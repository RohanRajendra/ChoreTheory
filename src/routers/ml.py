from fastapi import APIRouter, HTTPException
from db.connection import get_connection
import mysql.connector

router = APIRouter(prefix="/ml", tags=["ml"])


# ------------------------------------------------------------------
# GET /ml/houses/{house_id}/expense-forecast
# Linear regression on monthly expense totals → 3-month forecast.
# Returns historical data plus predicted amounts for next 3 months.
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/expense-forecast")
def expense_forecast(house_id: int):
    try:
        import pandas as pd
        from sklearn.linear_model import LinearRegression
        import numpy as np
    except ImportError:
        raise HTTPException(
            status_code=500,
            detail="ML dependencies not installed. Run: pip install scikit-learn pandas numpy"
        )

    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT
                YEAR(e.creation_date)  AS yr,
                MONTH(e.creation_date) AS mo,
                SUM(e.amount)          AS total
            FROM expense e
            JOIN user_expense ue ON e.expense_id = ue.expense_id
            JOIN user_house   uh ON ue.email      = uh.email
            WHERE uh.house_id = %s
            GROUP BY yr, mo
            ORDER BY yr, mo
            """,
            (house_id,)
        )
        rows = cursor.fetchall()
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()

    if len(rows) < 3:
        return {
            "historical": rows,
            "forecast": [],
            "message": "Not enough data for forecast (need at least 3 months)."
        }

    df = pd.DataFrame(rows)
    df["period_index"] = range(len(df))

    X = df[["period_index"]].values
    y = df["total"].values.astype(float)

    model = LinearRegression()
    model.fit(X, y)

    # Build next 3 month labels from the last known month
    last_yr = int(df.iloc[-1]["yr"])
    last_mo = int(df.iloc[-1]["mo"])
    forecast = []
    n = len(df)
    for i in range(1, 4):
        pred_mo = (last_mo - 1 + i) % 12 + 1
        pred_yr = last_yr + (last_mo - 1 + i) // 12
        predicted = float(model.predict([[n + i - 1]])[0])
        forecast.append({
            "yr": pred_yr,
            "mo": pred_mo,
            "predicted_amount": round(max(predicted, 0), 2)
        })

    historical = [
        {"yr": int(r["yr"]), "mo": int(r["mo"]), "total": float(r["total"])}
        for r in rows
    ]

    return {"historical": historical, "forecast": forecast}


# ------------------------------------------------------------------
# GET /ml/houses/{house_id}/resource-recommendations
# KNN collaborative filtering: recommends resources the user
# hasn't booked yet, based on similar users' booking patterns.
# Query param: user_email
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/resource-recommendations")
def resource_recommendations(house_id: int, user_email: str):
    try:
        import pandas as pd
        from sklearn.neighbors import NearestNeighbors
        import numpy as np
    except ImportError:
        raise HTTPException(
            status_code=500,
            detail="ML dependencies not installed. Run: pip install scikit-learn pandas numpy"
        )

    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.execute(
            """
            SELECT
                b.user_email,
                r.resource_id,
                r.name AS resource_name,
                CASE
                    WHEN rs.resource_id IS NOT NULL THEN 'space'
                    WHEN ra.resource_id IS NOT NULL THEN 'appliance'
                    ELSE 'base'
                END AS resource_type,
                COUNT(*) AS booking_count
            FROM booking b
            JOIN resource_table   r  ON b.resource_id  = r.resource_id
            LEFT JOIN resource_space    rs ON r.resource_id = rs.resource_id
            LEFT JOIN resource_appliance ra ON r.resource_id = ra.resource_id
            WHERE r.house_id = %s
            GROUP BY b.user_email, r.resource_id, r.name, resource_type
            """,
            (house_id,)
        )
        rows = cursor.fetchall()
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()

    if not rows:
        return {"user_email": user_email, "recommendations": [], "message": "No booking data available."}

    df = pd.DataFrame(rows)
    pivot = df.pivot_table(
        index="user_email",
        columns="resource_id",
        values="booking_count",
        fill_value=0
    )

    if user_email not in pivot.index:
        return {"user_email": user_email, "recommendations": [], "message": "User has no bookings in this house."}

    n_users = len(pivot)
    if n_users < 2:
        return {"user_email": user_email, "recommendations": [], "message": "Not enough users for recommendations."}

    k = min(3, n_users - 1)
    model = NearestNeighbors(n_neighbors=k, metric="cosine", algorithm="brute")
    model.fit(pivot.values)

    user_idx = pivot.index.get_loc(user_email)
    user_vector = pivot.iloc[user_idx].values.reshape(1, -1)
    distances, indices = model.kneighbors(user_vector)

    # Average booking vector of neighbors
    neighbor_vectors = pivot.iloc[indices[0]].values
    avg_vector = neighbor_vectors.mean(axis=0)

    # Resources the target user hasn't booked
    user_booked = set(pivot.columns[pivot.iloc[user_idx] > 0])
    resource_meta = {
        r["resource_id"]: {"resource_name": r["resource_name"], "resource_type": r["resource_type"]}
        for r in rows
    }

    candidates = []
    for col_idx, resource_id in enumerate(pivot.columns):
        if resource_id not in user_booked and avg_vector[col_idx] > 0:
            candidates.append({
                "resource_id": int(resource_id),
                "resource_name": resource_meta[resource_id]["resource_name"],
                "resource_type": resource_meta[resource_id]["resource_type"],
                "score": round(float(avg_vector[col_idx]), 4)
            })

    candidates.sort(key=lambda x: x["score"], reverse=True)

    return {"user_email": user_email, "recommendations": candidates[:3]}
