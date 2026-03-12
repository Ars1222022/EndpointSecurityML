# =====================================================
# fix-airflow.ps1 - Fixar sklearn-problem i Airflow
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🔧 FIXAR AIRFLOW - INSTALLERAR SAKNADE PAKET" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Installera i alla containers
Write-Host "1️⃣ Installerar scikit-learn i webservern..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-webserver-1 pip install scikit-learn pandas numpy joblib

Write-Host "2️⃣ Installerar i schedulern..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-scheduler-1 pip install scikit-learn pandas numpy joblib

Write-Host "3️⃣ Installerar i workern..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-worker-1 pip install scikit-learn pandas numpy joblib

Write-Host "4️⃣ Startar om Airflow-containers..." -ForegroundColor Yellow
docker-compose restart airflow-webserver airflow-scheduler airflow-worker

Write-Host ""
Write-Host "✅ KLART! Ladda om Airflow UI (F5)" -ForegroundColor Green
