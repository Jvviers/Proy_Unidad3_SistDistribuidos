import os
import requests
from fastapi import FastAPI, HTTPException

app = FastAPI()

APP1_URL = os.getenv("APP1_URL", "http://app1-instance-a:8001")
APP2_URL = os.getenv("APP2_URL", "http://app2-instance-a:8002")
APP3_URL = os.getenv("APP3_URL", "http://app3-reportes:8003")


@app.get("/health")
def health():
    return {"status": "ok", "service": "middleware"}


@app.post("/orders")
def create_order(payload: dict):
    product_id = payload.get("product_id")
    qty = payload.get("qty")
    if not product_id or not qty:
        raise HTTPException(status_code=400, detail="product_id y qty son requeridos")

    # Reservar stock en app1
    dec_resp = requests.post(f"{APP1_URL}/products/{product_id}/decrement", json={"qty": qty})
    if dec_resp.status_code != 200:
        raise HTTPException(status_code=dec_resp.status_code, detail=dec_resp.text)

    # Crear orden en app2
    order_resp = requests.post(f"{APP2_URL}/orders", json={"product_id": product_id, "qty": qty})
    if order_resp.status_code != 201:
        # revertir stock si la orden falla
        requests.post(f"{APP1_URL}/products/{product_id}/increment", json={"qty": qty})
        raise HTTPException(status_code=order_resp.status_code, detail=order_resp.text)

    order = order_resp.json()

    # Registrar reporte simple en app3
    requests.post(f"{APP3_URL}/reports", json={"name": f"order_{order['id']}", "value": qty})

    return {"order": order, "stock_reserved": True}
