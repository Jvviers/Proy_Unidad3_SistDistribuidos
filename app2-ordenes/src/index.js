const express = require("express");
const { Pool } = require("pg");

const app = express();
app.use(express.json());

const pool = new Pool({
  host: process.env.DB_HOST || "postgres-primary",
  port: process.env.DB_PORT ? Number(process.env.DB_PORT) : 5432,
  user: process.env.DB_USER || "orders",
  password: process.env.DB_PASS || "orders123",
  database: process.env.DB_NAME || "ordersdb",
});

async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS orders (
      id SERIAL PRIMARY KEY,
      product_id INT,
      qty INT,
      status VARCHAR(50) DEFAULT 'created'
    )
  `);
}

app.get("/health", async (req, res) => {
  try {
    await ensureSchema();
    res.json({ status: "ok", service: "app2-ordenes" });
  } catch (err) {
    res.status(500).json({ status: "error", error: err.message });
  }
});

app.get("/orders", async (req, res) => {
  try {
    const { rows } = await pool.query("SELECT id, product_id, qty, status FROM orders");
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/orders", async (req, res) => {
  const { product_id, qty } = req.body || {};
  if (!product_id || !qty) {
    return res.status(400).json({ error: "product_id y qty son requeridos" });
  }
  try {
    const { rows } = await pool.query(
      "INSERT INTO orders (product_id, qty) VALUES ($1, $2) RETURNING id, product_id, qty, status",
      [product_id, qty]
    );
    res.status(201).json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.post("/orders/:id/status", async (req, res) => {
  const id = req.params.id;
  const { status } = req.body || {};
  if (!status) {
    return res.status(400).json({ error: "status requerido" });
  }
  try {
    const { rows } = await pool.query(
      "UPDATE orders SET status=$1 WHERE id=$2 RETURNING id, product_id, qty, status",
      [status, id]
    );
    if (!rows.length) return res.status(404).json({ error: "orden no encontrada" });
    res.json(rows[0]);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.listen(8002, () => console.log("App2 escuchando en puerto 8002"));
