# =====================================================
# setup-github-actions.ps1 - KOMPLETT CI/CD SETUP
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🤖 GITHUB ACTIONS - KOMPLETT SETUP" -ForegroundColor Cyan
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
# 2. FRÅGA OM DOCKER HUB-ANVÄNDARNAMN
# ------------------------------
Write-Host "🔑 Docker Hub behövs för att lagra dina Docker-images" -ForegroundColor Cyan
Write-Host "   (Om du inte har ett konto, skapa gratis på hub.docker.com)" -ForegroundColor Gray
Write-Host ""
$dockerUsername = Read-Host "📝 Ange ditt DOCKER HUB användarnamn"
if ([string]::IsNullOrWhiteSpace($dockerUsername)) {
    $dockerUsername = "ditt-docker-anvandarnamn"
    Write-Host "  ⚠️ Använder standard: $dockerUsername" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 3. SKAPA GITHUB WORKFLOWS-MAPP
# ------------------------------
Write-Host "1️⃣ Skapar GitHub Actions-mapp..." -ForegroundColor Yellow
$workflowDir = Join-Path $ProjectRoot ".github" "workflows"
New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
Write-Host "  ✅ .github/workflows/ mapp skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. SKAPA CI.YML
# ------------------------------
Write-Host "2️⃣ Skapar CI-workflow..." -ForegroundColor Yellow

$ciYml = @"
name: CI - Build and Test

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: actions/setup-python@v5
        with:
          python-version: '3.11'
          
      - name: Install dependencies
        run: pip install -r requirements.txt
          
      - name: Create directories
        run: |
          mkdir -p data/raw
          mkdir -p models/production
          
      - name: Create test model
        run: |
          python -c '
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
import joblib
import os
from datetime import datetime

X_train = np.array([[0,0], [1,1], [0,0], [1,1]])
y_train = np.array([0,1,0,1])
model = RandomForestClassifier(n_estimators=10)
model.fit(X_train, y_train)

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
model_path = f"models/production/endpoint_model_{timestamp}.pkl"
joblib.dump(model, model_path)
print(f"Modell sparad: {model_path}")
'
          
      - name: Start API and run tests
        run: |
          # Starta API i bakgrunden
          uvicorn src.api.app:app --host 0.0.0.0 --port 8000 &
          API_PID=$!
          
          # Vänta på att API startar
          sleep 5
          
          # Testa att API:et är igång
          curl -f http://localhost:8000/health || exit 1
          
          # Kör testerna
          pytest tests/ -v
          
          # Stäng API
          kill $API_PID
"@

Set-Content -Path (Join-Path $workflowDir "ci.yml") -Value $ciYml -Encoding UTF8
Write-Host "  ✅ ci.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. SKAPA CD.YML (med secrets - utan escaping)
# ------------------------------
Write-Host "3️⃣ Skapar CD-workflow..." -ForegroundColor Yellow

# Skapa cd.yml som textfil utan att PowerShell tolkar den
$cdYml = @'
name: CD - Deploy to Docker Hub

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: docker/login-action@v3
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
          
      - uses: docker/build-push-action@v5
        with:
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/endpointsecurity-api:latest
          file: Dockerfile.api
'@

# Spara direkt som UTF-8 utan PowerShell-tolkning
[System.IO.File]::WriteAllLines((Join-Path $workflowDir "cd.yml"), $cdYml)
Write-Host "  ✅ cd.yml skapad (använder secrets)" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. SKAPA .ENV.EXAMPLE
# ------------------------------
Write-Host "4️⃣ Skapar .env.example..." -ForegroundColor Yellow

$envExample = @"
# Docker Hub credentials (för GitHub Actions)
DOCKER_USERNAME=$dockerUsername
DOCKER_PASSWORD=din-docker-token-här
"@

Set-Content -Path (Join-Path $ProjectRoot ".env.example") -Value $envExample -Encoding UTF8
Write-Host "  ✅ .env.example skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. SKAPA TESTER-MAPP
# ------------------------------
Write-Host "5️⃣ Skapar tester..." -ForegroundColor Yellow

$testsDir = Join-Path $ProjectRoot "tests"
New-Item -ItemType Directory -Path $testsDir -Force | Out-Null

$testApi = @'
"""
tests/test_api.py - Enhetstester för API:et
"""

import pytest
import requests

API_URL = "http://localhost:8000"

def test_health():
    response = requests.get(f"{API_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"

def test_predict_normal():
    response = requests.post(
        f"{API_URL}/predict",
        json={"NetworkConnections": 0, "ProcessName": "notepad.exe"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] == 0
    assert data["threat_type"] == "Normal"

def test_predict_attack():
    response = requests.post(
        f"{API_URL}/predict",
        json={"NetworkConnections": 1, "ProcessName": "powershell.exe"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] == 1
    assert data["threat_type"] == "Attack"
'@

Set-Content -Path (Join-Path $testsDir "test_api.py") -Value $testApi -Encoding UTF8
Write-Host "  ✅ test_api.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. SKAPA PYTEST.INI
# ------------------------------
Write-Host "6️⃣ Skapar pytest.ini..." -ForegroundColor Yellow

$pytestIni = @"
[pytest]
testpaths = tests
"@

Set-Content -Path (Join-Path $ProjectRoot "pytest.ini") -Value $pytestIni -Encoding UTF8
Write-Host "  ✅ pytest.ini skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 9. SKAPA TEST-CICD.PS1
# ------------------------------
Write-Host "7️⃣ Skapar test-cicd.ps1..." -ForegroundColor Yellow

$testScript = @'
Write-Host "Testar CI/CD setup..."

if (Test-Path ".github/workflows/ci.yml") { Write-Host "OK - ci.yml finns" }
if (Test-Path ".github/workflows/cd.yml") { Write-Host "OK - cd.yml finns" }
if (Test-Path "tests/test_api.py") { Write-Host "OK - tester finns" }

Write-Host ""
Write-Host "Nasta steg:"
Write-Host "1. Pusha till GitHub"
Write-Host "2. Lagg till secrets: DOCKER_USERNAME och DOCKER_PASSWORD"
Write-Host "3. Ga till Actions fliken"
'@

Set-Content -Path (Join-Path $ProjectRoot "test-cicd.ps1") -Value $testScript -Encoding UTF8
Write-Host "  ✅ test-cicd.ps1 skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 10. UPPDATERA REQUIREMENTS.TXT
# ------------------------------
Write-Host "8️⃣ Uppdaterar requirements.txt..." -ForegroundColor Yellow

$reqPath = Join-Path $ProjectRoot "requirements.txt"
$testDeps = @"

# Testing
pytest==7.4.0
pytest-cov==4.1.0
httpx==0.25.0
requests==2.31.0
"@

if (Test-Path $reqPath) {
    Add-Content -Path $reqPath -Value $testDeps -Encoding UTF8
} else {
    Set-Content -Path $reqPath -Value "# ML Dependencies`nnumpy==1.23.5`npandas==2.0.3`nscikit-learn==1.2.2`njoblib==1.2.0`nfastapi==0.104.1`nuvicorn[standard]==0.24.0`npydantic==2.5.0`nmlflow==2.8.0$testDeps" -Encoding UTF8
}
Write-Host "  ✅ requirements.txt uppdaterad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 11. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ GITHUB ACTIONS SETUP KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 DINA UPPGIFTER:" -ForegroundColor Yellow
Write-Host "  Docker Hub användarnamn: $dockerUsername (för .env.example)" -ForegroundColor White
Write-Host "  I GitHub secrets ska du använda:" -ForegroundColor White
Write-Host "    DOCKER_USERNAME = ditt Docker Hub användarnamn" -ForegroundColor Gray
Write-Host "    DOCKER_PASSWORD = din Docker Hub token" -ForegroundColor Gray
Write-Host ""
Write-Host "📋 NÄSTA STEG:" -ForegroundColor Green
Write-Host "  1. Kör .\test-cicd.ps1 för att verifiera" -ForegroundColor Yellow
Write-Host "  2. Pusha till GitHub" -ForegroundColor Yellow
Write-Host "  3. Lägg till secrets på GitHub" -ForegroundColor Yellow
Write-Host "  4. Kolla Actions-fliken" -ForegroundColor Yellow