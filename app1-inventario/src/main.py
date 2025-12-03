import os
from typing import Any, Dict, List

import pymysql
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel


DB_HOST = os.getenv("DB_HOST", "mariadb-primary")
DB_HOST_REPLICA = os.getenv("DB_HOST_REPLICA", "mariadb-replica")
DB_PORT = int(os.getenv("DB_PORT", "3306"))
DB_NAME = os.getenv("DB_NAME", "inventorydb")
DB_USER = os.getenv("DB_USER", "inventory")
DB_PASS = os.getenv("DB_PASS", "inventory123")

app = FastAPI(title="Inventario", version="1.0.0")


def get_conn():
    hosts = [DB_HOST]
    if DB_HOST_REPLICA and DB_HOST_REPLICA not in hosts:
        hosts.append(DB_HOST_REPLICA)

    last_exc = None
    for host in hosts:
        try:
            return pymysql.connect(
                host=host,
                port=DB_PORT,
                user=DB_USER,
                password=DB_PASS,
                database=DB_NAME,
                autocommit=False,
                cursorclass=pymysql.cursors.DictCursor,
            )
        except Exception as exc:
            last_exc = exc
            continue
    raise HTTPException(status_code=502, detail=f"No se pudo conectar a BD: {last_exc}")


class StockChange(BaseModel):
    qty: int = 1


@app.get("/health")
def health() -> Dict[str, Any]:
    try:
        with get_conn() as conn:
            with conn.cursor() as cur:
                cur.execute("SELECT 1")
        return {"status": "ok", "service": "app1-inventario"}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/products")
def get_products() -> List[Dict[str, Any]]:
    with get_conn() as conn:
        with conn.cursor() as cur:
            cur.execute("SELECT id, name, stock FROM products")
            return cur.fetchall()


@app.post("/products/{product_id}/decrement")
def decrement_stock(product_id: int, payload: StockChange) -> Dict[str, Any]:
    with get_conn() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "SELECT stock FROM products WHERE id=%s FOR UPDATE", (product_id,)
                )
                row = cur.fetchone()
                if not row or row["stock"] < payload.qty:
                    raise HTTPException(status_code=400, detail="Stock insuficiente")
                cur.execute(
                    "UPDATE products SET stock = stock - %s WHERE id=%s",
                    (payload.qty, product_id),
                )
                cur.execute(
                    "SELECT id, name, stock FROM products WHERE id=%s", (product_id,)
                )
                result = cur.fetchone()
            conn.commit()
            return result
        except Exception:
            conn.rollback()
            raise


@app.post("/products/{product_id}/increment")
def increment_stock(product_id: int, payload: StockChange) -> Dict[str, Any]:
    with get_conn() as conn:
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "UPDATE products SET stock = stock + %s WHERE id=%s",
                    (payload.qty, product_id),
                )
                cur.execute(
                    "SELECT id, name, stock FROM products WHERE id=%s", (product_id,)
                )
                result = cur.fetchone()
            conn.commit()
            return result
        except Exception:
            conn.rollback()
            raise
