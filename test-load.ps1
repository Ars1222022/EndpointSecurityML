# =====================================================
# test-load.ps1 - Skapar belastning på API:et
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "⚡ SKAPAR BELASTNING PÅ API:ET" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$apiUrl = "http://localhost:8000/predict"
$processes = @("notepad.exe", "powershell.exe", "chrome.exe", "cmd.exe", "wannacry.exe", "explorer.exe", "mimikatz.exe")
$totalRequests = 0

Write-Host "📊 Skickar 100 anrop till API:et..." -ForegroundColor Yellow
Write-Host "   (Öppna Grafana och se graferna ändras!)" -ForegroundColor Gray
Write-Host ""

for ($i = 1; $i -le 100; $i++) {
    # Välj slumpmässig process
    $process = $processes | Get-Random
    $connections = Get-Random -Minimum 0 -Maximum 2
    
    $body = @{
        NetworkConnections = $connections
        ProcessName = $process
    } | ConvertTo-Json
    
    try {
        $response = Invoke-RestMethod -Uri $apiUrl -Method Post -Body $body -ContentType "application/json"
        $totalRequests++
        
        # Skriv ut progress var 10:e anrop
        if ($i % 10 -eq 0) {
            Write-Host "  ✅ $i anrop skickade..." -ForegroundColor Green
        }
    }
    catch {
        Write-Host "  ❌ Fel vid anrop $i" -ForegroundColor Red
    }
    
    # Vänta lite mellan anropen
    Start-Sleep -Milliseconds 100
}

Write-Host ""
Write-Host "✅ KLART! $totalRequests anrop skickade" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Gå till Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor Yellow
Write-Host "   Importera dashboard från grafana/dashboard.json" -ForegroundColor Yellow
Write-Host "   Se hur graferna ändras i realtid!" -ForegroundColor Yellow