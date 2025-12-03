Param(
    [string]$OutputDir = "tests/evidencias"
)

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$outPath = Join-Path -Path $PSScriptRoot -ChildPath $OutputDir
New-Item -ItemType Directory -Force -Path $outPath | Out-Null
$file = Join-Path -Path $outPath -ChildPath ("{0}-postgres.txt" -f $timestamp)

function Section {
    param($Title, $Content)
    Add-Content -Path $file -Value "###### $Title ######"
    Add-Content -Path $file -Value $Content
    Add-Content -Path $file -Value "`n"
}

Section "Health inicial (PostgreSQL)" (Invoke-RestMethod -Method Get -Uri "http://localhost:8000/health" | ConvertTo-Json -Depth 5)
Section "Health app3" (Invoke-RestMethod -Method Get -Uri "http://localhost:8003/health" | ConvertTo-Json -Depth 5)

$stopOut = (docker compose stop postgres-primary 2>&1 | Out-String)
Section "Parada de primario (postgres-primary)" $stopOut

$ready = "Timeout"
for ($i=0; $i -lt 12; $i++) {
    docker compose exec postgres-replica pg_isready -h postgres-replica -U orders -d ordersdb 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) { $ready = "postgres-replica READY intento $i"; break }
    Start-Sleep -Seconds 5
}
Section "Esperando replica/promocion" $ready

$status = "OK"
$payload = ""
for ($i=0; $i -lt 10; $i++) {
    try {
        $resp = Invoke-RestMethod -Method Post -Uri "http://localhost:8000/orders" -Body '{"product_id":1,"qty":1}' -ContentType "application/json"
        $payload = $resp | ConvertTo-Json -Depth 8
        $status = "OK"
        break
    } catch {
        $status = "ERROR"
        $payload = $_ | Out-String
        Start-Sleep -Seconds 6
    }
}
Section "Resultado POST /orders [$status]" $payload

$logs = (docker compose logs --tail=200 postgres-watchdog postgres-haproxy 2>&1 | Out-String)
Section "Logs watchdog/HAProxy (PostgreSQL)" $logs

Section "Nota de recuperacion" "Tras el failover, reintegra primario/recrea volumenes segun PRUEBAS.md antes de operar en modo primario."

Write-Host "Evidencia generada en $file"
