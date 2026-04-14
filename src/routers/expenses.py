from fastapi import APIRouter, HTTPException
from db.connection import get_connection
from models.schemas import ExpenseCreate, ExpenseSplit
import mysql.connector

router = APIRouter(prefix="/expenses", tags=["expenses"])


# ------------------------------------------------------------------
# POST /expenses
# Create a new expense.
# The after_expense_insert trigger automatically adds the creator
# to user_expense for the full amount with status 'unpaid'.
# The frontend should call /split for other participants after.
# ------------------------------------------------------------------
@router.post("/", status_code=201)
def create_expense(payload: ExpenseCreate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc(
            "create_expense",
            [
                payload.amount,
                payload.description,
                payload.due_date.strftime("%Y-%m-%d"),
                payload.receipts_attachment,
                payload.is_recurring,
                payload.created_by
            ]
        )
        connection.commit()
        return {"message": "Expense created successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /expenses/user/{email}
# Fetch all expenses a user participates in, with their
# individual share and payment status per expense.
# Registered before /{expense_id} to avoid route shadowing.
# ------------------------------------------------------------------
@router.get("/user/{email}")
def get_user_expenses(email: str):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_user_expenses", [email])
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
# GET /expenses/user/{email}/balance/{house_id}
# Returns the total unpaid balance for a user in a given house.
# Direct function call — no procedure needed.
# Registered before /{expense_id} to avoid route shadowing.
# ------------------------------------------------------------------
@router.get("/user/{email}/balance/{house_id}")
def get_user_balance(email: str, house_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
            "SELECT get_user_balance(%s, %s) AS balance",
            (email, house_id)
        )
        row = cursor.fetchone()
        return {
            "email": email,
            "house_id": house_id,
            "outstanding_balance": row[0]
        }
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /expenses/{expense_id}
# Fetch a single expense by ID with creator name.
# ------------------------------------------------------------------
@router.get("/{expense_id}")
def get_expense(expense_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_expense", [expense_id])
        result = None
        for res in cursor.stored_results():
            result = res.fetchone()

        if result is None:
            raise HTTPException(status_code=404, detail="Expense not found.")

        return result
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /expenses/{expense_id}/participants
# Fetch all users split on an expense with their share and
# payment status.
# ------------------------------------------------------------------
@router.get("/{expense_id}/participants")
def get_expense_participants(expense_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_expense_participants", [expense_id])
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
# POST /expenses/{expense_id}/split
# Add a participant to an expense with their share amount.
# Call once per participant after creating the expense.
# The creator is already added by the trigger — calling this
# for the creator will return a duplicate error from the procedure.
# ------------------------------------------------------------------
@router.post("/{expense_id}/split", status_code=201)
def split_expense(expense_id: int, payload: ExpenseSplit):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc(
            "split_expense",
            [expense_id, payload.email, payload.user_share]
        )
        connection.commit()
        return {
            "message": f"{payload.email} added to expense successfully.",
            "user_share": payload.user_share
        }
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# PUT /expenses/{expense_id}/settle/{email}
# Mark a user's share of an expense as paid.
# Procedure raises error if already paid or record not found.
# ------------------------------------------------------------------
@router.put("/{expense_id}/settle/{email}")
def settle_payment(expense_id: int, email: str):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("settle_payment", [email, expense_id])
        connection.commit()
        return {
            "message": f"Payment settled for {email} on expense {expense_id}."
        }
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# DELETE /expenses/{expense_id}
# Delete an expense. Cascades to all user_expense rows.
# ------------------------------------------------------------------
@router.delete("/{expense_id}")
def delete_expense(expense_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("delete_expense", [expense_id])
        connection.commit()
        return {"message": "Expense deleted successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()