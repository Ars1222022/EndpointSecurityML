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
Write-Host "   (Endast för .env.example - dina riktiga uppgifter lagras som secrets)" -ForegroundColor Gray
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
          
      - name: Start API
        run: |
          uvicorn src.api.app:app --host 0.0.0.0 --port 8000 &
          sleep 5
          
      - name: Test health endpoint
        run: curl -f http://localhost:8000/health || exit 1
          
      - name: Run tests
        run: pytest tests/ -v
"@

Set-Content -Path (Join-Path $workflowDir "ci.yml") -Value $ciYml -Encoding UTF8
Write-Host "  ✅ ci.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. SKAPA CD.YML (utan escaping-problem)
# ------------------------------
Write-Host "3️⃣ Skapar CD-workflow..." -ForegroundColor Yellow

# Skapa cd.yml med enkel text för att undvika escaping
$cdYmlContent = @'
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

# Spara direkt utan PowerShell-tolkning
$cdYmlContent | Out-File -FilePath (Join-Path $workflowDir "cd.yml") -Encoding UTF8 -NoNewline
Write-Host "  ✅ cd.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. SKAPA TESTER
# ------------------------------
Write-Host "4️⃣ Skapar tester..." -ForegroundColor Yellow

$testsDir = Join-Path $ProjectRoot "tests"
New-Item -ItemType Directory -Path $testsDir -Force | Out-Null

# test_api.py
$testApi = @'
"""
tests/test_api.py - Enhetstester för API:et
"""

import pytest
import requests

API_URL = "http://localhost:8000"

def test_health():
    """Testar att health endpoint fungerar"""
    response = requests.get(f"{API_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"

def test_predict_normal():
    """Testar prediktion med normal process"""
    response = requests.post(
        f"{API_URL}/predict",
        json={"NetworkConnections": 0, "ProcessName": "notepad.exe"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] == 0
    assert data["threat_type"] == "Normal"

def test_predict_attack():
    """Testar prediktion med misstänkt process"""
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
# 7. SKAPA PYTEST.INI
# ------------------------------
Write-Host "5️⃣ Skapar pytest.ini..." -ForegroundColor Yellow

$pytestIni = @"
[pytest]
testpaths = tests
"@

Set-Content -Path (Join-Path $ProjectRoot "pytest.ini") -Value $pytestIni -Encoding UTF8
Write-Host "  ✅ pytest.ini skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. SKAPA .ENV.EXAMPLE
# ------------------------------
Write-Host "6️⃣ Skapar .env.example..." -ForegroundColor Yellow

$envExample = @"
# Docker Hub credentials (för GitHub Secrets - används i cd.yml)
DOCKER_USERNAME=$dockerUsername
DOCKER_PASSWORD=din-docker-token-här

# MLflow
MLFLOW_TRACKING_URI=http://mlflow:5000
"@

Set-Content -Path (Join-Path $ProjectRoot ".env.example") -Value $envExample -Encoding UTF8
Write-Host "  ✅ .env.example skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 9. SKAPA TEST-CICD.PS1
# ------------------------------
Write-Host "7️⃣ Skapar test-cicd.ps1..." -ForegroundColor Yellow

$testScript = @'
# =====================================================
# test-cicd.ps1 - Testar att CI/CD-setup fungerar
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🔍 TESTAR CI/CD SETUP" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Test 1: Kolla att workflow-filer finns
Write-Host "1️⃣ Kontrollerar workflow-filer..." -ForegroundColor Yellow
if (Test-Path ".github/workflows/ci.yml") {
    Write-Host "  ✅ ci.yml finns" -ForegroundColor Green
} else {
    Write-Host "  ❌ ci.yml saknas!" -ForegroundColor Red
}

if (Test-Path ".github/workflows/cd.yml") {
    Write-Host "  ✅ cd.yml finns" -ForegroundColor Green
} else {
    Write-Host "  ❌ cd.yml saknas!" -ForegroundColor Red
}
Write-Host ""

# Test 2: Kolla att tester finns
Write-Host "2️⃣ Kontrollerar tester..." -ForegroundColor Yellow
if (Test-Path "tests/test_api.py") {
    Write-Host "  ✅ test_api.py finns" -ForegroundColor Green
} else {
    Write-Host "  ❌ test_api.py saknas!" -ForegroundColor Red
}
Write-Host ""

# Test 3: Kolla pytest.ini
Write-Host "3️⃣ Kontrollerar pytest.ini..." -ForegroundColor Yellow
if (Test-Path "pytest.ini") {
    Write-Host "  ✅ pytest.ini finns" -ForegroundColor Green
} else {
    Write-Host "  ❌ pytest.ini saknas!" -ForegroundColor Red
}
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ TEST KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 NÄSTA STEG:" -ForegroundColor Yellow
Write-Host "  1. Pusha till GitHub:" -ForegroundColor White
Write-Host "     git add ." -ForegroundColor Gray
Write-Host "     git commit -m 'Lägg till CI/CD'" -ForegroundColor Gray
Write-Host "     git push origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "  2. Gå till GitHub och lägg till secrets:" -ForegroundColor White
Write-Host "     DOCKER_USERNAME = ditt Docker Hub användarnamn" -ForegroundColor Gray
Write-Host "     DOCKER_PASSWORD = din Docker Hub token" -ForegroundColor Gray
Write-Host ""
Write-Host "  3. Gå till Actions-fliken och se dina workflows köra!" -ForegroundColor White
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
requests==2.31.0
"@

if (Test-Path $reqPath) {
    Add-Content -Path $reqPath -Value $testDeps -Encoding UTF8
    Write-Host "  ✅ requirements.txt uppdaterad med testberoenden" -ForegroundColor Green
} else {
    Set-Content -Path $reqPath -Value "# ML Dependencies`nnumpy==1.23.5`npandas==2.0.3`nscikit-learn==1.2.2`njoblib==1.2.0`nfastapi==0.104.1`nuvicorn[standard]==0.24.0`npydantic==2.5.0`nmlflow==2.8.0$testDeps" -Encoding UTF8
    Write-Host "  ✅ requirements.txt skapad" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 11. INSTALLERA BIBLIOTEK LOKALT
# ------------------------------
Write-Host "9️⃣ Installerar bibliotek lokalt (rekommenderas)..." -ForegroundColor Yellow
pip install -r requirements.txt
Write-Host ""

# ------------------------------
# 12. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ GITHUB ACTIONS SETUP KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 FILER SOM SKAPATS:" -ForegroundColor Yellow
Write-Host "  • .github/workflows/ci.yml     - CI-workflow (testar koden)" -ForegroundColor White
Write-Host "  • .github/workflows/cd.yml     - CD-workflow (publicerar till Docker Hub)" -ForegroundColor White
Write-Host "  • tests/test_api.py            - Enhetstester för API:et" -ForegroundColor White
Write-Host "  • pytest.ini                   - Pytest konfiguration" -ForegroundColor White
Write-Host "  • .env.example                 - Mall för miljövariabler" -ForegroundColor White
Write-Host "  • test-cicd.ps1                 - Testskript för CI/CD" -ForegroundColor White
Write-Host "  • requirements.txt              - Uppdaterad med testberoenden" -ForegroundColor White
Write-Host ""
Write-Host "📋 DINA UPPGIFTER:" -ForegroundColor Yellow
Write-Host "  Docker Hub användarnamn: $dockerUsername (för .env.example)" -ForegroundColor White
Write-Host ""
Write-Host "📋 NÄSTA STEG:" -ForegroundColor Green
Write-Host "  1. Kör .\test-cicd.ps1 för att verifiera att allt skapats korrekt" -ForegroundColor Yellow
Write-Host "  2. Pusha till GitHub:" -ForegroundColor Yellow
Write-Host "     git add ." -ForegroundColor White
Write-Host "     git commit -m 'Lägg till CI/CD pipelines'" -ForegroundColor White
Write-Host "     git push origin main" -ForegroundColor White
Write-Host ""
Write-Host "  3. Gå till GitHub → Settings → Secrets and variables → Actions" -ForegroundColor Yellow
Write-Host "     Lägg till dessa secrets:" -ForegroundColor White
Write-Host "     • DOCKER_USERNAME = ditt Docker Hub användarnamn" -ForegroundColor Gray
Write-Host "     • DOCKER_PASSWORD = din Docker Hub token" -ForegroundColor Gray
Write-Host ""
Write-Host "  4. Gå till Actions-fliken och se dina workflows köra!" -ForegroundColor Yellow