# =====================================================
# test-monitoring.ps1 - Testar Prometheus & Grafana
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📊 TESTAR PROMETHEUS & GRAFANA" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1️⃣ Testar Prometheus..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9090" -UseBasicParsing -TimeoutSec 2
    Write-Host "  ✅ Prometheus OK på port 9090" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ Prometheus startar (vänta 30 sekunder)" -ForegroundColor Yellow
}

Write-Host "2️⃣ Testar Grafana..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2
    Write-Host "  ✅ Grafana OK på port 3000" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ Grafana startar (vänta 30 sekunder)" -ForegroundColor Yellow
}

Write-Host "3️⃣ Testar metrics-endpoint..."
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8000/metrics" -UseBasicParsing -TimeoutSec 2
    if ($response.Content -match "http_requests_total") {
        Write-Host "  ✅ Metrics fungerar!" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Metrics endpoint svarar men ingen data än" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ Metrics endpoint fungerar inte" -ForegroundColor Red
}

Write-Host ""
Write-Host "📋 NÄSTA STEG:" -ForegroundColor Yellow
Write-Host "  1. Öppna Grafana: http://localhost:3000 (admin/admin)"
Write-Host "  2. Lägg till Prometheus som datakälla (http://prometheus:9090)"
Write-Host "  3. Importera dashboard från grafana/dashboard.json"
Write-Host "  4. Gör några anrop till API:et och se data!"
