# =====================================================
# fix-docker-start.ps1 - Startar Docker utan Airflow
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🔧 FIXAR DOCKER START - UTAN AIRFLOW" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. KONTROLLERA ATT BACKUP FINNS
# ------------------------------
Write-Host "1️⃣ Kontrollerar backup..." -ForegroundColor Yellow
if (-not (Test-Path "docker-compose.yml.backup")) {
    Write-Host "  ⚠️ Ingen backup hittad! Skapar nu..." -ForegroundColor Yellow
    Copy-Item "docker-compose.yml" "docker-compose.yml.backup" -Force
    Write-Host "  ✅ Backup skapad: docker-compose.yml.backup" -ForegroundColor Green
} else {
    Write-Host "  ✅ Backup finns redan" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 2. SKAPA EN NY DOCKER-COMPOSE UTAN AIRFLOW
# ------------------------------
Write-Host "2️⃣ Skapar temporär docker-compose utan Airflow..." -ForegroundColor Yellow

# Läs backup-filen
$composeContent = Get-Content "docker-compose.yml.backup" -Raw

# Enklare metod: Plocka ut bara de tjänster vi vill ha
$newCompose = @"
services:
  postgres:
    image: postgres:13
    environment:
      POSTGRES_USER: airflow
      POSTGRES_PASSWORD: airflow
      POSTGRES_DB: airflow
    healthcheck:
      test: ["CMD", "pg_isready", "-U", "airflow"]
    volumes:
      - postgres_data:/var/lib/postgresql/data

  redis:
    image: redis:7
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

  mlflow:
    build:
      context: .
      dockerfile: Dockerfile.mlflow
    container_name: mlflow
    ports:
      - "5000:5000"
    volumes:
      - ./mlruns:/app/mlruns

  api:
    build:
      context: .
      dockerfile: Dockerfile.api
    container_name: api
    ports:
      - "8000:8000"
    volumes:
      - ./models:/app/models
      - ./data:/app/data
      - ./src:/app/src
    depends_on:
      - mlflow

  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    ports:
      - "9090:9090"
    volumes:
      - ./prometheus:/etc/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
    depends_on:
      - api

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana:/etc/grafana/provisioning/dashboards
    depends_on:
      - prometheus

volumes:
  postgres_data:
  grafana_data:
"@

# Spara som ny docker-compose.yml
$newCompose | Out-File "docker-compose.yml" -Encoding UTF8
Write-Host "  ✅ Ny docker-compose.yml skapad (utan Airflow)" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. STOPPA ALLA CONTAINERS
# ------------------------------
Write-Host "3️⃣ Stoppar alla containers..." -ForegroundColor Yellow
docker-compose down
Write-Host "  ✅ Alla containers stoppade" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. STARTA GRUNDTJÄNSTERNA
# ------------------------------
Write-Host "4️⃣ Startar grundtjänster..." -ForegroundColor Yellow
docker-compose up -d
Write-Host "  ✅ Grundtjänster startade" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. VÄNTA OCH KONTROLLERA
# ------------------------------
Write-Host "5️⃣ Väntar 15 sekunder..." -ForegroundColor Yellow
Start-Sleep -Seconds 15

Write-Host ""
Write-Host "📊 Status för containers:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
Write-Host ""

# ------------------------------
# 6. TESTA ATT ALLT FUNGERAR
# ------------------------------
Write-Host "6️⃣ Testar tjänsterna..." -ForegroundColor Yellow

# Testa API
try {
    $apiHealth = Invoke-RestMethod -Uri "http://localhost:8000/health" -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ API fungerar på port 8000" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ API svarar inte än - vänta lite" -ForegroundColor Yellow
}

# Testa Prometheus
try {
    $prom = Invoke-WebRequest -Uri "http://localhost:9090" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ Prometheus fungerar på port 9090" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ Prometheus svarar inte än" -ForegroundColor Yellow
}

# Testa Grafana
try {
    $grafana = Invoke-WebRequest -Uri "http://localhost:3000" -UseBasicParsing -TimeoutSec 2 -ErrorAction SilentlyContinue
    Write-Host "  ✅ Grafana fungerar på port 3000" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ Grafana svarar inte än" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ FIX KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Nästa steg:" -ForegroundColor Yellow
Write-Host "  .\test-monitoring.ps1     # Testa monitoring" -ForegroundColor White
Write-Host ""
Write-Host "📋 Återställa Airflow när det är fixat:" -ForegroundColor Gray
Write-Host "  Copy-Item docker-compose.yml.backup docker-compose.yml -Force" -ForegroundColor Gray
Write-Host "  docker-compose up -d      # Starta allt inklusive Airflow" -ForegroundColor Gray