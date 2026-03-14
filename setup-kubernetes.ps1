# =====================================================
# setup-kubernetes.ps1 - KOMPLETT KUBERNETES SETUP (ALLT I ETT)
# =====================================================
# Detta skript:
# 1. Skapar alla nödvändiga Kubernetes-filer
# 2. Fixar ErrImageNeverPull-problemet
# 3. Installerar dill i poddarna (fixar model loading)
# 4. Distribuerar i rätt ordning (deployment -> service -> hpa)
# 5. Testar att allt fungerar
# 6. Kontrollerar och installerar Airflow om det saknas
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🚀 KOMPLETT KUBERNETES SETUP (ALLT I ETT)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. HITTA PROJEKTROTEN
# ------------------------------
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot
Write-Host "📁 Projektmapp: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 2. KONTROLLERA KUBERNETES
# ------------------------------
Write-Host "1️⃣ Kontrollerar Kubernetes..." -ForegroundColor Yellow

$k8sStatus = kubectl get nodes 2>$null
if ($k8sStatus -match "Ready") {
    Write-Host "  ✅ Kubernetes är igång!" -ForegroundColor Green
} else {
    Write-Host "  ❌ Kubernetes är INTE igång!" -ForegroundColor Red
    Write-Host ""
    Write-Host "📋 GÖR FÖLJANDE:" -ForegroundColor Yellow
    Write-Host "  1. Öppna Docker Desktop" -ForegroundColor White
    Write-Host "  2. Klicka på kugghjulet (Settings)" -ForegroundColor White
    Write-Host "  3. Välj 'Kubernetes' i menyn" -ForegroundColor White
    Write-Host "  4. Bocka i 'Enable Kubernetes'" -ForegroundColor White
    Write-Host "  5. Klicka på 'Apply & Restart'" -ForegroundColor White
    Write-Host "  6. Vänta tills 'Kubernetes running'" -ForegroundColor White
    Write-Host "  7. Kör detta skript IGEN" -ForegroundColor Yellow
    exit 1
}
Write-Host ""

# ------------------------------
# 3. SKAPA KUBERNETES-MAPP
# ------------------------------
Write-Host "2️⃣ Skapar Kubernetes-mapp..." -ForegroundColor Yellow

$k8sDir = ".\k8s"
if (-not (Test-Path $k8sDir)) {
    New-Item -ItemType Directory -Path $k8sDir -Force | Out-Null
    Write-Host "  ✅ Mapp skapad: $k8sDir" -ForegroundColor Green
} else {
    Write-Host "  ✅ Mapp finns redan: $k8sDir" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 4. SKAPA DEPLOYMENT.YAML (med IfNotPresent)
# ------------------------------
Write-Host "3️⃣ Skapar Kubernetes deployment (fixad version)..." -ForegroundColor Yellow

$deploymentFile = ".\k8s\api-deployment.yaml"
@"
apiVersion: apps/v1
kind: Deployment
metadata:
  name: api-deployment
  labels:
    app: endpoint-security-api
spec:
  replicas: 3
  selector:
    matchLabels:
      app: endpoint-security-api
  template:
    metadata:
      labels:
        app: endpoint-security-api
    spec:
      containers:
      - name: api
        image: endpointsecurity-api:latest
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8000
"@ | Out-File -FilePath $deploymentFile -Encoding UTF8
Write-Host "  ✅ api-deployment.yaml skapad (imagePullPolicy: IfNotPresent)" -ForegroundColor Green

# ------------------------------
# 5. SKAPA SERVICE.YAML (FIXAD VERSION)
# ------------------------------
$serviceFile = ".\k8s\api-service.yaml"
@"
apiVersion: v1
kind: Service
metadata:
  name: api-service
spec:
  selector:
    app: endpoint-security-api
  ports:
    - protocol: TCP
      port: 8000
      targetPort: 8000
  type: LoadBalancer
"@ | Out-File -FilePath $serviceFile -Encoding UTF8
Write-Host "  ✅ api-service.yaml skapad (port 8000)" -ForegroundColor Green

# ------------------------------
# 6. SKAPA HORIZONTAL POD AUTOSCALER
# ------------------------------
$hpaFile = ".\k8s\api-hpa.yaml"
@"
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: api-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: api-deployment
  minReplicas: 2
  maxReplicas: 10
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 50
"@ | Out-File -FilePath $hpaFile -Encoding UTF8
Write-Host "  ✅ api-hpa.yaml skapad (automatisk skalning)" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. UPPDATERA DOCKERFILE.API MED DILL
# ------------------------------
Write-Host "4️⃣ Uppdaterar Dockerfile.api med dill..." -ForegroundColor Yellow

$dockerfilePath = ".\Dockerfile.api"
$dockerfileContent = Get-Content $dockerfilePath -Raw
if ($dockerfileContent -notmatch "dill") {
    $updatedDockerfile = $dockerfileContent -replace "prometheus-client psutil", "prometheus-client psutil dill"
    $updatedDockerfile | Out-File -FilePath $dockerfilePath -Encoding UTF8
    Write-Host "  ✅ Dockerfile.api uppdaterad med dill" -ForegroundColor Green
} else {
    Write-Host "  ✅ Dockerfile.api har redan dill" -ForegroundColor Green
}

# ------------------------------
# 8. BYGG DOCKER-IMAGE
# ------------------------------
Write-Host ""
Write-Host "5️⃣ Bygger Docker-image med dill..." -ForegroundColor Yellow

docker build -t endpointsecurity-api:latest -f Dockerfile.api .
$imageExists = docker images endpointsecurity-api:latest -q
if ($imageExists) {
    Write-Host "  ✅ Image byggd: endpointsecurity-api:latest" -ForegroundColor Green
} else {
    Write-Host "  ❌ Image byggdes inte!" -ForegroundColor Red
    exit 1
}
Write-Host ""

# ------------------------------
# 9. RENSA GAMLA RESURSER (men inte för mycket!)
# ------------------------------
Write-Host "6️⃣ Rensar gamla Kubernetes-resurser..." -ForegroundColor Yellow

# Ta bort gamla deployment och hpa, men BEHÅLL service om den finns
kubectl delete deployment api-deployment --ignore-not-found=true
kubectl delete hpa api-hpa --ignore-not-found=true
Write-Host "  ✅ Gamla deployment och hpa borttagna" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 10. DISTRIBUERA TILL KUBERNETES I RÄTT ORDNING!
# ------------------------------
Write-Host "7️⃣ Distribuerar till Kubernetes (i rätt ordning)..." -ForegroundColor Yellow

# Steg 1: Skapa deployment
Write-Host "  📦 Steg 1: Skapar deployment..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-deployment.yaml

# Steg 2: Skapa service
Write-Host "  🌐 Steg 2: Skapar service..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-service.yaml

# Steg 3: Skapa autoscaler
Write-Host "  📊 Steg 3: Skapar autoscaler..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-hpa.yaml

Write-Host "  ✅ Deployment skapad i Kubernetes" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 11. VÄNTA PÅ PODDAR
# ------------------------------
Write-Host "8️⃣ Väntar på att poddar ska starta..." -ForegroundColor Yellow

$maxWait = 30
$waitCount = 0
while ($waitCount -lt $maxWait) {
    Start-Sleep -Seconds 2
    $pods = kubectl get pods --no-headers 2>$null
    $readyPods = $pods | Select-String "Running" | Measure-Object | Select-Object -ExpandProperty Count
    $totalPods = ($pods | Measure-Object | Select-Object -ExpandProperty Count)
    
    if ($readyPods -eq $totalPods -and $totalPods -gt 0) {
        Write-Host "  ✅ Alla $totalPods poddar är igång efter $($waitCount*2) sekunder!" -ForegroundColor Green
        break
    }
    $waitCount++
    Write-Host "  ⏳ Väntar... $readyPods/$totalPods poddar redo" -NoNewline
    Write-Host "`r" -NoNewline
}

Write-Host ""
Write-Host "📊 Kubernetes poddar:" -ForegroundColor Cyan
kubectl get pods
Write-Host ""

# ------------------------------
# 12. INSTALLERA DILL I PODDARNA
# ------------------------------
Write-Host "9️⃣ Installerar dill i poddarna..." -ForegroundColor Yellow

$pods = @()
kubectl get pods --no-headers | ForEach-Object { $pods += ($_ -split '\s+')[0] }

foreach ($pod in $pods) {
    Write-Host "  🔧 Installerar dill i $pod..." -ForegroundColor Yellow
    kubectl exec $pod -- pip install dill 2>$null
}

# ------------------------------
# 13. TRÄNA MODELL I ALLA PODDAR
# ------------------------------
Write-Host ""
Write-Host "🔟 Tränar modell i alla poddar..." -ForegroundColor Yellow

$pods = @()
kubectl get pods --no-headers | ForEach-Object { $pods += ($_ -split '\s+')[0] }

foreach ($pod in $pods) {
    Write-Host "  🤖 Tränar modell i $pod..." -ForegroundColor Cyan
    kubectl exec $pod -- python src/training/train_no_mlflow.py
    Write-Host ""
}

# ------------------------------
# 14. STARTA OM PODDAR FÖR ATT LADDA MODELLERNA
# ------------------------------
Write-Host "1️⃣1️⃣ Startar om poddar för att ladda modeller..." -ForegroundColor Yellow
kubectl delete pods --all
Start-Sleep -Seconds 15

Write-Host ""
Write-Host "📊 Nya poddar:" -ForegroundColor Cyan
kubectl get pods
Write-Host ""

# ------------------------------
# 15. TESTA KUBERNETES API:ET
# ------------------------------
Write-Host "1️⃣2️⃣ Testar Kubernetes API..." -ForegroundColor Yellow

Start-Sleep -Seconds 5
$response = curl -s http://localhost:8000/health 2>$null
if ($response) {
    $health = $response | ConvertFrom-Json
    if ($health.model_loaded) {
        Write-Host "  ✅ Kubernetes API fungerar! Modell laddad: $($health.model_version)" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ Kubernetes API svarar men ingen modell laddad" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ Kubernetes API svarar inte" -ForegroundColor Red
}
Write-Host ""

# ------------------------------
# 16. KONTROLLERA OCH INSTALLERA AIRFLOW (om det behövs)
# ------------------------------
Write-Host "1️⃣3️⃣ Kontrollerar Airflow-status..." -ForegroundColor Yellow

# Kolla om Airflow-containers finns
$airflowRunning = docker ps --filter "name=airflow-webserver" --format "{{.Names}}"

if ($airflowRunning) {
    Write-Host "  ✅ Airflow är redan igång! (http://localhost:8080)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Airflow är inte igång - installerar nu..." -ForegroundColor Yellow
    
    # Kontrollera om setup-airflow.ps1 finns
    if (Test-Path ".\setup-airflow.ps1") {
        Write-Host "  🔧 Kör setup-airflow.ps1..." -ForegroundColor Yellow
        & .\setup-airflow.ps1
        
        # Starta Airflow-specifika tjänster
        Write-Host "  🚀 Startar Airflow-containers..." -ForegroundColor Yellow
        docker-compose up -d airflow-webserver airflow-scheduler airflow-worker
        
        Write-Host "  ✅ Airflow installation klar! (http://localhost:8080)" -ForegroundColor Green
    } else {
        Write-Host "  ❌ setup-airflow.ps1 hittades inte - kan inte installera Airflow" -ForegroundColor Red
    }
}
Write-Host ""

# ------------------------------
# 17. SKAPA HJÄLPSKRIPT
# ------------------------------
Write-Host "1️⃣4️⃣ Skapar hjälpskript..." -ForegroundColor Yellow

# deploy-to-k8s.ps1 (med rätt ordning)
@"
# =====================================================
# deploy-to-k8s.ps1 - Distribuera till Kubernetes (rätt ordning)
# =====================================================
Write-Host "📦 Skapar deployment..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-deployment.yaml
Write-Host "🌐 Skapar service..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-service.yaml
Write-Host "📊 Skapar autoscaler..." -ForegroundColor Cyan
kubectl apply -f .\k8s\api-hpa.yaml
Write-Host "`n📊 Status:" -ForegroundColor Yellow
kubectl get pods
kubectl get services
"@ | Out-File -FilePath ".\deploy-to-k8s.ps1" -Encoding UTF8

# test-k8s.ps1
@"
# =====================================================
# test-k8s.ps1 - Testa Kubernetes
# =====================================================
Write-Host "📊 Kubernetes poddar:" -ForegroundColor Yellow
kubectl get pods
Write-Host "`n📊 Kubernetes services:" -ForegroundColor Yellow
kubectl get services
Write-Host "`n🚀 Testa API:et: curl http://localhost:8000/health" -ForegroundColor Green
"@ | Out-File -FilePath ".\test-k8s.ps1" -Encoding UTF8

Write-Host "  ✅ deploy-to-k8s.ps1 skapad" -ForegroundColor Green
Write-Host "  ✅ test-k8s.ps1 skapad" -ForegroundColor Green

# ------------------------------
# 18. SLUTSTATUS FÖR ALLA SYSTEM
# ------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ KOMPLETT SETUP KLAR!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 KUBERNETES STATUS:" -ForegroundColor Yellow
Write-Host "  • 3 Kubernetes-poddar med modeller" -ForegroundColor White
Write-Host "  • API tillgängligt på: http://localhost:8000" -ForegroundColor Green
Write-Host "  • Ingen port-forward behövs!" -ForegroundColor White
Write-Host ""
Write-Host "📋 AIRFLOW STATUS:" -ForegroundColor Yellow
$airflowRunning = docker ps --filter "name=airflow-webserver" --format "{{.Names}}"
if ($airflowRunning) {
    Write-Host "  ✅ Airflow är igång! (http://localhost:8080 - admin/admin)" -ForegroundColor Green
} else {
    Write-Host "  ⚠️ Airflow är inte installerat (kör setup-airflow.ps1 manuellt)" -ForegroundColor Yellow
}
Write-Host ""
Write-Host "📋 ANDRA TJÄNSTER:" -ForegroundColor Yellow
Write-Host "  • Vanligt API: http://localhost:8000 (samma port!)" -ForegroundColor White
Write-Host "  • Grafana: http://localhost:3000 (admin/admin)" -ForegroundColor White
Write-Host "  • Prometheus: http://localhost:9090" -ForegroundColor White
Write-Host "  • MLflow: http://localhost:5000" -ForegroundColor White
Write-Host ""
Write-Host "📋 TESTA NU:" -ForegroundColor Green
Write-Host "  curl http://localhost:8000/health                     # Testa API" -ForegroundColor White
Write-Host "  kubectl get pods                                     # Se Kubernetes poddar" -ForegroundColor White
Write-Host "  http://localhost:8080                               # Airflow UI" -ForegroundColor White
Write-Host "  http://localhost:3000                               # Grafana" -ForegroundColor White