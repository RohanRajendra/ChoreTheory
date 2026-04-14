from fastapi import APIRouter, HTTPException
from db.connection import get_connection
from models.schemas import UserCreate, UserUpdate, UserLogin
import mysql.connector
import hashlib

router = APIRouter(prefix="/users", tags=["users"])


def hash_password(password: str) -> str:
    """SHA-256 hash. simple encoding."""
    return hashlib.sha256(password.encode()).hexdigest()


def verify_password(plain: str, hashed: str) -> bool:
    return hash_password(plain) == hashed


# ------------------------------------------------------------------
# POST /users
# Create a new user. Password is hashed before storage.
# ------------------------------------------------------------------
@router.post("/", status_code=201)
def create_user(payload: UserCreate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        hashed = hash_password(payload.password)
        cursor.callproc("create_user", [payload.email, payload.name, hashed])
        connection.commit()
        return {"message": "User created successfully.", "email": payload.email}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# POST /users/login
# Fetch stored hash and compare against provided password.
# ------------------------------------------------------------------
@router.post("/login")
def login_user(payload: UserLogin):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("login_user", [payload.email])
        result = None
        for res in cursor.stored_results():
            result = res.fetchone()

        if result is None:
            raise HTTPException(status_code=404, detail="User not found.")

        if not verify_password(payload.password, result["password"]):
            raise HTTPException(status_code=401, detail="Incorrect password.")

        return {
            "message": "Login successful.",
            "email": result["email"],
            "name": result["name"]
        }
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /users/{email}
# Fetch a user's profile. Password is never returned.
# ------------------------------------------------------------------
@router.get("/{email}")
def get_user(email: str):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_user", [email])
        result = None
        for res in cursor.stored_results():
            result = res.fetchone()

        if result is None:
            raise HTTPException(status_code=404, detail="User not found.")

        return result
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# PUT /users/{email}
# Update name and/or password. Omitted fields stay unchanged.
# ------------------------------------------------------------------
@router.put("/{email}")
def update_user(email: str, payload: UserUpdate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        hashed = hash_password(payload.password) if payload.password else None
        cursor.callproc("update_user", [email, payload.name, hashed])
        connection.commit()
        return {"message": "User updated successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# DELETE /users/{email}
# Delete a user. DB cascades handle memberships and expenses.
# Bookings and expenses created by this user are preserved with
# user_email / created_by SET NULL.
# ------------------------------------------------------------------
@router.delete("/{email}")
def delete_user(email: str):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("delete_user", [email])
        connection.commit()
        return {"message": "User deleted successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()