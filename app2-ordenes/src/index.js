const express = require("express");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

const DB_CONFIG = {
  host: process.env.DB_HOST || "postgres-primary",
  port: Number(process.env.DB_PORT || 5432),
  user: process.env.DB_USER || "orders",
  password: process.env.DB_PASS || "orders123",
  database: process.env.DB_NAME || "ordersdb",
};

const pool = new Pool(DB_CONFIG);

app.get("/health", async (_req, res) => {
  try {
    await pool.query("SELECT 1");
    res.json({ status: "ok", service: "app2-ordenes" });
  } catch (err) {
    res.status(500).json({ status: "error", error: err.message });
  }
});

app.post("/orders", async (req, res) => {
  const { product_id, qty } = req.body;
  if (!product_id || !qty) {
    return res.status(400).json({ error: "product_id y qty son requeridos" });
  }

  try {
    const result = await pool.query(
      "INSERT INTO orders (product_id, qty, status) VALUES ($1, $2, $3) RETURNING *",
      [product_id, qty, "created"]
    );
    res.json(result.rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(8002, () => console.log("App2 escuchando en puerto 8002"));
