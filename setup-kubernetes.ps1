# =====================================================
# fix-k8s-deployment.ps1 - Fixar Kubernetes-deployment
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🔧 FIXAR KUBERNETES DEPLOYMENT" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. ANVÄND KORREKT SÖKVÄG (citerad)
# ------------------------------
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot
Write-Host "📁 Projektmapp: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 2. TA BORT GAMLA DEPLOYMENTS (om de finns)
# ------------------------------
Write-Host "1️⃣ Rensar gamla deployment..." -ForegroundColor Yellow
& kubectl delete deployment api-deployment 2>$null
& kubectl delete service api-service 2>$null
Write-Host "  ✅ Gamla deployment borttagna" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. APPLICERA NYA KONFIGURATIONER (med citerad sökväg)
# ------------------------------
Write-Host "2️⃣ Distribuerar till Kubernetes..." -ForegroundColor Yellow

# Använd citerad sökväg för att hantera mellanslag
$k8sPath = "`"$ProjectRoot\k8s`""
Write-Host "  📁 Sökväg: $k8sPath" -ForegroundColor Gray

# Applicera direkt med full sökväg
& kubectl apply -f "$ProjectRoot\k8s\api-deployment.yaml"
& kubectl apply -f "$ProjectRoot\k8s\api-service.yaml"

Write-Host "  ✅ Deployment skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 4. VÄNTA PÅ PODDAR
# ------------------------------
Write-Host "3️⃣ Väntar på att poddar ska starta..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

for ($i = 1; $i -le 6; $i++) {
    $pods = & kubectl get pods --no-headers 2>$null
    if ($pods) {
        Write-Host "  📊 Status efter $($i*5) sekunder:" -ForegroundColor Cyan
        & kubectl get pods
        break
    } else {
        Write-Host "  ⏳ Inga poddar än... väntar 5 sekunder till" -ForegroundColor Yellow
        Start-Sleep -Seconds 5
    }
}

Write-Host ""

# ------------------------------
# 5. VISA STATUS
# ------------------------------
Write-Host "4️⃣ Slutgiltig status:" -ForegroundColor Yellow
& kubectl get pods
& kubectl get services
Write-Host ""

# ------------------------------
# 6. TESTA MED PORT-FORWARD
# ------------------------------
Write-Host "5️⃣ Testa Kubernetes API via port-forward:" -ForegroundColor Yellow
Write-Host "   Öppna ett NYTT PowerShell-fönster och kör:" -ForegroundColor Cyan
Write-Host "   kubectl port-forward service/api-service 8080:80" -ForegroundColor White
Write-Host ""
Write-Host "   Öppna sedan i webbläsaren: http://localhost:8080/health" -ForegroundColor White
Write-Host ""

# ------------------------------
# 7. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ FIX KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 KOMMANDON:" -ForegroundColor Yellow
Write-Host "  kubectl get pods              # Se alla poddar" -ForegroundColor White
Write-Host "  kubectl logs -f pod/[namn]    # Se loggar" -ForegroundColor White
Write-Host "  kubectl delete pod/[namn]     # Starta om en pod" -ForegroundColor Gray