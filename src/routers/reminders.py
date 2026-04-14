from fastapi import APIRouter, HTTPException
from db.connection import get_connection
from models.schemas import ReminderCreate, ReminderUpdate
import mysql.connector

router = APIRouter(prefix="/reminders", tags=["reminders"])


# ------------------------------------------------------------------
# POST /reminders
# Create a manual reminder for an existing booking.
# Note: a default 30-minute reminder is already auto-created
# by the after_booking_insert trigger. This endpoint allows
# the user to add additional reminders on top of that.
# ------------------------------------------------------------------
@router.post("/", status_code=201)
def create_reminder(payload: ReminderCreate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc(
            "create_reminder",
            [
                payload.booking_id,
                payload.reminder_time.strftime("%Y-%m-%d %H:%M:%S"),
                payload.message
            ]
        )
        connection.commit()
        return {"message": "Reminder created successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /reminders/booking/{booking_id}
# Fetch all reminders for a given booking ordered by time asc.
# Registered before /{reminder_id} to avoid route shadowing.
# ------------------------------------------------------------------
@router.get("/booking/{booking_id}")
def get_booking_reminders(booking_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_booking_reminders", [booking_id])
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
# PUT /reminders/{reminder_id}
# Update reminder_time and/or message for a pending reminder.
# booking_id is required in the body — it is part of the
# composite PK and is needed by the update_reminder procedure.
# Procedure blocks updates to sent or cancelled reminders.
# ------------------------------------------------------------------
@router.put("/{reminder_id}")
def update_reminder(reminder_id: int, payload: ReminderUpdate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        reminder_time = (
            payload.reminder_time.strftime("%Y-%m-%d %H:%M:%S")
            if payload.reminder_time else None
        )
        cursor.callproc(
            "update_reminder",
            [reminder_id, payload.booking_id, reminder_time, payload.message]
        )
        connection.commit()
        return {"message": "Reminder updated successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# DELETE /reminders/{reminder_id}
# Delete a reminder by composite PK (reminder_id + booking_id).
# booking_id is passed as a query parameter since it is part
# of the composite PK and is required by the procedure.
# ------------------------------------------------------------------
@router.delete("/{reminder_id}")
def delete_reminder(reminder_id: int, booking_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("delete_reminder", [reminder_id, booking_id])
        connection.commit()
        return {"message": "Reminder deleted successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()