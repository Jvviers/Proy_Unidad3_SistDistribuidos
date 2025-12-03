import os
from typing import Any, Dict

import httpx
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

APP1_URL = os.getenv("APP1_URL", "http://app1-instance-a:8001")
APP1_FALLBACK_URL = os.getenv("APP1_FALLBACK_URL", "http://app1-instance-b:8001")
APP2_URL = os.getenv("APP2_URL", "http://app2-instance-a:8002")
APP2_FALLBACK_URL = os.getenv("APP2_FALLBACK_URL", "http://app2-instance-b:8002")
APP3_URL = os.getenv("APP3_URL", "http://app3-reportes:8003")
TIMEOUT_SECONDS = float(os.getenv("HTTP_TIMEOUT", "5"))

app = FastAPI(title="Middleware", version="1.0.0")


class OrderRequest(BaseModel):
    product_id: int
    qty: int


def _client() -> httpx.Client:
    return httpx.Client(timeout=TIMEOUT_SECONDS)


def _post_with_fallback(
    client: httpx.Client,
    primary: str,
    fallback: str,
    path: str,
    payload: Dict[str, Any],
) -> httpx.Response:
    """
    Intenta primero en la URL primaria; si falla, usa la URL de respaldo.
    """
    urls = [primary]
    if fallback and fallback != primary:
        urls.append(fallback)

    last_exc: Exception | None = None
    for url in urls:
        try:
            res = client.post(f"{url}{path}", json=payload)
            res.raise_for_status()
            return res
        except Exception as exc:  # pragma: no cover - log en informe
            last_exc = exc
            continue
    raise HTTPException(status_code=502, detail=f"Error llamando a {path}: {last_exc}")


@app.get("/health")
def health() -> Dict[str, Any]:
    return {"status": "ok", "service": "middleware"}


@app.post("/orders")
def create_order(payload: OrderRequest) -> Dict[str, Any]:
    """
    Orquesta el flujo:
    1) Decrementa stock en App1.
    2) Crea orden en App2.
    3) Registra reporte en App3.
    Si falla 2 o 3, compensa el stock en App1 (intentando primaria y respaldo).
    """
    with _client() as client:
        # Paso 1: Decremento de stock
        try:
            dec_res = _post_with_fallback(
                client,
                APP1_URL,
                APP1_FALLBACK_URL,
                f"/products/{payload.product_id}/decrement",
                {"qty": payload.qty},
            )
            stock_info = dec_res.json()
        except Exception as e:  # pragma: no cover - log para proyecto
            raise HTTPException(status_code=502, detail=f"Error en App1: {e}")

        # Paso 2: Crear orden
        try:
            order_res = _post_with_fallback(
                client,
                APP2_URL,
                APP2_FALLBACK_URL,
                "/orders",
                {"product_id": payload.product_id, "qty": payload.qty},
            )
            order_data = order_res.json()
        except Exception as e:
            # Compensacion: revertir stock
            try:
                _post_with_fallback(
                    client,
                    APP1_URL,
                    APP1_FALLBACK_URL,
                    f"/products/{payload.product_id}/increment",
                    {"qty": payload.qty},
                )
            except Exception:
                pass
            raise HTTPException(status_code=502, detail=f"Error en App2: {e}")

        # Paso 3: Registrar reporte
        try:
            report_res = client.post(
                f"{APP3_URL}/reports",
                json={
                    "order_id": order_data.get("id"),
                    "status": "created",
                    "product_id": payload.product_id,
                    "qty": payload.qty,
                },
            )
            report_res.raise_for_status()
            report_data = report_res.json()
        except Exception as e:
            # Compensacion: revertir stock
            try:
                _post_with_fallback(
                    client,
                    APP1_URL,
                    APP1_FALLBACK_URL,
                    f"/products/{payload.product_id}/increment",
                    {"qty": payload.qty},
                )
            except Exception:
                pass
            raise HTTPException(status_code=502, detail=f"Error en App3: {e}")

    return {
        "order": order_data,
        "stock": stock_info,
        "report": report_data,
    }