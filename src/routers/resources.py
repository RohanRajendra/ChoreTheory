from fastapi import APIRouter, HTTPException
from db.connection import get_connection
from models.schemas import ResourceCreate, ResourceUpdate
import mysql.connector

router = APIRouter(prefix="/resources", tags=["resources"])


# ------------------------------------------------------------------
# POST /resources
# Create a base resource, then optionally classify it as a
# Space or Appliance. Up to 3 DB calls in one endpoint:
#   1. create_resource        → gets new resource_id
#   2. create_space           → if subclass is 'space'
#      create_appliance       → if subclass is 'appliance'
# The subclass field in the payload determines which branch runs.
# ------------------------------------------------------------------
@router.post("/", status_code=201)
def create_resource(payload: ResourceCreate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        # Step 1 — create base resource, retrieve OUT param
        cursor.execute(
            "CALL create_resource(%s, %s, %s, %s, @resource_id)",
            (payload.name, payload.time_limit, payload.icon, payload.house_id)
        )
        cursor.execute("SELECT @resource_id")
        row = cursor.fetchone()

        if row is None or row[0] is None:
            raise HTTPException(status_code=500, detail="Resource creation failed.")

        resource_id = row[0]

        # Step 2 — classify as subclass if provided
        if payload.subclass == "space":
            if payload.clean_after_use is None or payload.max_occupancy is None:
                raise HTTPException(
                    status_code=422,
                    detail="Space requires clean_after_use and max_occupancy."
                )
            cursor.callproc(
                "create_space",
                [resource_id, payload.clean_after_use, payload.max_occupancy]
            )

        elif payload.subclass == "appliance":
            if payload.requires_maintenance is None:
                raise HTTPException(
                    status_code=422,
                    detail="Appliance requires requires_maintenance."
                )
            cursor.callproc(
                "create_appliance",
                [resource_id, payload.requires_maintenance]
            )

        connection.commit()
        return {
            "message": "Resource created successfully.",
            "resource_id": resource_id,
            "subclass": payload.subclass or "base"
        }
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /resources/house/{house_id}
# Fetch all resources for a house.
# Includes subclass fields and resource_type column.
# Registered before /{resource_id} to avoid route shadowing.
# ------------------------------------------------------------------
@router.get("/house/{house_id}")
def get_house_resources(house_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_house_resources", [house_id])
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
# GET /resources/{resource_id}/availability
# Check if a resource is free in a given time window.
# Query params: start_time, end_time (ISO 8601 datetime strings).
# Returns available: true/false.
# Registered before /{resource_id} as a fixed sub-path.
# ------------------------------------------------------------------
@router.get("/{resource_id}/availability")
def check_availability(resource_id: int, start_time: str, end_time: str):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.execute(
            "SELECT is_resource_available(%s, %s, %s) AS available",
            (resource_id, start_time, end_time)
        )
        row = cursor.fetchone()
        return {
            "resource_id": resource_id,
            "start_time": start_time,
            "end_time": end_time,
            "available": bool(row[0])
        }
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# GET /resources/{resource_id}
# Fetch a single resource by ID.
# Returns base fields + subclass fields + resource_type.
# ------------------------------------------------------------------
@router.get("/{resource_id}")
def get_resource(resource_id: int):
    connection = get_connection()
    cursor = connection.cursor(dictionary=True)
    try:
        cursor.callproc("get_resource", [resource_id])
        result = None
        for res in cursor.stored_results():
            result = res.fetchone()

        if result is None:
            raise HTTPException(status_code=404, detail="Resource not found.")

        return result
    except mysql.connector.Error as e:
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# PUT /resources/{resource_id}
# Update base resource fields. Omitted fields stay unchanged.
# Subclass fields are not updatable here — subclass rows are
# owned by the DB and set at creation time.
# ------------------------------------------------------------------
@router.put("/{resource_id}")
def update_resource(resource_id: int, payload: ResourceUpdate):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc(
            "update_resource",
            [resource_id, payload.name, payload.time_limit, payload.icon]
        )
        connection.commit()
        return {"message": "Resource updated successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()


# ------------------------------------------------------------------
# DELETE /resources/{resource_id}
# Delete a resource. DB cascades handle subclass rows and bookings.
# ------------------------------------------------------------------
@router.delete("/{resource_id}")
def delete_resource(resource_id: int):
    connection = get_connection()
    cursor = connection.cursor()
    try:
        cursor.callproc("delete_resource", [resource_id])
        connection.commit()
        return {"message": "Resource deleted successfully."}
    except mysql.connector.Error as e:
        connection.rollback()
        raise HTTPException(status_code=400, detail=e.msg)
    finally:
        cursor.close()
        connection.close()