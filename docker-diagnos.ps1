# =====================================================
# docker-diagnos.ps1 - DIAGNOSTISERA ALLA CONTAINERS
# =====================================================
# Anpassad för EndpointSecurityML-projektet
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🐳 DOCKER DIAGNOS - ENDPOINTSECURITYML" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. LISTA ALLA CONTAINERS
# ------------------------------
Write-Host "1️⃣ Listar alla containers (körs just nu):" -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

# ------------------------------
# 2. KOLLA ALLA AIRFLOW-CONTAINERS
# ------------------------------
Write-Host "2️⃣ Status för Airflow-containers:" -ForegroundColor Yellow
$airflowContainers = @(
    "endpointsecurityml-airflow-webserver-1", 
    "endpointsecurityml-airflow-scheduler-1", 
    "endpointsecurityml-airflow-worker-1",
    "endpointsecurityml-postgres-1", 
    "endpointsecurityml-redis-1"
)
$airflowOK = $true

foreach ($container in $airflowContainers) {
    $status = docker ps --filter "name=$container" --format "{{.Status}}"
    if ($status -like "*Up*") {
        Write-Host "  ✅ $container - OK" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $container - STOPPAD" -ForegroundColor Red
        $airflowOK = $false
    }
}
Write-Host ""

# ------------------------------
# 3. KOLLA OM AIRFLOW-WORKER ÄR ANSLUTEN
# ------------------------------
if ($airflowOK) {
    Write-Host "3️⃣ Kontrollerar Airflow-worker anslutning..." -ForegroundColor Yellow
    $workerLogs = docker logs --tail 5 endpointsecurityml-airflow-worker-1 2>&1
    if ($workerLogs -like "*ready*") {
        Write-Host "  ✅ Worker är redo och ansluten till schedulern" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Worker startar fortfarande (vänta 30 sek)" -ForegroundColor Yellow
    }
    Write-Host ""
}

# ------------------------------
# 4. KOLLA ANDRA TJÄNSTER (API, MLflow, Monitoring)
# ------------------------------
Write-Host "4️⃣ Status för övriga tjänster:" -ForegroundColor Yellow

# API
$apiStatus = docker ps --filter "name=api" --format "{{.Status}}"
if ($apiStatus -like "*Up*") {
    Write-Host "  ✅ api - OK" -ForegroundColor Green
} else {
    Write-Host "  ❌ api - STOPPAD" -ForegroundColor Red
}

# MLflow
$mlflowStatus = docker ps --filter "name=mlflow" --format "{{.Status}}"
if ($mlflowStatus -like "*Up*") {
    Write-Host "  ✅ mlflow - OK" -ForegroundColor Green
} else {
    Write-Host "  ❌ mlflow - STOPPAD" -ForegroundColor Red
}

# Prometheus
$promStatus = docker ps --filter "name=prometheus" --format "{{.Status}}"
if ($promStatus -like "*Up*") {
    Write-Host "  ✅ prometheus - OK" -ForegroundColor Green
} else {
    Write-Host "  ❌ prometheus - STOPPAD" -ForegroundColor Red
}

# Grafana
$grafanaStatus = docker ps --filter "name=grafana" --format "{{.Status}}"
if ($grafanaStatus -like "*Up*") {
    Write-Host "  ✅ grafana - OK" -ForegroundColor Green
} else {
    Write-Host "  ❌ grafana - STOPPAD" -ForegroundColor Red
}
Write-Host ""

# ------------------------------
# 5. TESTA ATT TJÄNSTERNA SVARAR
# ------------------------------
Write-Host "5️⃣ Testar att tjänsterna svarar:" -ForegroundColor Yellow

# Testa Airflow UI
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ Airflow UI svarar på port 8080" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Airflow UI svarar inte på port 8080" -ForegroundColor Red
}

# Testa API health
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8000/health" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    if ($response.Content -match "model_loaded") {
        Write-Host "  ✅ API svarar på port 8000 (med modell)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ API svarar men ingen modell laddad" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ❌ API svarar inte på port 8000" -ForegroundColor Red
}

# Testa MLflow UI
try {
    $response = Invoke-WebRequest -Uri "http://localhost:5000" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ MLflow UI svarar på port 5000" -ForegroundColor Green
} catch {
    Write-Host "  ❌ MLflow UI svarar inte på port 5000" -ForegroundColor Red
}

# Testa Grafana
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ Grafana svarar på port 3000" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Grafana svarar inte på port 3000" -ForegroundColor Red
}

# Testa Prometheus
try {
    $response = Invoke-WebRequest -Uri "http://localhost:9090" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ Prometheus svarar på port 9090" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Prometheus svarar inte på port 9090" -ForegroundColor Red
}
Write-Host ""

# ------------------------------
# 6. RÄKNA STATISTIK
# ------------------------------
Write-Host "6️⃣ Sammanställning:" -ForegroundColor Yellow

$allContainers = @(
    "endpointsecurityml-airflow-webserver-1", 
    "endpointsecurityml-airflow-scheduler-1", 
    "endpointsecurityml-airflow-worker-1",
    "endpointsecurityml-postgres-1", 
    "endpointsecurityml-redis-1",
    "api",
    "mlflow",
    "prometheus",
    "grafana"
)

$totalContainers = $allContainers.Count
$runningContainers = 0

foreach ($container in $allContainers) {
    $status = docker ps --filter "name=$container" --format "{{.Status}}"
    if ($status -like "*Up*") {
        $runningContainers++
    }
}

Write-Host "  📊 Status: $runningContainers av $totalContainers containers kör" -ForegroundColor White

if ($runningContainers -eq $totalContainers) {
    Write-Host ""
    Write-Host "🎉 ALLT FUNGERAR! Alla containers är igång!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 DINA TJÄNSTER:" -ForegroundColor Cyan
    Write-Host "  • Airflow UI: http://localhost:8080 (admin/admin)" -ForegroundColor White
    Write-Host "  • MLflow UI: http://localhost:5000" -ForegroundColor White
    Write-Host "  • API Docs: http://localhost:8000/docs" -ForegroundColor White
    Write-Host "  • Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
    Write-Host "  • Prometheus: http://localhost:9090" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "⚠️ Några containers fungerar inte. Försök:" -ForegroundColor Yellow
    Write-Host "  1. docker-compose down" -ForegroundColor White
    Write-Host "  2. docker-compose up -d" -ForegroundColor White
    Write-Host "  3. Kör det här skriptet igen" -ForegroundColor White
    Write-Host ""
    Write-Host "📋 Om Airflow-worker krånglar:" -ForegroundColor Yellow
    Write-Host "  Kör: .\fix-airflow-dockerfile.ps1" -ForegroundColor White
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ DIAGNOS KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan