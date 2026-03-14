# =====================================================
# deploy-to-k8s.ps1 - Distribuera till Kubernetes (rätt ordning)
# =====================================================
Write-Host "📦 Skapar deployment..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-deployment.yaml
Write-Host "🌐 Skapar service..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-service.yaml
Write-Host "📊 Skapar autoscaler..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-hpa.yaml
Write-Host "
📊 Status:" -ForegroundColor Yellow
kubectl get pods
kubectl get services
