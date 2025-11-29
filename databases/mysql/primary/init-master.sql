CREATE USER IF NOT EXISTS 'repl'@'%' IDENTIFIED BY 'replpass';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;

CREATE DATABASE IF NOT EXISTS reportsdb;
USE reportsdb;
CREATE TABLE IF NOT EXISTS reports (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255),
    value INT
);
INSERT INTO reports (name, value) VALUES ('reporte_inicial', 1)
ON DUPLICATE KEY UPDATE value = value;

