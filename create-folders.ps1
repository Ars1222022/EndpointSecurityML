# =====================================================
# create-folders.ps1 - Skapar mappstruktur (RENSAD VERSION)
# =====================================================
# Kör i PowerShell för att skapa alla nödvändiga mappar
# för EndpointSecurityML-projektet
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📁 SKAPAR MAPPSTRUKTUR FÖR ENDPOINTSECURITYML" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Write-Host "📁 Projektmapp: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# =====================================================
# 1. DEFINITION AV ALLA MAPPAR
# =====================================================
$Folders = @(
    # GitHub Actions
    ".github\workflows",
    
    # Data
    "data\raw",
    "data\processed",
    
    # Modeller
    "models\production",
    
    # Source code
    "src\data_generation",
    "src\training",
    "src\api",
    
    # Tester
    "tests",
    
    # Airflow
    "airflow\dags",
    "airflow\logs",
    "airflow\plugins",
    
    # Dokumentation
    "docs",
    
    # Monitoring
    "prometheus",
    "grafana",
    
    # Kubernetes
    "k8s",
    
    # MLflow
    "mlruns"
)

# =====================================================
# 2. SKAPA ALLA MAPPAR
# =====================================================
Write-Host "1️⃣ Skapar mappar..." -ForegroundColor Yellow
$createdCount = 0
foreach ($Folder in $Folders) {
    $FullPath = Join-Path $ProjectRoot $Folder
    if (-not (Test-Path $FullPath)) {
        New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
        Write-Host "  ✅ Skapad: $Folder" -ForegroundColor Green
        $createdCount++
    } else {
        Write-Host "  ⏩ Redan finns: $Folder" -ForegroundColor Gray
    }
}
Write-Host "  ✅ $createdCount nya mappar skapades" -ForegroundColor Green
Write-Host ""

# =====================================================
# 3. SKAPA .GITIGNORE
# =====================================================
Write-Host "2️⃣ Skapar .gitignore..." -ForegroundColor Yellow
$GitIgnorePath = Join-Path $ProjectRoot ".gitignore"

$GitIgnore = @"
# Python
__pycache__/
*.pyc
*.pyo
*.pyd
venv/
.env

# Editor
.vscode/
.DS_Store

# Data
*.csv
*.pkl
!data/raw/*.csv

# MLflow
mlruns/
mlartifacts/

# DVC
.dvc/
dvc_cache/

# Docker
*.mdf
*.ldf

# Logs
airflow/logs/
"@

Set-Content -Path $GitIgnorePath -Value $GitIgnore -Encoding UTF8
Write-Host "  ✅ .gitignore skapad" -ForegroundColor Green
Write-Host ""

# =====================================================
# 4. SKAPA README I DOKUMENTATION
# =====================================================
Write-Host "3️⃣ Skapar README i docs-mappen..." -ForegroundColor Yellow

$DocsReadme = Join-Path $ProjectRoot "docs\README.md"
@"
# Dokumentation

Denna mapp innehåller dokumentation för projektet.

## Tillgänglig dokumentation
- `AIRFLOW.md` - Airflow-specifik information
- `DOCKER.md` - Docker-kommandon och tjänster
"@ | Set-Content -Path $DocsReadme -Encoding UTF8
Write-Host "  ✅ docs/README.md skapad" -ForegroundColor Green
Write-Host ""

# =====================================================
# 5. SAMMANFATTNING
# =====================================================
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ KLART!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Skapade mappar:" -ForegroundColor Yellow
Get-ChildItem -Path $ProjectRoot -Directory | ForEach-Object {
    Write-Host "  📁 $($_.Name)" -ForegroundColor White
}
Write-Host ""
Write-Host "📋 Nästa steg:" -ForegroundColor Green
Write-Host "  Öppna mappen i VS Code och börja koda!" -ForegroundColor White