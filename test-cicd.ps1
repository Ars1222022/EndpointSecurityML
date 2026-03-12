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
