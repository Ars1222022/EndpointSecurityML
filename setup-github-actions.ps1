# =====================================================
# setup-github-actions.ps1 - 100% FELSÄKER VERSION
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "GITHUB ACTIONS - KOMPLETT AUTOMATION" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. HITTA PROJEKTROTEN
# ------------------------------
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot
Write-Host "Projektmapp: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 2. FRÅGA OM DOCKER HUB-ANVÄNDARNAMN
# ------------------------------
Write-Host "Docker Hub behövs för att lagra dina Docker-images" -ForegroundColor Cyan
Write-Host ""
$dockerUsername = Read-Host "Ange ditt Docker Hub användarnamn"
if ([string]::IsNullOrWhiteSpace($dockerUsername)) {
    $dockerUsername = "ditt-anvandarnamn"
    Write-Host "Använder standard: $dockerUsername" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 3. UPPDATERA REQUIREMENTS.TXT
# ------------------------------
Write-Host "Steg 1: Uppdaterar requirements.txt..." -ForegroundColor Yellow

$testDeps = @"

# Testing
pytest==7.4.0
pytest-cov==4.1.0
httpx==0.25.0
requests==2.31.0
"@

$reqPath = Join-Path $ProjectRoot "requirements.txt"
if (Test-Path $reqPath) {
    Add-Content -Path $reqPath -Value $testDeps -Encoding UTF8
    Write-Host "  OK - requirements.txt uppdaterad" -ForegroundColor Green
} else {
    Set-Content -Path $reqPath -Value "# ML Dependencies`nnumpy==1.23.5`npandas==2.0.3`nscikit-learn==1.2.2`njoblib==1.2.0`nfastapi==0.104.1`nuvicorn[standard]==0.24.0`npydantic==2.5.0`nmlflow==2.8.0$testDeps" -Encoding UTF8
    Write-Host "  OK - requirements.txt skapad" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 4. INSTALLERA ALLA BIBLIOTEK LOKALT
# ------------------------------
Write-Host "Steg 2: Installerar bibliotek lokalt..." -ForegroundColor Yellow
pip install -r requirements.txt
Write-Host ""

# ------------------------------
# 5. SKAPA GITHUB WORKFLOWS-MAPP
# ------------------------------
Write-Host "Steg 3: Skapar GitHub Actions-mapp..." -ForegroundColor Yellow
$workflowDir = Join-Path $ProjectRoot ".github" "workflows"
New-Item -ItemType Directory -Path $workflowDir -Force | Out-Null
Write-Host "  OK - .github/workflows/ mapp skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. SKAPA CI.YML (ENKEL VERSION)
# ------------------------------
Write-Host "Steg 4: Skapar CI-workflow..." -ForegroundColor Yellow

$ciYml = @'
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
      - uses: actions/checkout@v3
      - uses: actions/setup-python@v4
        with:
          python-version: '3.11'
      - run: |
          pip install -r requirements.txt
          pytest tests/ -v
'@

Set-Content -Path (Join-Path $workflowDir "ci.yml") -Value $ciYml -Encoding UTF8
Write-Host "  OK - ci.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. SKAPA CD.YML (ENKEL VERSION)
# ------------------------------
Write-Host "Steg 5: Skapar CD-workflow..." -ForegroundColor Yellow

$cdYml = @'
name: CD - Deploy to Docker Hub

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKER_USERNAME }}
          password: ${{ secrets.DOCKER_PASSWORD }}
      - uses: docker/build-push-action@v4
        with:
          push: true
          tags: ${{ secrets.DOCKER_USERNAME }}/endpointsecurity-api:latest
'@

# Spara som textfil - PowerShell tolkar inte innehållet
$cdYml | Out-File -FilePath (Join-Path $workflowDir "cd.yml") -Encoding UTF8
Write-Host "  OK - cd.yml skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. SKAPA TESTER
# ------------------------------
Write-Host "Steg 6: Skapar enhetstester..." -ForegroundColor Yellow

$testsDir = Join-Path $ProjectRoot "tests"
New-Item -ItemType Directory -Path $testsDir -Force | Out-Null

$testApi = @'
import pytest
from fastapi.testclient import TestClient
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.api.app import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200

def test_predict_normal():
    response = client.post("/predict", json={"NetworkConnections": 0, "ProcessName": "notepad.exe"})
    assert response.status_code == 200
    assert response.json()["prediction"] == 0

def test_predict_attack():
    response = client.post("/predict", json={"NetworkConnections": 1, "ProcessName": "powershell.exe"})
    assert response.status_code == 200
    assert response.json()["prediction"] == 1
'@

Set-Content -Path (Join-Path $testsDir "test_api.py") -Value $testApi -Encoding UTF8
Write-Host "  OK - tester skapade" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 9. SKAPA ENV.EXAMPLE
# ------------------------------
Write-Host "Steg 7: Skapar .env.example..." -ForegroundColor Yellow

$envExample = @"
# Docker Hub credentials
DOCKER_USERNAME=$dockerUsername
DOCKER_PASSWORD=change-this
"@

Set-Content -Path (Join-Path $ProjectRoot ".env.example") -Value $envExample -Encoding UTF8
Write-Host "  OK - .env.example skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 10. SKAPA pytest.ini
# ------------------------------
Write-Host "Steg 8: Skapar pytest.ini..." -ForegroundColor Yellow

$pytestIni = @"
[pytest]
testpaths = tests
"@

Set-Content -Path (Join-Path $ProjectRoot "pytest.ini") -Value $pytestIni -Encoding UTF8
Write-Host "  OK - pytest.ini skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 11. UPPDATERA README.MD (UTAN SPECIALTECKEN)
# ------------------------------
Write-Host "Steg 9: Uppdaterar README.md..." -ForegroundColor Yellow

$readmePath = Join-Path $ProjectRoot "README.md"
$readmeContent = @"

CI/CD Automatisering
====================
Detta projekt anvander GitHub Actions.

Docker Image
------------
docker pull $dockerUsername/endpointsecurity-api:latest

Kor tester lokalt
-----------------
pytest tests/ -v
"@

Add-Content -Path $readmePath -Value $readmeContent -Encoding UTF8
Write-Host "  OK - README.md uppdaterad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 12. SKAPA KONTROLL-SKRIPT (UTAN SPECIALTECKEN)
# ------------------------------
Write-Host "Steg 10: Skapar test-skript..." -ForegroundColor Yellow

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
Write-Host "  OK - test-cicd.ps1 skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 13. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "KLAR! Allt ar installerat." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Docker Hub anvandarnamn: $dockerUsername" -ForegroundColor Yellow
Write-Host ""
Write-Host "Kor nu: .\test-cicd.ps1" -ForegroundColor Yellow