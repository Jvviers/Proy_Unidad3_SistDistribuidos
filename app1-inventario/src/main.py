from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health():
    return {"status": "ok", "service": "app1-inventario"}

@app.get("/products")
def get_products():
    return [{"id": 1, "name": "Producto de prueba", "stock": 10}]
