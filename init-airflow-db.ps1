# =====================================================
# init-airflow-db.ps1 - Initierar Airflow och installerar paket
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🗄️  INITIERAR AIRFLOW DATABAS" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Starta postgres och redis först
Write-Host "1️⃣ Startar postgres och redis..." -ForegroundColor Yellow
docker-compose up -d postgres redis
Start-Sleep -Seconds 10

# 2. Initiera databasen
Write-Host "2️⃣ Initierar Airflow-databasen..." -ForegroundColor Yellow
docker run --rm `
  --network endpointsecurityml_default `
  -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres/airflow `
  apache/airflow:2.8.1 `
  airflow db init

# 3. Skapa admin-användare
Write-Host "3️⃣ Skapar admin-användare..." -ForegroundColor Yellow
docker run --rm `
  --network endpointsecurityml_default `
  -e AIRFLOW__DATABASE__SQL_ALCHEMY_CONN=postgresql+psycopg2://airflow:airflow@postgres/airflow `
  apache/airflow:2.8.1 `
  airflow users create `
  --username admin `
  --firstname Admin `
  --lastname User `
  --role Admin `
  --email admin@example.com `
  --password admin

# 4. Starta alla Airflow-containers
Write-Host "4️⃣ Startar Airflow-containers..." -ForegroundColor Yellow
docker-compose up -d airflow-webserver airflow-scheduler airflow-worker

# 5. Vänta att de startar
Start-Sleep -Seconds 20

# 6. Installera scikit-learn i alla containers (Airflow-version 1.2.2)
Write-Host "5️⃣ Installerar scikit-learn i Airflow-containers..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-webserver-1 pip install scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0
docker exec endpointsecurityml-airflow-scheduler-1 pip install scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0
docker exec endpointsecurityml-airflow-worker-1 pip install scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0

# 7. Starta om Airflow-containers
Write-Host "6️⃣ Startar om Airflow-containers..." -ForegroundColor Yellow
docker-compose restart airflow-webserver airflow-scheduler airflow-worker

Write-Host ""
Write-Host "✅ KLART!" -ForegroundColor Green
Write-Host "Starta resten: docker-compose up -d mlflow api" -ForegroundColor Yellow
Write-Host "Öppna: http://localhost:8080/login (admin/admin)" -ForegroundColor Yellow
