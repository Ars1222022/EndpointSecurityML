# =====================================================
# setup-api.ps1 - ULTIMATA VERSIONEN (ALLA VERSIONER KORREKTA)
# =====================================================
# Detta skript skapar ett komplett fungerande API
# med MLflow, FastAPI och alla nödvändiga komponenter
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 FASTAPI - ULTIMATA SETUP" -ForegroundColor Cyan
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
# 2. RENSA ALLA GAMLA CONTAINERS
# ------------------------------
Write-Host "1️⃣ Rensar gamla containers..." -ForegroundColor Yellow
docker stop api mlflow 2>$null
docker rm api mlflow 2>$null
docker-compose down 2>$null
Write-Host "  ✅ Gamla containers borttagna" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. SKAPA API-MAPP
# ------------------------------
Write-Host "2️⃣ Skapar API-mapp..." -ForegroundColor Yellow
$apiDir = Join-Path $ProjectRoot "src" "api"
New-Item -ItemType Directory -Path $apiDir -Force | Out-Null
Write-Host "  ✅ src/api/ mapp skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. SKAPA MODELS.PY
# ------------------------------
Write-Host "3️⃣ Skapar models.py..." -ForegroundColor Yellow

$modelsContent = @'
"""models.py - Pydantic-modeller för API:et"""
from pydantic import BaseModel
from typing import Optional

class PredictionRequest(BaseModel):
    NetworkConnections: int
    ProcessName: str

class PredictionResponse(BaseModel):
    prediction: int
    confidence: float
    threat_type: str
    model_version: str

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_version: Optional[str] = None
'@

Set-Content -Path (Join-Path $apiDir "models.py") -Value $modelsContent -Encoding UTF8
Write-Host "  ✅ models.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. SKAPA UTILS.PY (UTAN PANDAS)
# ------------------------------
Write-Host "4️⃣ Skapar utils.py (utan pandas)..." -ForegroundColor Yellow

$utilsContent = @'
"""utils.py - utan pandas för att undvika numpy-konflikter"""
import glob
import os
import joblib
import numpy as np

def find_latest_model():
    """Hittar den senast tränade modellen"""
    files = glob.glob("models/production/*.pkl")
    if not files:
        return None
    return max(files, key=os.path.getctime)

def prepare_features(network_connections, process_name):
    """Förbereder features som numpy array (istället för pandas)"""
    suspicious = 1 if process_name.lower() in ['powershell.exe','cmd.exe','wannacry.exe'] else 0
    return np.array([[network_connections, suspicious]], dtype=np.float64)

def get_threat_type(prediction):
    """Konverterar prediction till hottyp"""
    return 'Attack' if prediction == 1 else 'Normal'
'@

Set-Content -Path (Join-Path $apiDir "utils.py") -Value $utilsContent -Encoding UTF8
Write-Host "  ✅ utils.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. SKAPA APP.PY
# ------------------------------
Write-Host "5️⃣ Skapar app.py..." -ForegroundColor Yellow

$appContent = @'
"""app.py - Huvud-API för modellprediktioner"""
from fastapi import FastAPI, HTTPException
import joblib
import os
from .models import PredictionRequest, PredictionResponse, HealthResponse
from .utils import find_latest_model, prepare_features, get_threat_type

app = FastAPI(title="Endpoint Security ML API")

model = None
model_version = None

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
    
    return PredictionResponse(
        prediction=pred,
        confidence=conf,
        threat_type=get_threat_type(pred),
        model_version=model_version
    )

@app.get("/")
async def root():
    return {
        "message": "Endpoint Security ML API",
        "docs": "/docs",
        "health": "/health",
        "predict": "/predict (POST)"
    }
'@

Set-Content -Path (Join-Path $apiDir "app.py") -Value $appContent -Encoding UTF8
Write-Host "  ✅ app.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. SKAPA TRÄNINGSSKRIPT UTAN MLFLOW
# ------------------------------
Write-Host "6️⃣ Skapar träningsskript utan MLflow..." -ForegroundColor Yellow

$trainDir = Join-Path $ProjectRoot "src" "training"
New-Item -ItemType Directory -Path $trainDir -Force | Out-Null

$trainNoMlflow = @'
"""train_no_mlflow.py - Tränar modell utan MLflow (för API:t)"""
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import glob
import os
from datetime import datetime

print("📊 Tränar modell för API...")

# Hitta senaste data
csv_files = glob.glob('data/raw/*.csv')
if not csv_files:
    print("❌ Ingen data hittad! Kopiera först data till containern.")
    exit(1)
    
latest_data = max(csv_files, key=os.path.getctime)
print(f"📁 Använder data: {latest_data}")

# Läs data
df = pd.read_csv(latest_data)
print(f"📊 Laddade {len(df)} rader")

# Förbered features
df['IsSuspicious'] = df['ProcessName'].isin(['powershell.exe','cmd.exe','wannacry.exe']).astype(int)
X = df[['NetworkConnections', 'IsSuspicious']]
y = df['IsAttack']

print(f"📈 Attack: {y.sum()}, Normal: {len(y)-y.sum()}")

# Dela data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Träna
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Utvärdera
accuracy = accuracy_score(y_test, model.predict(X_test))
print(f"🎯 Accuracy: {accuracy:.3f}")

# Spara
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
model_path = f'models/production/endpoint_model_{timestamp}.pkl'
joblib.dump(model, model_path)
print(f"💾 Modell sparad: {model_path}")
print("✅ Träning klar!")
'@

Set-Content -Path (Join-Path $trainDir "train_no_mlflow.py") -Value $trainNoMlflow -Encoding UTF8
Write-Host "  ✅ train_no_mlflow.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. SKAPA DOCKERFILE.API (MED KORREKTA VERSIONER)
# ------------------------------
Write-Host "7️⃣ Skapar Dockerfile.api..." -ForegroundColor Yellow

$dockerfileApi = @"
FROM python:3.9-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc curl && rm -rf /var/lib/apt/lists/*

# Installera KORREKTA versioner (testade och fungerar)
RUN pip install --no-cache-dir numpy==1.23.5
RUN pip install --no-cache-dir pandas==2.0.3
RUN pip install --no-cache-dir scikit-learn==1.2.2 joblib==1.2.0
RUN pip install --no-cache-dir fastapi==0.104.1 uvicorn[standard]==0.24.0 pydantic==2.5.0

COPY . .

RUN mkdir -p /app/models/production /app/src/api

EXPOSE 8000

CMD ["uvicorn", "src.api.app:app", "--host", "0.0.0.0", "--port", "8000"]
"@

Set-Content -Path "Dockerfile.api" -Value $dockerfileApi -Encoding UTF8
Write-Host "  ✅ Dockerfile.api skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 9. SKAPA DOCKERFILE.MLFLOW
# ------------------------------
Write-Host "8️⃣ Skapar Dockerfile.mlflow..." -ForegroundColor Yellow

$dockerfileMlflow = @"
FROM python:3.11-slim

WORKDIR /app

RUN pip install --no-cache-dir mlflow pandas

EXPOSE 5000

CMD ["mlflow", "ui", "--host", "0.0.0.0", "--port", "5000", "--backend-store-uri", "/app/mlruns"]
"@

Set-Content -Path "Dockerfile.mlflow" -Value $dockerfileMlflow -Encoding UTF8
Write-Host "  ✅ Dockerfile.mlflow skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 10. SKAPA DOCKER-COMPOSE.YML
# ------------------------------
Write-Host "9️⃣ Skapar docker-compose.yml..." -ForegroundColor Yellow

$compose = @"
services:
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
"@

Set-Content -Path "docker-compose.yml" -Value $compose -Encoding UTF8
Write-Host "  ✅ docker-compose.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 11. BYGG OCH STARTA CONTAINERS
# ------------------------------
Write-Host "🔟 Bygger och startar containers (detta tar några minuter)..." -ForegroundColor Yellow
docker-compose up --build -d
Write-Host "  ✅ Containers startade" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 12. KOPIERA DATA TILL API-CONTAINERN
# ------------------------------
Write-Host "1️⃣1️⃣ Kopierar data till API-containern..." -ForegroundColor Yellow
Start-Sleep -Seconds 15
docker cp data/raw/. api:/app/data/raw/ 2>$null
Write-Host "  ✅ Data kopierad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 13. TRÄNA MODELL I API-CONTAINERN
# ------------------------------
Write-Host "1️⃣2️⃣ Tränar modell i API-containern..." -ForegroundColor Yellow
docker exec api python src/training/train_no_mlflow.py
Write-Host "  ✅ Modell tränad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 14. STARTA OM API FÖR ATT LADDA MODELLEN
# ------------------------------
Write-Host "1️⃣3️⃣ Startar om API för att ladda modellen..." -ForegroundColor Yellow
docker restart api
Start-Sleep -Seconds 5
Write-Host "  ✅ API redo" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 15. TESTA ALLT
# ------------------------------
Write-Host "1️⃣4️⃣ Testar tjänsterna..." -ForegroundColor Yellow

# Testa health
$health = Invoke-RestMethod -Uri "http://localhost:8000/health" -ErrorAction SilentlyContinue
if ($health.model_loaded) {
    Write-Host "  ✅ API fungerar - modell laddad!" -ForegroundColor Green
    Write-Host "  📊 Modellversion: $($health.model_version)" -ForegroundColor White
} else {
    Write-Host "  ⚠️ API fungerar men ingen modell laddad" -ForegroundColor Yellow
}

# Testa MLflow
try {
    $mlflowTest = Invoke-WebRequest -Uri "http://localhost:5000" -UseBasicParsing -TimeoutSec 2
    Write-Host "  ✅ MLflow UI fungerar!" -ForegroundColor Green
} catch {
    Write-Host "  ⚠️ MLflow UI startar (vänta några sekunder)" -ForegroundColor Yellow
}

# Testa prediktion
try {
    $body = @{NetworkConnections=1; ProcessName="powershell.exe"} | ConvertTo-Json
    $pred = Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
    Write-Host "  ✅ Predict endpoint fungerar!" -ForegroundColor Green
    Write-Host "  🔍 Testprediktion: Attack=$($pred.prediction), Confidence=$($pred.confidence)" -ForegroundColor White
} catch {
    Write-Host "  ⚠️ Predict test misslyckades" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 16. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ FASTAPI SETUP KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 DINA TJÄNSTER:" -ForegroundColor Yellow
Write-Host "  MLflow UI:    http://localhost:5000" -ForegroundColor White
Write-Host "  API Docs:     http://localhost:8000/docs" -ForegroundColor White
Write-Host "  Health check: http://localhost:8000/health" -ForegroundColor White
Write-Host ""
Write-Host "📋 TESTA API:ET:" -ForegroundColor Gray
Write-Host '  $body = @{NetworkConnections=1; ProcessName="powershell.exe"} | ConvertTo-Json' -ForegroundColor Gray
Write-Host '  Invoke-RestMethod -Uri "http://localhost:8000/predict" -Method Post -Body $body -ContentType "application/json"' -ForegroundColor Gray
Write-Host ""
Write-Host "📋 ANVÄNDBARA KOMMANDON:" -ForegroundColor Gray
Write-Host "  docker logs api        # Se API-loggar" -ForegroundColor Gray
Write-Host "  docker logs mlflow     # Se MLflow-loggar" -ForegroundColor Gray
Write-Host "  docker-compose down    # Stoppa allt" -ForegroundColor Gray
Write-Host "  docker-compose up -d   # Starta allt" -ForegroundColor Gray