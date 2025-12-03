CREATE USER replication WITH REPLICATION ENCRYPTED PASSWORD 'replpass';
-- Usuario superusuario para promoción desde watchdog
DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'failover') THEN
      CREATE ROLE failover WITH SUPERUSER LOGIN PASSWORD 'failover123';
   END IF;
END $$;

DO $$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_database WHERE datname = 'ordersdb') THEN
      CREATE DATABASE ordersdb;
   END IF;
END $$;

\c ordersdb;

CREATE TABLE IF NOT EXISTS orders (
    id SERIAL PRIMARY KEY,
    product_id INT NOT NULL,
    qty INT NOT NULL,
    status TEXT DEFAULT 'created',
    created_at TIMESTAMP DEFAULT now()
);
