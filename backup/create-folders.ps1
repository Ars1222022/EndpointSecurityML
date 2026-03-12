# create-folders.ps1 - Kör i PowerShell
# Skapar alla mappar för EndpointSecurityML-projektet

$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

$Folders = @(
    ".github\workflows",
    "data\raw",
    "data\processed", 
    "data\generated",
    "models\experiments",
    "models\production",
    "src\data_generation",
    "src\features",
    "src\training",
    "src\api",
    "src\monitoring",
    "notebooks",
    "tests",
    "docker",
    "airflow\dags",
    "docs",
    "config"
)

Write-Host "Skapar mappar i: $ProjectRoot" -ForegroundColor Green

foreach ($Folder in $Folders) {
    $FullPath = Join-Path $ProjectRoot $Folder
    New-Item -ItemType Directory -Path $FullPath -Force | Out-Null
    Write-Host "  ✅ Skapad: $Folder"
}

Write-Host ""
Write-Host "Skapar .gitignore..." -ForegroundColor Green
$GitIgnore = @"
__pycache__/
*.pyc
venv/
.env
.vscode/
.DS_Store
*.csv
*.pkl
mlruns/
"@
Set-Content -Path (Join-Path $ProjectRoot ".gitignore") -Value $GitIgnore

Write-Host ""
Write-Host "✅ Klart! Nu kan du öppna mappen i VS Code" -ForegroundColor Green