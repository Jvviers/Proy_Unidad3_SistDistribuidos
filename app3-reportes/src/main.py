import os
from typing import Any, Dict

import pymysql
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


DB_HOST = os.getenv("DB_HOST", "mysql-primary")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_NAME = os.getenv("DB_NAME", "reportsdb")
DB_USER = os.getenv("DB_USER", "reports")
DB_PASS = os.getenv("DB_PASS", "reports123")

app = FastAPI(title="Reportes", version="1.0.0")


def get_conn():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASS,
        database=DB_NAME,
        autocommit=True,
        cursorclass=pymysql.cursors.DictCursor,
    )


class Report(BaseModel):
    order_id: int
    status: str
    product_id: int
    qty: int


@app.get("/health")
def health() -> Dict[str, Any]:
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return {"status": "ok", "service": "app3-reportes"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/reports")
def create_report(report: Report) -> Dict[str, Any]:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute(
                "INSERT INTO reports (order_id, status, product_id, qty) VALUES (%s, %s, %s, %s)",
                (report.order_id, report.status, report.product_id, report.qty),
            )
            cur.execute(
                "SELECT id, order_id, status, product_id, qty, created_at FROM reports ORDER BY id DESC LIMIT 1"
            )
            return cur.fetchone()
