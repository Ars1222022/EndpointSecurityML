# =====================================================
# test-k8s.ps1 - Testa Kubernetes-deployment
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "⚡ TESTAR KUBERNETES API" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📊 Kubernetes poddar:" -ForegroundColor Yellow
kubectl get pods
Write-Host ""

Write-Host "🌐 Ditt vanliga API fungerar på: http://localhost:8000" -ForegroundColor Green
Write-Host ""

Write-Host "1️⃣ Testar vanliga API:et via localhost..." -ForegroundColor Yellow
$url = "http://localhost:8000"

try {
    $response = Invoke-RestMethod -Uri "$url/health" -TimeoutSec 5
    Write-Host "  ✅ Health OK" -ForegroundColor Green
    Write-Host "  Modell laddad: $($response.model_loaded)" -ForegroundColor Gray
} catch {
    Write-Host "  ❌ Health failed: $_" -ForegroundColor Red
}
Write-Host ""

Write-Host "2️⃣ Testar Kubernetes-versionen (via port-forward)..." -ForegroundColor Yellow
Write-Host "   Kör i ett nytt fönster: kubectl port-forward service/api-service 8080:80" -ForegroundColor Gray
Write-Host "   Öppna sedan: http://localhost:8080/health" -ForegroundColor Gray
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ TEST KLART!" -ForegroundColor Green
