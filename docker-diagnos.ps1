# =====================================================
# docker-diagnos.ps1 - Testar att alla containers fungerar
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🐳 DOCKER DIAGNOS - TESTAR ALLA CONTAINERS" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. LISTA ALLA CONTAINERS
# ------------------------------
Write-Host "1️⃣ Listar alla containers (körs just nu):" -ForegroundColor Yellow
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

# ------------------------------
# 2. KOLLA SPECIFIKT AIRFLOW-WORKER
# ------------------------------
Write-Host "2️⃣ Kontrollerar airflow-worker-1..." -ForegroundColor Yellow
$workerStatus = docker ps --filter "name=airflow-worker-1" --format "table {{.Status}}"

if ($workerStatus -like "*Up*") {
    Write-Host "  ✅ airflow-worker-1 är igång!" -ForegroundColor Green
} else {
    Write-Host "  ❌ airflow-worker-1 är INTE igång!" -ForegroundColor Red
    Write-Host ""
    Write-Host "  📋 Loggar från worker:" -ForegroundColor Yellow
    docker logs --tail 20 airflow-worker-1
}
Write-Host ""

# ------------------------------
# 3. KOLLA ALLA AIRFLOW-CONTAINERS
# ------------------------------
Write-Host "3️⃣ Status för Airflow-containers:" -ForegroundColor Yellow
$airflowContainers = @("airflow-webserver-1", "airflow-scheduler-1", "airflow-worker-1", "postgres-1", "redis-1")

foreach ($container in $airflowContainers) {
    $status = docker ps --filter "name=$container" --format "{{.Status}}"
    if ($status -like "*Up*") {
        Write-Host "  ✅ $container - OK" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $container - STOPPAD" -ForegroundColor Red
    }
}
Write-Host ""

# ------------------------------
# 4. KOLLA OM AIRFLOW-WORKER HAR STARTAT KORREKT
# ------------------------------
Write-Host "4️⃣ Kollar om worker har registrerat sig..." -ForegroundColor Yellow
$workerLogs = docker logs --tail 5 airflow-worker-1 2>&1
if ($workerLogs -like "*connected*") {
    Write-Host "  ✅ Worker är ansluten till schedulern" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Worker kanske inte är ansluten än - vänta lite" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 5. TESTA ATT AIRFLOW UI FUNGERAR
# ------------------------------
Write-Host "5️⃣ Testar Airflow UI..." -ForegroundColor Yellow
try {
    $response = Invoke-WebRequest -Uri "http://localhost:8080" -UseBasicParsing -TimeoutSec 2
    Write-Host "  ✅ Airflow UI svarar på port 8080" -ForegroundColor Green
} catch {
    Write-Host "  ❌ Airflow UI svarar inte på port 8080" -ForegroundColor Red
}
Write-Host ""

# ------------------------------
# 6. STARTA OM WORKER OM DEN INTE FUNGERAR
# ------------------------------
if ($workerStatus -notlike "*Up*") {
    Write-Host "6️⃣ Försöker starta om worker..." -ForegroundColor Yellow
    docker start airflow-worker-1
    Start-Sleep -Seconds 5
    
    $newStatus = docker ps --filter "name=airflow-worker-1" --format "{{.Status}}"
    if ($newStatus -like "*Up*") {
        Write-Host "  ✅ Worker startad!" -ForegroundColor Green
    } else {
        Write-Host "  ❌ Worker startade inte - kollar loggar:" -ForegroundColor Red
        docker logs --tail 20 airflow-worker-1
    }
}
Write-Host ""

# ------------------------------
# 7. SAMMANFATTNING
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📋 SAMMANFATTNING" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$allGood = $true
$totalContainers = 0
$runningContainers = 0

$allContainers = @("airflow-webserver-1", "airflow-scheduler-1", "airflow-worker-1", "postgres-1", "redis-1", "api-1", "mlflow-1")

foreach ($container in $allContainers) {
    $totalContainers++
    $status = docker ps --filter "name=$container" --format "{{.Status}}"
    if ($status -like "*Up*") {
        $runningContainers++
        Write-Host "  ✅ $container" -ForegroundColor Green
    } else {
        $allGood = $false
        Write-Host "  ❌ $container" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "📊 Status: $runningContainers av $totalContainers containers kör" -ForegroundColor Yellow

if ($allGood) {
    Write-Host ""
    Write-Host "🎉 ALLT FUNGERAR! Alla containers är igång!" -ForegroundColor Green
    Write-Host ""
    Write-Host "📋 Dina tjänster:" -ForegroundColor Cyan
    Write-Host "  • Airflow UI: http://localhost:8080 (admin/admin)" -ForegroundColor White
    Write-Host "  • MLflow UI: http://localhost:5000" -ForegroundColor White
    Write-Host "  • API Docs: http://localhost:8000/docs" -ForegroundColor White
} else {
    Write-Host ""
    Write-Host "⚠️ Vissa containers fungerar inte. Försök:" -ForegroundColor Yellow
    Write-Host "  1. docker-compose down" -ForegroundColor White
    Write-Host "  2. docker-compose up -d" -ForegroundColor White
    Write-Host "  3. Kör det här skriptet igen" -ForegroundColor White
}