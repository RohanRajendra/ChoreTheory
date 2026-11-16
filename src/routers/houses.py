from fastapi import APIRouter, HTTPException
from db.connection import get_connection
from models.schemas import HouseCreate, HouseUpdate, AddMember, RemoveMember
import mysql.connector

router = APIRouter(prefix="/houses", tags=["houses"])


# ------------------------------------------------------------------
# POST /houses
# Create a new house. The creator is automatically set as admin.
# Uses OUT parameter pattern — two execute calls required.
# ------------------------------------------------------------------
@router.post("/", status_code=201)
def create_house(payload: HouseCreate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
            "CALL create_house(%s, %s, %s, @house_id)",
            (payload.address, payload.name, payload.creator_email)
        )
        cursor.execute("SELECT @house_id")
        row = cursor.fetchone()
        connection.commit()

        if row is None or row[0] is None:
            raise HTTPException(status_code=500, detail="House creation failed.")

        return {"message": "House created successfully.", "house_id": row[0]}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /houses/{house_id}
# Fetch a single house by ID.
# ------------------------------------------------------------------
@router.get("/{house_id}")
def get_house(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_house", [house_id])
        result = None
        for res in cursor.stored_results():
            result = res.fetchone()

        if result is None:
            raise HTTPException(status_code=404, detail="House not found.")

        return result
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /houses/user/{email}
# Fetch all houses a user belongs to.
# Returns house details and the user's is_admin flag per house.
# ------------------------------------------------------------------
@router.get("/user/{email}")
def get_user_houses(email: str):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_user_houses", [email])
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
# PUT /houses/{house_id}
# Update house name and/or address. Omitted fields stay unchanged.
# ------------------------------------------------------------------
@router.put("/{house_id}")
def update_house(house_id: int, payload: HouseUpdate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("update_house", [house_id, payload.address, payload.name])
        connection.commit()
        return {"message": "House updated successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# DELETE /houses/{house_id}
# Delete a house. Cascades to resources, bookings, and memberships.
# ------------------------------------------------------------------
@router.delete("/{house_id}")
def delete_house(house_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("delete_house", [house_id])
        connection.commit()
        return {"message": "House deleted successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# POST /houses/{house_id}/members
# Add a new member to a house. Caller must be the house admin.
# Admin check is enforced by the add_user_to_house procedure.
# ------------------------------------------------------------------
@router.post("/{house_id}/members", status_code=201)
def add_member(house_id: int, payload: AddMember):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc(
            "add_user_to_house",
            [payload.admin_email, payload.new_user_email, house_id, payload.role]
        )
        connection.commit()
        return {
            "message": f"{payload.new_user_email} added to house successfully."
        }
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /houses/{house_id}/members
# List all members of a house with their admin status.
# ------------------------------------------------------------------
@router.get("/{house_id}/members")
def get_house_members(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_house_members", [house_id])
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
# DELETE /houses/{house_id}/members/{email}
# Remove a member from a house.
# Procedure blocks removal of the admin.
# ------------------------------------------------------------------
@router.delete("/{house_id}/members/{email}")
def remove_member(house_id: int, email: str):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("remove_member_from_house", [email, house_id])
        connection.commit()
        return {"message": f"{email} removed from house successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /houses/{house_id}/balance
# Returns the total expense amount across all members of a house.
# Direct function call — no procedure needed.
# ------------------------------------------------------------------
@router.get("/{house_id}/balance")
def get_house_balance(house_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
            "SELECT get_total_house_expenses(%s) AS total_expenses",
            (house_id,)
        )
        row = cursor.fetchone()
        return {"house_id": house_id, "total_expenses": row[0]}
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()