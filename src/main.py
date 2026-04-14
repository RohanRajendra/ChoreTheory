from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routers import users, houses, resources, bookings, reminders, expenses, analytics, ml

app = FastAPI(title="Shared Home Scheduler API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(users.router)
app.include_router(houses.router)
app.include_router(resources.router)
app.include_router(bookings.router)
app.include_router(reminders.router)
app.include_router(expenses.router)
app.include_router(analytics.router)
app.include_router(ml.router)

