# =====================================================
# create-docker-compose.ps1 - Skapar komplett docker-compose.yml
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🐳 SKAPAR KOMPLETT DOCKER-COMPOSE.YML (MED MONITORING)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Skapa backup om filen redan finns
if (Test-Path "docker-compose.yml") {
    Copy-Item "docker-compose.yml" "docker-compose.yml.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')" -Force
    Write-Host "✅ Backup skapad av befintlig docker-compose.yml" -ForegroundColor Green
}

# 2. Definiera innehållet
$composeContent = @'
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
'@

# 3. Spara filen
$composeContent | Out-File -FilePath "docker-compose.yml" -Encoding UTF8

Write-Host "✅ docker-compose.yml har skapats!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 TJÄNSTER SOM INGÅR:" -ForegroundColor Cyan
Write-Host "  • postgres (databas för Airflow)" -ForegroundColor White
Write-Host "  • redis (cache för Airflow)" -ForegroundColor White
Write-Host "  • airflow-webserver (port 8080)" -ForegroundColor White
Write-Host "  • airflow-scheduler" -ForegroundColor White
Write-Host "  • airflow-worker" -ForegroundColor White
Write-Host "  • mlflow (port 5000)" -ForegroundColor White
Write-Host "  • api (port 8000)" -ForegroundColor White
Write-Host "  • prometheus (port 9090)" -ForegroundColor Green
Write-Host "  • grafana (port 3000)" -ForegroundColor Green
Write-Host ""
Write-Host "📋 KOMMANDON:" -ForegroundColor Yellow
Write-Host "  docker-compose up -d      # Starta ALLA tjänster" -ForegroundColor White
Write-Host "  docker-compose stop       # Stoppa ALLA tjänster" -ForegroundColor White
Write-Host "  docker-compose down       # Stoppa och ta bort ALLA containers" -ForegroundColor White
Write-Host "  docker-compose logs -f    # Se loggar från ALLA tjänster" -ForegroundColor White
Write-Host ""
Write-Host "📋 TESTA:" -ForegroundColor Green
Write-Host "  curl http://localhost:8000/health    # API" -ForegroundColor White
Write-Host "  http://localhost:5000                # MLflow" -ForegroundColor White
Write-Host "  http://localhost:8080                # Airflow (admin/admin)" -ForegroundColor White
Write-Host "  http://localhost:3000                # Grafana (admin/admin)" -ForegroundColor White
Write-Host "  http://localhost:9090                # Prometheus" -ForegroundColor White