# =====================================================
# setup-airflow.ps1 - EXTREMT ENKEL VERSION (MED FIXAR)
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "⏰ APACHE AIRFLOW - ENKEL SETUP" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. HITTA PROJEKTROTEN
# ------------------------------
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot
Write-Host "📁 Projektmapp: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 2. SKAPA AIRFLOW-MAPPAR
# ------------------------------
Write-Host "1️⃣ Skapar Airflow-mappar..." -ForegroundColor Yellow
mkdir -Force airflow\dags, airflow\logs, airflow\plugins | Out-Null
Write-Host "  ✅ Mappar skapade" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. SKAPA ML_TRANING_DAG.PY
# ------------------------------
Write-Host "2️⃣ Skapar ML Training DAG..." -ForegroundColor Yellow
$mlDag = @'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import glob
import os

default_args = {
    'owner': 'ml_team',
    'start_date': datetime(2026, 3, 1),
    'retries': 1,
}

dag = DAG('ml_training', default_args=default_args, schedule_interval='0 3 * * *')

def train():
    files = glob.glob('/opt/airflow/data/raw/*.csv')
    if not files: return "No data"
    latest = max(files, key=os.path.getctime)
    df = pd.read_csv(latest)
    df['IsSuspicious'] = df['ProcessName'].isin(['powershell.exe','cmd.exe','wannacry.exe']).astype(int)
    X = df[['NetworkConnections','IsSuspicious']]
    y = df['IsAttack']
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X_train, y_train)
    acc = float(accuracy_score(y_test, model.predict(X_test)))
    path = f'/opt/airflow/models/production/model_{datetime.now().strftime("%Y%m%d_%H%M%S")}.pkl'
    joblib.dump(model, path)
    return f"Accuracy: {acc:.3f}"

PythonOperator(task_id='train', python_callable=train, dag=dag)
'@
Set-Content -Path "airflow\dags\ml_training_dag.py" -Value $mlDag -Encoding UTF8
Write-Host "  ✅ ml_training_dag.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. SKAPA MONITORING_DAG.PY
# ------------------------------
Write-Host "3️⃣ Skapar Monitoring DAG..." -ForegroundColor Yellow
$monDag = @'
from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import requests

default_args = {'owner': 'ml_team', 'start_date': datetime(2026, 3, 1)}
dag = DAG('api_monitoring', default_args=default_args, schedule_interval='0 * * * *')

def check():
    r = requests.get("http://api:8000/health", timeout=5)
    return "OK" if r.status_code == 200 else "Fail"

PythonOperator(task_id='check', python_callable=check, dag=dag)
'@
Set-Content -Path "airflow\dags\monitoring_dag.py" -Value $monDag -Encoding UTF8
Write-Host "  ✅ monitoring_dag.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. SKAPA DOCKER-COMPOSE.YML (UPPDATERAD MED ALLA ENV VARIABLER)
# ------------------------------
Write-Host "4️⃣ Skapar docker-compose.yml..." -ForegroundColor Yellow
$compose = @'
version: '3.8'
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

  airflow-webserver:
    image: apache/airflow:2.8.1
    command: webserver
    ports:
      - "8080:8080"
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://redis:6379/0
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      _PIP_ADDITIONAL_REQUIREMENTS: "scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0 requests"
    volumes:
      - ./airflow/dags:/opt/airflow/dags
      - ./airflow/logs:/opt/airflow/logs
      - ./airflow/plugins:/opt/airflow/plugins
      - ./models:/opt/airflow/models
      - ./data:/opt/airflow/data
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  airflow-scheduler:
    image: apache/airflow:2.8.1
    command: scheduler
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://redis:6379/0
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      _PIP_ADDITIONAL_REQUIREMENTS: "scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0 requests"
    volumes:
      - ./airflow/dags:/opt/airflow/dags
      - ./airflow/logs:/opt/airflow/logs
      - ./airflow/plugins:/opt/airflow/plugins
      - ./models:/opt/airflow/models
      - ./data:/opt/airflow/data
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

  airflow-worker:
    image: apache/airflow:2.8.1
    command: celery worker
    environment:
      AIRFLOW__CORE__EXECUTOR: CeleryExecutor
      AIRFLOW__DATABASE__SQL_ALCHEMY_CONN: postgresql+psycopg2://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__RESULT_BACKEND: db+postgresql://airflow:airflow@postgres/airflow
      AIRFLOW__CELERY__BROKER_URL: redis://redis:6379/0
      AIRFLOW__CORE__LOAD_EXAMPLES: 'false'
      _PIP_ADDITIONAL_REQUIREMENTS: "scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0 requests"
    volumes:
      - ./airflow/dags:/opt/airflow/dags
      - ./airflow/logs:/opt/airflow/logs
      - ./airflow/plugins:/opt/airflow/plugins
      - ./models:/opt/airflow/models
      - ./data:/opt/airflow/data
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy

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

volumes:
  postgres_data:
'@
Set-Content -Path "docker-compose.yml" -Value $compose -Encoding UTF8
Write-Host "  ✅ docker-compose.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. SKAPA INIT-SKRIPT (UPPDATERAD MED PACKAGE INSTALLATION)
# ------------------------------
Write-Host "5️⃣ Skapar init-airflow-db.ps1..." -ForegroundColor Yellow
$init = @'
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

# 6. Installera scikit-learn i alla containers
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
Write-Host "Öppna: http://localhost:8080 (admin/admin)" -ForegroundColor Yellow
'@
Set-Content -Path "init-airflow-db.ps1" -Value $init -Encoding UTF8
Write-Host "  ✅ init-airflow-db.ps1 skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. SKAPA README (ENKELT)
# ------------------------------
Write-Host "6️⃣ Skapar instruktioner..." -ForegroundColor Yellow
mkdir -Force docs | Out-Null
$readme = @"
# Airflow

## Dina DAGar
- ml_training: Körs 03:00 dagligen
- api_monitoring: Körs varje timme

## Kom igång
1. .\init-airflow-db.ps1
2. docker-compose up -d
3. http://localhost:8080 (admin/admin)
"@
Set-Content -Path "docs\AIRFLOW.md" -Value $readme -Encoding UTF8
Write-Host "  ✅ docs/AIRFLOW.md skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. SKAPA FIX-SKRIPT (FÖR ATT ÅTERSTÄLLA OM PROBLEM)
# ------------------------------
Write-Host "7️⃣ Skapar fix-airflow.ps1..." -ForegroundColor Yellow
$fixScript = @'
# =====================================================
# fix-airflow.ps1 - Fixar sklearn-problem i Airflow
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🔧 FIXAR AIRFLOW - INSTALLERAR SAKNADE PAKET" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Installera i alla containers
Write-Host "1️⃣ Installerar scikit-learn i webservern..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-webserver-1 pip install scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0

Write-Host "2️⃣ Installerar i schedulern..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-scheduler-1 pip install scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0

Write-Host "3️⃣ Installerar i workern..." -ForegroundColor Yellow
docker exec endpointsecurityml-airflow-worker-1 pip install scikit-learn==1.2.2 pandas==2.0.3 numpy==1.23.5 joblib==1.2.0

Write-Host "4️⃣ Startar om Airflow-containers..." -ForegroundColor Yellow
docker-compose restart airflow-webserver airflow-scheduler airflow-worker

Write-Host ""
Write-Host "✅ KLART! Ladda om Airflow UI (F5)" -ForegroundColor Green
'@
Set-Content -Path "fix-airflow.ps1" -Value $fixScript -Encoding UTF8
Write-Host "  ✅ fix-airflow.ps1 skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 9. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ AIRFLOW SETUP KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 KÖR I ORDNING:" -ForegroundColor Yellow
Write-Host "  1. .\init-airflow-db.ps1" -ForegroundColor White
Write-Host "  2. docker-compose up -d" -ForegroundColor White
Write-Host "  3. Öppna http://localhost:8080" -ForegroundColor White
Write-Host ""
Write-Host "📋 OM DET INTE FUNGERAR:" -ForegroundColor Yellow
Write-Host "  Kör .\fix-airflow.ps1" -ForegroundColor White