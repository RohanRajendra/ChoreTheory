from fastapi import HTTPException
from db.connection import get_connection


def get_user_role(email: str, house_id: int) -> str | None:
    """Returns 'admin', 'member', 'guest', or None if not a member."""
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
            "SELECT role FROM user_house WHERE email = %s AND house_id = %s",
            (email, house_id)
        )
        row = cursor.fetchone()
        return row[0] if row else None
    finally:
        cursor.close()
        connection.close()


def require_non_guest(email: str, house_id: int) -> None:
    """Raises HTTP 403 if the user is a guest or not a member of the house."""
    role = get_user_role(email, house_id)
    if role is None:
        raise HTTPException(status_code=403, detail="User is not a member of this house.")
    if role == "guest":
        raise HTTPException(status_code=403, detail="Guests cannot perform write operations.")
