Write-Host "Testar CI/CD setup..."

if (Test-Path ".github/workflows/ci.yml") { Write-Host "OK - ci.yml finns" }
if (Test-Path ".github/workflows/cd.yml") { Write-Host "OK - cd.yml finns" }
if (Test-Path "tests/test_api.py") { Write-Host "OK - tester finns" }

Write-Host ""
Write-Host "Nasta steg:"
Write-Host "1. Pusha till GitHub"
Write-Host "2. Lagg till secrets: DOCKER_USERNAME och DOCKER_PASSWORD"
Write-Host "3. Ga till Actions fliken"
