# =====================================================
# deploy-to-k8s.ps1 - Distribuera API:et till Kubernetes
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 DISTRIBUERAR TILL KUBERNETES" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "1️⃣ Kontrollerar Minikube..." -ForegroundColor Yellow
minikube status
Write-Host ""

Write-Host "2️⃣ Distribuerar till Kubernetes..." -ForegroundColor Yellow
kubectl apply -f k8s/
Write-Host ""

Write-Host "3️⃣ Väntar på att poddarna startar..." -ForegroundColor Yellow
Start-Sleep -Seconds 10
kubectl get pods
Write-Host ""

Write-Host "4️⃣ API URL:" -ForegroundColor Yellow
minikube service api-service --url
Write-Host ""

Write-Host "✅ KLART!" -ForegroundColor Green
