from pydantic import BaseModel, EmailStr
from typing import Optional
from datetime import datetime, date
from decimal import Decimal


# ------------------------------------------------------------------
# USER SCHEMAS
# ------------------------------------------------------------------

class UserCreate(BaseModel):
    email: EmailStr
    name: str
    password: str


class UserLogin(BaseModel):
    email: EmailStr
    password: str


class UserUpdate(BaseModel):
    name: Optional[str] = None
    password: Optional[str] = None


# ------------------------------------------------------------------
# HOUSE SCHEMAS
# ------------------------------------------------------------------

class HouseCreate(BaseModel):
    address: str
    name: str
    creator_email: EmailStr


class HouseUpdate(BaseModel):
    address: Optional[str] = None
    name: Optional[str] = None


class AddMember(BaseModel):
    admin_email: EmailStr
    new_user_email: EmailStr
    role: str = "member"          # 'member' or 'guest'


class RemoveMember(BaseModel):
    admin_email: EmailStr


# ------------------------------------------------------------------
# RESOURCE SCHEMAS
# ------------------------------------------------------------------

class ResourceCreate(BaseModel):
    name: str
    time_limit: int
    icon: Optional[str] = None
    house_id: int
    subclass: Optional[str] = None          # 'space' | 'appliance' | None
    clean_after_use: Optional[bool] = None
    max_occupancy: Optional[int] = None
    requires_maintenance: Optional[bool] = None


class ResourceUpdate(BaseModel):
    name: Optional[str] = None
    time_limit: Optional[int] = None
    icon: Optional[str] = None


# ------------------------------------------------------------------
# BOOKING SCHEMAS
# ------------------------------------------------------------------

class BookingCreate(BaseModel):
    user_email: EmailStr
    resource_id: int
    start_time: datetime
    end_time: datetime


# ------------------------------------------------------------------
# REMINDER SCHEMAS
# ------------------------------------------------------------------

class ReminderCreate(BaseModel):
    booking_id: int
    reminder_time: datetime
    message: Optional[str] = None


class ReminderUpdate(BaseModel):
    booking_id: int
    reminder_time: Optional[datetime] = None
    message: Optional[str] = None


# ------------------------------------------------------------------
# EXPENSE SCHEMAS
# ------------------------------------------------------------------

class ExpenseCreate(BaseModel):
    amount: Decimal
    description: str
    due_date: date
    receipts_attachment: Optional[str] = None
    is_recurring: bool = False
    created_by: EmailStr


class ExpenseSplit(BaseModel):
    email: EmailStr
    user_share: Decimal