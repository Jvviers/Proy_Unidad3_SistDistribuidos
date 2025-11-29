import os
import time
import mysql.connector
from fastapi import FastAPI, HTTPException

app = FastAPI()


def get_connection():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "mariadb-primary"),
        port=int(os.getenv("DB_PORT", "3306")),
        user=os.getenv("DB_USER", "inventory"),
        password=os.getenv("DB_PASS", "inventory123"),
        database=os.getenv("DB_NAME", "inventorydb"),
    )


def ensure_schema():
    attempts = 0
    while attempts < 30:
        try:
            conn = get_connection()
            cur = conn.cursor()
            cur.execute(
                """
                CREATE TABLE IF NOT EXISTS products (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    name VARCHAR(255),
                    stock INT
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
    raise RuntimeError("No se pudo conectar a MariaDB")


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
        return {"status": "ok", "service": "app1-inventario"}
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc))


@app.get("/products")
def get_products():
    conn = get_connection()
    cur = conn.cursor(dictionary=True)
    cur.execute("SELECT id, name, stock FROM products")
    rows = cur.fetchall()
    cur.close()
    conn.close()
    return rows


@app.post("/products")
def create_product(body: dict):
    name = body.get("name")
    stock = body.get("stock", 0)
    if not name:
        raise HTTPException(status_code=400, detail="name requerido")
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("INSERT INTO products (name, stock) VALUES (%s, %s)", (name, stock))
    conn.commit()
    cur.close()
    conn.close()
    return {"name": name, "stock": stock}


@app.post("/products/{product_id}/decrement")
def decrement_stock(product_id: int, body: dict):
    qty = body.get("qty", 0)
    if qty <= 0:
        raise HTTPException(status_code=400, detail="qty debe ser > 0")
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("SELECT stock FROM products WHERE id=%s", (product_id,))
    row = cur.fetchone()
    if not row:
        cur.close()
        conn.close()
        raise HTTPException(status_code=404, detail="Producto no encontrado")
    if row[0] < qty:
        cur.close()
        conn.close()
        raise HTTPException(status_code=400, detail="Stock insuficiente")
    cur.execute("UPDATE products SET stock = stock - %s WHERE id=%s", (qty, product_id))
    conn.commit()
    cur.close()
    conn.close()
    return {"product_id": product_id, "decremented": qty}


@app.post("/products/{product_id}/increment")
def increment_stock(product_id: int, body: dict):
    qty = body.get("qty", 0)
    if qty <= 0:
        raise HTTPException(status_code=400, detail="qty debe ser > 0")
    conn = get_connection()
    cur = conn.cursor()
    cur.execute("UPDATE products SET stock = stock + %s WHERE id=%s", (qty, product_id))
    conn.commit()
    cur.close()
    conn.close()
    return {"product_id": product_id, "incremented": qty}
