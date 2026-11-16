from fastapi import APIRouter, HTTPException
from db.connection import get_connection
import mysql.connector

router = APIRouter(prefix="/analytics", tags=["analytics"])


# ------------------------------------------------------------------
# GET /analytics/houses/{house_id}/expense-trend
# Total expenses grouped by month for the given house.
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/expense-trend")
def expense_trend(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_expense_trend_by_month", [house_id])
        results = []
        for res in cursor.stored_results():
            results = res.fetchall()
        return results
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /analytics/houses/{house_id}/top-spenders
# Top 5 users by total share in the given house.
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/top-spenders")
def top_spenders(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_top_spenders", [house_id])
        results = []
        for res in cursor.stored_results():
            results = res.fetchall()
        return results
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /analytics/houses/{house_id}/booking-frequency
# Booking count per resource for the given house.
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/booking-frequency")
def booking_frequency(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_resource_booking_frequency", [house_id])
        results = []
        for res in cursor.stored_results():
            results = res.fetchall()
        return results
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /analytics/houses/{house_id}/settlement-breakdown
# Count of user_expense rows by payment_status for the given house.
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/settlement-breakdown")
def settlement_breakdown(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_expense_settlement_breakdown", [house_id])
        results = []
        for res in cursor.stored_results():
            results = res.fetchall()
        return results
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /analytics/houses/{house_id}/resource-utilization
# Total minutes booked and booking count by resource type.
# ------------------------------------------------------------------
@router.get("/houses/{house_id}/resource-utilization")
def resource_utilization(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_resource_utilization_by_type", [house_id])
        results = []
        for res in cursor.stored_results():
            results = res.fetchall()
        return results
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()
