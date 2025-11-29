CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS inventorydb;
USE inventorydb;
CREATE TABLE IF NOT EXISTS products (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    stock INT
);
INSERT INTO products (name, stock) VALUES ('Producto inicial', 100)
ON DUPLICATE KEY UPDATE stock = stock;
