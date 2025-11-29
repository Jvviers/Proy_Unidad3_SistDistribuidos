import os
import time
import mysql.connector
from fastapi import FastAPI, HTTPException

app = FastAPI()


def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "mysql-primary"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "reports"),
        password=os.getenv("DB_PASS", "reports123"),
        database=os.getenv("DB_NAME", "reportsdb"),
    )


def ensure_schema():
    attempts = 0
    while attempts < 30:
        try:
            conn = get_connection()
            cur = conn.cursor()
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS reports (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255),
                    value INT
                )
                """
            )
            conn.commit()
            cur.close()
            conn.close()
            return
        except Exception:
            attempts += 1
            time.sleep(2)
    raise RuntimeError("No se pudo conectar a MySQL")


@app.on_event("startup")
def startup_event():
    try:
        ensure_schema()
    except Exception as exc:
        print(f"[startup] No se pudo inicializar esquema: {exc}")


@app.get("/health")
def health():
    try:
        ensure_schema()
        return {"status": "ok", "service": "app3-reportes"}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/reports")
def get_reports():
    conn = get_connection()
    cur = conn.cursor(dictionary=True)
    cur.execute("SELECT id, name, value FROM reports")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


@app.post("/reports")
def create_report(body: dict):
    name = body.get("name")
    value = body.get("value", 0)
    if not name:
        raise HTTPException(status_code=400, detail="name requerido")
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO reports (name, value) VALUES (%s, %s)", (name, value))
    conn.commit()
    cur.close()
    conn.close()
    return {"name": name, "value": value}
