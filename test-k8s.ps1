# =====================================================
# test-k8s.ps1 - Testa Kubernetes
# =====================================================
Write-Host "📊 Kubernetes poddar:" -ForegroundColor Yellow
kubectl get pods
Write-Host "
📊 Kubernetes services:" -ForegroundColor Yellow
kubectl get services
Write-Host "
🚀 Testa API:et: curl http://localhost:8000/health" -ForegroundColor Green
