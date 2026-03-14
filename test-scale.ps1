# =====================================================
# test-scale.ps1 - Testa lastbalansering
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "⚡ TESTAR LASTBALANSERING" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# Hämta URL
$url = minikube service api-service --url
Write-Host "🌐 API URL: $url" -ForegroundColor Green
Write-Host ""

# Testa health
Write-Host "1️⃣ Testar health endpoint..." -ForegroundColor Yellow
try {
    $response = Invoke-RestMethod -Uri "$url/health" -TimeoutSec 5
    Write-Host "  ✅ OK" -ForegroundColor Green
} catch {
    Write-Host "  ❌ FEL" -ForegroundColor Red
}
Write-Host ""

# Skicka 10 testanrop
Write-Host "2️⃣ Skickar 10 testanrop..." -ForegroundColor Yellow
$processes = @("notepad.exe", "powershell.exe", "chrome.exe")

for ($i = 1; $i -le 10; $i++) {
    $process = $processes | Get-Random
    $body = @{NetworkConnections=1; ProcessName=$process} | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri "$url/predict" -Method Post -Body $body -ContentType "application/json"
        Write-Host "  ✅ Anrop $i: $($response.threat_type)" -ForegroundColor Green
    } catch {
        Write-Host "  ❌ Anrop $i: FEL" -ForegroundColor Red
    }
    Start-Sleep -Milliseconds 200
}
Write-Host ""

Write-Host "✅ TEST KLART!" -ForegroundColor Green
Write-Host "Kolla status: kubectl get pods" -ForegroundColor Yellow
