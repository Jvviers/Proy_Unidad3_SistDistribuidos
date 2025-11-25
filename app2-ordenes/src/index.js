const express = require("express");
const app = express();

app.get("/health", (req, res) => {
  res.json({ status: "ok", service: "app2-ordenes" });
});

app.get("/test", (req, res) => {
  res.json({ msg: "API Ordenes funcionando" });
});

app.listen(8002, () => console.log("App2 escuchando en puerto 8002"));
