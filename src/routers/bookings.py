from fastapi import APIRouter, HTTPException
from db.connection import get_connection
from models.schemas import BookingCreate
import mysql.connector

router = APIRouter(prefix="/bookings", tags=["bookings"])


# ------------------------------------------------------------------
# POST /bookings
# Create a new booking.
# Procedure enforces:
#   - end_time > start_time
#   - no overlapping bookings for the resource
# Trigger auto-creates a 30-minute reminder after insert.
# ------------------------------------------------------------------
@router.post("/", status_code=201)
def create_booking(payload: BookingCreate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc(
            "create_booking",
            [
                payload.user_email,
                payload.resource_id,
                payload.start_time.strftime("%Y-%m-%d %H:%M:%S"),
                payload.end_time.strftime("%Y-%m-%d %H:%M:%S")
            ]
        )
        connection.commit()
        return {"message": "Booking created successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /bookings/user/{email}
# Fetch all bookings for a user ordered by start_time desc.
# Registered before /{booking_id} to avoid route shadowing.
# ------------------------------------------------------------------
@router.get("/user/{email}")
def get_user_bookings(email: str):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_user_bookings", [email])
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
# GET /bookings/{booking_id}
# Fetch a single booking by ID with resource name.
# ------------------------------------------------------------------
@router.get("/{booking_id}")
def get_booking(booking_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_booking", [booking_id])
        result = None
        for res in cursor.stored_results():
            result = res.fetchone()

        if result is None:
            raise HTTPException(status_code=404, detail="Booking not found.")

        return result
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# DELETE /bookings/{booking_id}
# Cancel a booking. Cascades to all associated reminders.
# ------------------------------------------------------------------
@router.delete("/{booking_id}")
def delete_booking(booking_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("delete_booking", [booking_id])
        connection.commit()
        return {"message": "Booking cancelled successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()