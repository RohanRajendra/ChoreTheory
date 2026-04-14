# Backend Setup

## Prerequisites

- [Python 3.13.2](https://www.python.org/downloads/release/python-3132/)
- [MySQL 8.0+](https://dev.mysql.com/downloads/mysql/)
- [MySQL Workbench](https://dev.mysql.com/downloads/workbench/) 

---

## 1. Database Setup

Open MySQL Workbench or the MySQL CLI and run the complete dump file:

```bash
mysql -u root -p < src/sql_scripts/project_db_complete_dump.sql
```

Or in MySQL Workbench: **File → Open SQL Script**, select `project_db_complete_dump.sql`, then click the lightning bolt to execute.

This creates the `project_db` database, all tables, functions, procedures, triggers, events, and populates dummy data in one step.

---

## 2. Environment Variables

Create a `.env` file inside `src/`:

```
DB_HOST=localhost
DB_USER=root
DB_PASSWORD=your_mysql_password
DB_NAME=project_db
```

---

## 3. Virtual Environment

From the project root:

```bash
python3 -m venv venv
source venv/bin/activate        # Mac/Linux
venv\Scripts\activate           # Windows
```

---

## 4. Install Dependencies

```bash
pip install -r requirements.txt
```

`requirements.txt` contents:

```
fastapi
uvicorn
mysql-connector-python
python-dotenv
pydantic[email]
```

---

## 5. Run the Server

```bash
cd src
uvicorn main:app --reload
```

The API will be available at `http://localhost:8000`.

Interactive docs (Swagger UI) at `http://localhost:8000/docs`.

---

## Project Structure

```
src/
├── main.py
├── .env
├── db/
│   └── connection.py
├── routers/
│   ├── users.py
│   ├── houses.py
│   ├── resources.py
│   ├── bookings.py
│   ├── reminders.py
│   └── expenses.py
├── models/
│   └── schemas.py
└── sql_scripts/
    └── project_db_complete_dump.sql
```