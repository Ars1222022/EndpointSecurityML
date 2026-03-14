# =====================================================
# setup-docker.ps1 - KOMPLETT DOCKER-SETUP FÖR MLFLOW
# =====================================================
# Detta skript:
# 1. Rensar alla gamla containers
# 2. Skapar en ny Dockerfile
# 3. Bygger och startar MLflow i Docker
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🐳 DOCKER - KOMPLETT SETUP FÖR MLFLOW" -ForegroundColor Cyan
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
Write-Host "1️⃣ Rensar gamla Docker-containers..." -ForegroundColor Yellow

# Stoppa och ta bort specifik container om den finns
docker stop endpointsecurity-mlflow 2>$null
docker rm endpointsecurity-mlflow 2>$null

# Stoppa och ta bort alla containers relaterade till projektet
docker-compose down 2>$null

# Ta bort alla stoppade containers
docker container prune -f

Write-Host "  ✅ Gamla containers borttagna" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. SKAPA NY DOCKERFILE (MED ALLA BEROENDEN)
# ------------------------------
Write-Host "2️⃣ Skapar ny Dockerfile med alla beroenden..." -ForegroundColor Yellow

$dockerfile = @"
FROM python:3.11-slim

WORKDIR /app

# Installera systemberoenden
RUN apt-get update && apt-get install -y gcc curl && rm -rf /var/lib/apt/lists/*

# Kopiera requirements om den finns, annars skapa en
COPY requirements.txt . 2>/dev/null || echo "Ingen requirements.txt, skapar en..."

# Installera ALLA nödvändiga paket (inga versionkonflikter)
RUN pip install --no-cache-dir numpy pandas scikit-learn joblib pyodbc

# Installera MLflow och dess beroenden
RUN pip install --no-cache-dir mlflow

# Kopiera hela projektet
COPY . .

# Skapa nödvändiga mappar
RUN mkdir -p /app/mlruns /app/models/production /app/data/raw /app/data/processed /app/src/training

# Exponera port
EXPOSE 5000

# Starta MLflow
CMD ["mlflow", "ui", "--host", "0.0.0.0", "--port", "5000", "--backend-store-uri", "/app/mlruns"]
"@

Set-Content -Path "Dockerfile" -Value $dockerfile -Encoding UTF8
Write-Host "  ✅ Dockerfile skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. SKAPA ENKELT TRÄNINGSSKRIPT I CONTAINERN
# ------------------------------
Write-Host "3️⃣ Skapar träningsskript..." -ForegroundColor Yellow

$trainDir = Join-Path $ProjectRoot "src" "training"
New-Item -ItemType Directory -Path $trainDir -Force | Out-Null

$trainScript = @'
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import mlflow
import glob
import os

print("📊 MLflow version:", mlflow.__version__)
print("")

# Hitta data
print("🔍 Letar efter data...")
csv_files = glob.glob("data/raw/*.csv")
if not csv_files:
    print("❌ Ingen data hittad! Kör först dvc-kommandon.ps1 (val 1)")
    exit(1)

latest_data = max(csv_files, key=os.path.getctime)
print(f"  ✅ Använder: {latest_data}")
df = pd.read_csv(latest_data)
print(f"  📊 Laddade {len(df)} rader")
print("")

# Förbered features
print("🔧 Förbereder features...")
df['IsSuspicious'] = df['ProcessName'].isin(['powershell.exe', 'cmd.exe', 'wannacry.exe']).astype(int)
X = df[['NetworkConnections', 'IsSuspicious']]
y = df['IsAttack']

print(f"  ✅ Attack: {y.sum()}, Normal: {len(y)-y.sum()}")
print("")

# Dela data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# MLflow
mlflow.set_experiment("EndpointSecurity_Docker")

with mlflow.start_run() as run:
    print("🤖 Tränar modell...")
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    model.fit(X_train, y_train)
    
    print("📈 Utvärderar...")
    y_pred = model.predict(X_test)
    accuracy = float(accuracy_score(y_test, y_pred))
    
    # Logga
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("model_type", "RandomForest")
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("attack_count", int(y.sum()))
    mlflow.log_metric("normal_count", int(len(y)-y.sum()))
    
    # Feature importance
    for feature, importance in zip(['NetworkConnections', 'IsSuspicious'], model.feature_importances_):
        mlflow.log_metric(f"importance_{feature}", float(importance))
    
    print(f"\n  ✅ Accuracy: {accuracy:.3f}")
    print(f"  ✅ Feature importance - NetworkConnections: {model.feature_importances_[0]:.3f}")
    print(f"  ✅ Feature importance - IsSuspicious: {model.feature_importances_[1]:.3f}")
    print(f"\n📊 Run ID: {run.info.run_id}")
    print(f"📁 Experiment: EndpointSecurity_Docker")
    print(f"🔗 MLflow UI: http://localhost:5000")
'@

Set-Content -Path (Join-Path $trainDir "train.py") -Value $trainScript -Encoding UTF8
Write-Host "  ✅ train.py skapad i src/training/" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. BYGG DOCKER-IMAGE
# ------------------------------
Write-Host "4️⃣ Bygger Docker-image (detta tar några minuter)..." -ForegroundColor Yellow
docker build -t endpointsecurity-mlflow:latest .
Write-Host "  ✅ Docker-image byggd" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. STARTA CONTAINER
# ------------------------------
Write-Host "5️⃣ Startar container..." -ForegroundColor Yellow
docker run -d `
  --name endpointsecurity-mlflow `
  -p 5000:5000 `
  -v ${PWD}/mlruns:/app/mlruns `
  -v ${PWD}/models:/app/models `
  -v ${PWD}/data:/app/data `
  -v ${PWD}/src:/app/src `
  endpointsecurity-mlflow:latest

Write-Host "  ✅ Container startad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. VÄNTA OCH KONTROLLERA
# ------------------------------
Write-Host "6️⃣ Väntar på att MLflow ska starta..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

$containerStatus = docker ps --filter "name=endpointsecurity-mlflow" --format "table {{.Status}}"
if ($containerStatus -match "Up") {
    Write-Host "  ✅ MLflow kör på http://localhost:5000" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Något är fel. Kollar loggar..." -ForegroundColor Yellow
    docker logs endpointsecurity-mlflow
}
Write-Host ""

# ------------------------------
# 8. TRÄNA EN TESTMODELL
# ------------------------------
Write-Host "7️⃣ Tränar en testmodell i containern..." -ForegroundColor Yellow
docker exec endpointsecurity-mlflow python src/training/train.py
Write-Host ""

# ------------------------------
# 9. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ DOCKER MED MLFLOW ÄR KLART!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 MLflow UI: http://localhost:5000" -ForegroundColor Yellow
Write-Host ""
Write-Host "📋 Användbara kommandon:" -ForegroundColor White
Write-Host "  docker logs endpointsecurity-mlflow    # Se loggar" -ForegroundColor Gray
Write-Host "  docker stop endpointsecurity-mlflow    # Stoppa" -ForegroundColor Gray
Write-Host "  docker start endpointsecurity-mlflow   # Starta igen" -ForegroundColor Gray
Write-Host "  docker exec -it endpointsecurity-mlflow bash  # Öppna terminal" -ForegroundColor Gray
Write-Host "  docker exec endpointsecurity-mlflow python src/training/train.py  # Träna ny modell" -ForegroundColor Gray