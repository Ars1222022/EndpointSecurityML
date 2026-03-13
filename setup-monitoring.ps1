# =====================================================
# setup-monitoring.ps1 - ULTIMATA VERSIONEN (ALLA BUGGAR FIXADE)
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📊 PROMETHEUS & GRAFANA - ULTIMATA VERSIONEN" -ForegroundColor Cyan
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
# 2. SKAPA PROMETHEUS KONFIGURATION
# ------------------------------
Write-Host "1️⃣ Skapar Prometheus-konfiguration..." -ForegroundColor Yellow

$prometheusDir = Join-Path $ProjectRoot "prometheus"
New-Item -ItemType Directory -Path $prometheusDir -Force | Out-Null

$prometheusYml = @'
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: "fastapi"
    static_configs:
      - targets: ["api:8000"]
    metrics_path: /metrics
'@

Set-Content -Path (Join-Path $prometheusDir "prometheus.yml") -Value $prometheusYml -Encoding UTF8
Write-Host "  ✅ prometheus.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. SKAPA GRAFANA DASHBOARD (ENKEL VERSION SOM FUNGERAR)
# ------------------------------
Write-Host "2️⃣ Skapar Grafana dashboard..." -ForegroundColor Yellow

$grafanaDir = Join-Path $ProjectRoot "grafana"
New-Item -ItemType Directory -Path $grafanaDir -Force | Out-Null

$dashboardJson = @'
{
  "title": "ML API Monitoring",
  "panels": [
    {
      "title": "Requests per second",
      "targets": [{"expr": "rate(http_requests_total[1m])"}]
    },
    {
      "title": "Response time (ms)",
      "targets": [{"expr": "rate(http_request_duration_seconds_sum[1m]) / rate(http_request_duration_seconds_count[1m]) * 1000"}]
    },
    {
      "title": "Predictions by type",
      "targets": [{"expr": "predictions_total"}]
    },
    {
      "title": "Error rate (%)",
      "targets": [{"expr": "rate(http_errors_total[1m]) / rate(http_requests_total[1m]) * 100"}]
    },
    {
      "title": "CPU Usage (%)",
      "targets": [{"expr": "rate(app_cpu_seconds_total[1m]) * 100"}]
    },
    {
      "title": "Memory Usage (MB)",
      "targets": [{"expr": "app_memory_bytes / 1024 / 1024"}]
    },
    {
      "title": "Prediction Confidence (95th percentile)",
      "targets": [{"expr": "histogram_quantile(0.95, sum(rate(prediction_confidence_bucket[5m])) by (le))"}]
    }
  ]
}
'@

Set-Content -Path (Join-Path $grafanaDir "dashboard.json") -Value $dashboardJson -Encoding UTF8
Write-Host "  ✅ Grafana dashboard skapad (med 7 paneler)" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. SKAPA UPPDATERAD APP.PY (MED FIXADE METRIC-NAMN)
# ------------------------------
Write-Host "3️⃣ Skapar app.py med FIXADE metric-namn..." -ForegroundColor Yellow

$apiDir = Join-Path $ProjectRoot "src" "api"
New-Item -ItemType Directory -Path $apiDir -Force | Out-Null

$newAppPy = @'
"""
app.py - Huvud-API med Prometheus metrics (fixad version)
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
import joblib
import os
import time
import psutil
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
from .models import PredictionRequest, PredictionResponse, HealthResponse
from .utils import find_latest_model, prepare_features, get_threat_type

# ------------------------------
# Prometheus metrics (med unika namn - inga konflikter)
# ------------------------------
REQUEST_COUNT = Counter('http_requests_total', 'Totala antalet anrop', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Svarstider i sekunder', ['method', 'endpoint'])
PREDICTION_COUNT = Counter('predictions_total', 'Antal prediktioner', ['threat_type'])
MODEL_INFO = Counter('model_info', 'Information om modellen', ['version'])

# Extra metrics (med unika namn som inte krockar)
ERROR_COUNT = Counter('http_errors_total', 'Antal felanrop', ['method', 'endpoint'])
CPU_USAGE = Gauge('app_cpu_seconds_total', 'Appens CPU-användning')  # Ändrat från process_cpu_seconds_total
MEMORY_USAGE = Gauge('app_memory_bytes', 'Appens minnesanvändning')  # Ändrat namn för säkerhet
PREDICTION_CONFIDENCE = Histogram('prediction_confidence', 'Modellens confidence-värden', buckets=(0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99, 1.0))

app = FastAPI(title="Endpoint Security ML API")

model = None
model_version = None

# ------------------------------
# Middleware för metrics
# ------------------------------
@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    method = request.method
    endpoint = request.url.path
    
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    
    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=response.status_code).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)
    
    # Räkna fel (status >= 400)
    if response.status_code >= 400:
        ERROR_COUNT.labels(method=method, endpoint=endpoint).inc()
    
    return response

@app.on_event("startup")
async def load_model():
    """Laddar senaste modellen vid startup"""
    global model, model_version
    model_path = find_latest_model()
    
    if model_path:
        try:
            model = joblib.load(model_path)
            model_version = os.path.basename(model_path).replace("endpoint_model_", "").replace(".pkl", "")
            print(f"✅ Modell laddad: {model_path}")
            if model_version:
                MODEL_INFO.labels(version=model_version).inc()
        except Exception as e:
            print(f"❌ Kunde inte ladda modell: {e}")
    else:
        print("❌ Ingen modell hittad!")

@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="ok",
        model_loaded=model is not None,
        model_version=model_version
    )

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Ingen modell laddad")
    
    features = prepare_features(request.NetworkConnections, request.ProcessName)
    pred = int(model.predict(features)[0])
    conf = float(model.predict_proba(features).max())
    threat = get_threat_type(pred)
    
    # Logga metrics
    PREDICTION_COUNT.labels(threat_type=threat).inc()
    PREDICTION_CONFIDENCE.observe(conf)
    if model_version:
        MODEL_INFO.labels(version=model_version).inc()
    
    return PredictionResponse(
        prediction=pred,
        confidence=conf,
        threat_type=threat,
        model_version=model_version if model_version else "unknown"
    )

@app.get("/metrics")
async def get_metrics():
    # Uppdatera system metrics
    CPU_USAGE.set(time.process_time())
    MEMORY_USAGE.set(psutil.Process().memory_info().rss)
    
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

@app.get("/")
async def root():
    return {
        "message": "Endpoint Security ML API",
        "docs": "/docs",
        "health": "/health",
        "metrics": "/metrics",
        "predict": "/predict (POST)"
    }
'@

Set-Content -Path (Join-Path $apiDir "app.py") -Value $newAppPy -Encoding UTF8
Write-Host "  ✅ app.py uppdaterad med FIXADE metric-namn" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. SKAPA ENKLARE APP.PY FÖR CI (NYTT!)
# ------------------------------
Write-Host "4️⃣ Skapar enklare app_ci.py för GitHub Actions..." -ForegroundColor Yellow

$appCiPy = @'
"""
app_ci.py - Enklare API för CI-miljö (utan psutil)
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
import joblib
import os
import time
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
from .models import PredictionRequest, PredictionResponse, HealthResponse
from .utils import find_latest_model, prepare_features, get_threat_type

# Grundläggande metrics (inga psutil-beroende)
REQUEST_COUNT = Counter('http_requests_total', 'Totala antalet anrop', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Svarstider i sekunder', ['method', 'endpoint'])
PREDICTION_COUNT = Counter('predictions_total', 'Antal prediktioner', ['threat_type'])
MODEL_INFO = Counter('model_info', 'Information om modellen', ['version'])

app = FastAPI(title="Endpoint Security ML API (CI)")

model = None
model_version = None

@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    method = request.method
    endpoint = request.url.path
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=response.status_code).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)
    return response

@app.on_event("startup")
async def load_model():
    global model, model_version
    model_path = find_latest_model()
    if model_path:
        model = joblib.load(model_path)
        model_version = os.path.basename(model_path).replace("endpoint_model_", "").replace(".pkl", "")
        print(f"✅ Modell laddad: {model_path}")
        if model_version:
            MODEL_INFO.labels(version=model_version).inc()

@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(status="ok", model_loaded=model is not None, model_version=model_version)

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Ingen modell laddad")
    features = prepare_features(request.NetworkConnections, request.ProcessName)
    pred = int(model.predict(features)[0])
    conf = float(model.predict_proba(features).max())
    threat = get_threat_type(pred)
    PREDICTION_COUNT.labels(threat_type=threat).inc()
    if model_version:
        MODEL_INFO.labels(version=model_version).inc()
    return PredictionResponse(
        prediction=pred,
        confidence=conf,
        threat_type=threat,
        model_version=model_version if model_version else "unknown"
    )

@app.get("/metrics")
async def get_metrics():
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

@app.get("/")
async def root():
    return {"message": "Endpoint Security ML API (CI version)"}
'@

Set-Content -Path (Join-Path $apiDir "app_ci.py") -Value $appCiPy -Encoding UTF8
Write-Host "  ✅ app_ci.py skapad för CI-miljö" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. UPPDATERA REQUIREMENTS.TXT MED PSUTIL
# ------------------------------
Write-Host "5️⃣ Uppdaterar requirements.txt med psutil..." -ForegroundColor Yellow

$reqPath = Join-Path $ProjectRoot "requirements.txt"
Add-Content -Path $reqPath -Value "`npsutil==5.9.5" -Encoding UTF8
Write-Host "  ✅ psutil tillagt i requirements.txt" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. UPPDATERA DOCKERFILE.API (MED BÅDA PAKETEN)
# ------------------------------
Write-Host "6️⃣ Uppdaterar Dockerfile.api med prometheus-client och psutil..." -ForegroundColor Yellow

$dockerfilePath = Join-Path $ProjectRoot "Dockerfile.api"
$newDockerfile = @'
FROM python:3.9-slim
WORKDIR /app
RUN apt-get update && apt-get install -y gcc curl && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir numpy==1.23.5
RUN pip install --no-cache-dir pandas==2.0.3
RUN pip install --no-cache-dir scikit-learn==1.2.2 joblib==1.2.0
RUN pip install --no-cache-dir fastapi==0.104.1 uvicorn[standard]==0.24.0 pydantic==2.5.0
RUN pip install --no-cache-dir prometheus-client psutil
COPY . .
RUN mkdir -p /app/models/production /app/src/api
EXPOSE 8000
CMD ["uvicorn", "src.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
'@

Set-Content -Path $dockerfilePath -Value $newDockerfile -Encoding UTF8
Write-Host "  ✅ Dockerfile.api uppdaterad med prometheus-client och psutil" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. UPPDATERA DOCKER-COMPOSE.YML (SOM VANLIGT)
# ------------------------------
Write-Host "7️⃣ Uppdaterar docker-compose.yml..." -ForegroundColor Yellow

$composePath = Join-Path $ProjectRoot "docker-compose.yml"
$composeContent = Get-Content $composePath -Raw

if ($composeContent -notmatch "prometheus:") {
    $monitoringServices = @'

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
      - ./grafana:/etc/grafana/provisioning/dashboards
      - grafana_data:/var/lib/grafana
    depends_on:
      - prometheus

volumes:
  grafana_data:
'@

    $composeContent = $composeContent.TrimEnd() + "`r`n" + $monitoringServices.TrimStart()
    
    if ($composeContent -match "volumes:\s*\n\s*postgres_data:") {
        $composeContent = $composeContent -replace "(volumes:\s*\n\s*postgres_data:)", "`$1`r`n  grafana_data:"
    }
    
    Set-Content -Path $composePath -Value $composeContent -Encoding UTF8
    Write-Host "  ✅ docker-compose.yml uppdaterad" -ForegroundColor Green
} else {
    Write-Host "  ✅ docker-compose.yml redan uppdaterad" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 9. RENSA LOGG-PROBLEM (OFÖRÄNDRAT)
# ------------------------------
Write-Host "8️⃣ Rensar eventuella logg-problem..." -ForegroundColor Yellow
docker-compose down
if (Test-Path "airflow/logs") {
    try {
        Rename-Item -Path "airflow/logs" -NewName "airflow/logs_backup" -Force -ErrorAction Stop
        Write-Host "  ✅ Gammal logs-mapp bytt namn" -ForegroundColor Green
    } catch {
        Remove-Item -Path "airflow/logs" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
New-Item -ItemType Directory -Path "airflow/logs" -Force | Out-Null
Write-Host "  ✅ Ny logs-mapp skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 10. BYGG OM API (OFÖRÄNDRAT)
# ------------------------------
Write-Host "9️⃣ Bygger om API med nya paket (--no-cache)..." -ForegroundColor Yellow
docker-compose build --no-cache api
Write-Host "  ✅ API byggt" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 11. STARTA ALLA CONTAINERS (OFÖRÄNDRAT)
# ------------------------------
Write-Host "🔟 Startar alla containers..." -ForegroundColor Yellow
docker-compose up -d
Write-Host "  ✅ Containers startade" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 12. INSTALLERA PAKET LOKALT (OFÖRÄNDRAT)
# ------------------------------
Write-Host "1️⃣1️⃣ Installerar paket lokalt (för VS Code)..." -ForegroundColor Yellow
pip install prometheus-client psutil
Write-Host "  ✅ Paket installerade lokalt" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 13. SKAPA TEST-SKRIPT (OFÖRÄNDRAT)
# ------------------------------
Write-Host "1️⃣2️⃣ Skapar test-monitoring.ps1..." -ForegroundColor Yellow

$testScript = @'
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
'@

Set-Content -Path (Join-Path $ProjectRoot "test-monitoring.ps1") -Value $testScript -Encoding UTF8
Write-Host "  ✅ test-monitoring.ps1 skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 14. KLAR! (OFÖRÄNDRAT)
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ PROMETHEUS & GRAFANA SETUP KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 DINA NYA TJÄNSTER MED EXTRA METRICS:" -ForegroundColor Yellow
Write-Host "  • Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "  • Grafana:    http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host "  • Metrics:    http://localhost:8000/metrics" -ForegroundColor White
Write-Host ""
Write-Host "📋 NYA METRICS DU KAN ÖVERVAKA:" -ForegroundColor Green
Write-Host "  • Error rate (%) - Andel misslyckade anrop" -ForegroundColor White
Write-Host "  • CPU Usage (%) - Processorns belastning (app_cpu_seconds_total)" -ForegroundColor White
Write-Host "  • Memory Usage (MB) - Minnesanvändning (app_memory_bytes)" -ForegroundColor White
Write-Host "  • Prediction Confidence - Modellens säkerhet (95:e percentil)" -ForegroundColor White
Write-Host ""
Write-Host "📋 NÄSTA STEG:" -ForegroundColor Green
Write-Host "  1. Vänta 30 sekunder att allt startar" -ForegroundColor Yellow
Write-Host "  2. Öppna Grafana och logga in (admin/admin)" -ForegroundColor Yellow
Write-Host "  3. Importera nya dashboarden från grafana/dashboard.json" -ForegroundColor Yellow
Write-Host "  4. Gör några anrop till API:et och se alla metrics!" -ForegroundColor Yellow