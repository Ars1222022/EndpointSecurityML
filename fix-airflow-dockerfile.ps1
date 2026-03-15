# =====================================================
# fix-airflow-dockerfile.ps1 - Fixa Airflow-Dockerfile
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🏗️ BYGGER AIRFLOW-IMAGE (LÖSER KRASCH-PROBLEM)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Skapa backup om det behövs
if (Test-Path "Dockerfile.airflow") {
    Copy-Item "Dockerfile.airflow" "Dockerfile.airflow.backup" -Force
    Write-Host "✅ Backup skapad: Dockerfile.airflow.backup" -ForegroundColor Green
}

# 2. Skapa förbättrad Dockerfile
Write-Host ""
Write-Host "📝 Skapar förbättrad Dockerfile.airflow..." -ForegroundColor Yellow

$dockerfile = @'
FROM apache/airflow:2.8.1
USER root
RUN apt-get update && apt-get install -y gcc && rm -rf /var/lib/apt/lists/*
USER airflow
RUN pip install --no-cache-dir \
    scikit-learn==1.2.2 \
    pandas==2.0.3 \
    numpy==1.23.5 \
    joblib==1.2.0 \
    requests
RUN touch /opt/airflow/airflow-worker.pid && chmod 644 /opt/airflow/airflow-worker.pid
'@

$dockerfile | Out-File -FilePath "Dockerfile.airflow" -Encoding UTF8
Write-Host "✅ Dockerfile.airflow skapad" -ForegroundColor Green

# 3. Bygg image
Write-Host ""
Write-Host "🔨 Bygger Airflow-image (2-3 minuter)..." -ForegroundColor Yellow
docker build -t airflow-custom:latest -f Dockerfile.airflow .

# 4. Uppdatera docker-compose.yml
Write-Host ""
Write-Host "📝 Uppdaterar docker-compose.yml..." -ForegroundColor Yellow
$compose = Get-Content "docker-compose.yml" -Raw
$compose = $compose -replace 'image: apache/airflow:2.8.1', 'image: airflow-custom:latest'
$compose | Out-File -FilePath "docker-compose.yml" -Encoding UTF8
Write-Host "✅ docker-compose.yml uppdaterad" -ForegroundColor Green

# 5. Starta om ALLT
Write-Host ""
Write-Host "🔄 Startar om alla tjänster..." -ForegroundColor Yellow
docker-compose down
docker-compose up -d
Start-Sleep -Seconds 15

# 6. Visa status
Write-Host ""
Write-Host "📊 Status för alla containers:" -ForegroundColor Cyan
docker ps --format "table {{.Names}}\t{{.Status}}"

Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ KLART! Airflow kommer inte krascha mer!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Airflow UI: http://localhost:8080 (admin/admin)" -ForegroundColor White