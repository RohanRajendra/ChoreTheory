from fastapi import FastAPI
from routers import users, houses, resources, bookings, reminders, expenses

app = FastAPI(title="Shared Home Scheduler API")

app.include_router(users.router)
app.include_router(houses.router)
app.include_router(resources.router)
app.include_router(bookings.router)
app.include_router(reminders.router)
app.include_router(expenses.router)
