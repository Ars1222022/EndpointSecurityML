# =====================================================
# setup-dvc.ps1 - Data Version Control för EndpointSecurityML
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📦 DVC - DATA VERSION CONTROL" -ForegroundColor Cyan
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
# 2. RENSA GAMLA DVC-FILER
# ------------------------------
Write-Host "1️⃣ Rensar gamla DVC-filer..." -ForegroundColor Yellow

if (Test-Path ".dvc") { Remove-Item -Path ".dvc" -Recurse -Force }
if (Test-Path "dvc_cache") { Remove-Item -Path "dvc_cache" -Recurse -Force }
Get-ChildItem -Path . -Filter "*.dvc" | Remove-Item -Force
Write-Host "  ✅ Rensning klar" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. INSTALLERA DVC
# ------------------------------
Write-Host "2️⃣ Installerar DVC..." -ForegroundColor Yellow
pip install dvc --upgrade

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Installation misslyckades!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  ✅ DVC installerat" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 4. HITTA DVC
# ------------------------------
Write-Host "3️⃣ Letar efter DVC..." -ForegroundColor Yellow

$pythonScripts = "$env:USERPROFILE\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\LocalCache\local-packages\Python311\Scripts"

if (Test-Path "$pythonScripts\dvc.exe") {
    $dvcPath = "$pythonScripts\dvc.exe"
    $env:Path += ";$pythonScripts"
    Write-Host "  ✅ Hittade DVC" -ForegroundColor Green
} else {
    $dvcPath = "dvc"
    Write-Host "  ⚠️ Använder 'dvc' direkt" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 5. INITIERA DVC
# ------------------------------
Write-Host "4️⃣ Initierar DVC..." -ForegroundColor Yellow
& $dvcPath init --force
Write-Host "  ✅ DVC initierat" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 6. SKAPA CACHE-MAPP
# ------------------------------
Write-Host "5️⃣ Skapar cache-mapp..." -ForegroundColor Yellow
$dvcCachePath = Join-Path $ProjectRoot "dvc_cache"
New-Item -ItemType Directory -Path $dvcCachePath -Force | Out-Null
Write-Host "  ✅ Cache-mapp skapad: dvc_cache/" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. SKAPA EXPORTERINGS-SKRIPT
# ------------------------------
Write-Host "6️⃣ Skapar export_to_csv.py..." -ForegroundColor Yellow

$exportDir = Join-Path $ProjectRoot "src" "data_generation"
New-Item -ItemType Directory -Path $exportDir -Force | Out-Null
$exportScriptPath = Join-Path $exportDir "export_to_csv.py"

$exportScript = @'
import pandas as pd
import pyodbc
from datetime import datetime
import os

print("Ansluter till SQL Server...")
conn_str = "DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=EndpointSecurityML;Trusted_Connection=yes;"
conn = pyodbc.connect(conn_str)

print("Hämtar data...")
df = pd.read_sql("SELECT * FROM EndpointActivities", conn)

os.makedirs("data/raw", exist_ok=True)
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
csv_path = f"data/raw/endpoint_data_{timestamp}.csv"
df.to_csv(csv_path, index=False)
print(f"Sparade {len(df)} rader till {csv_path}")
conn.close()
'@

Set-Content -Path $exportScriptPath -Value $exportScript -Encoding UTF8
Write-Host "  ✅ export_to_csv.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. SKAPA DVC-KOMMANDON
# ------------------------------
Write-Host "7️⃣ Skapar dvc-kommandon.ps1..." -ForegroundColor Yellow

$dvcScriptPath = Join-Path $ProjectRoot "dvc-kommandon.ps1"
$dvcScript = @'
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "DVC - ENKLA KOMMANDON" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "1. Exportera data från SQL"
Write-Host "2. Lägg till CSV-fil i DVC"
Write-Host "3. Visa status"
Write-Host "4. Avsluta"
$val = Read-Host "Välj (1-4)"

if ($val -eq "1") { python src/data_generation/export_to_csv.py }
if ($val -eq "2") { 
    $files = Get-ChildItem data/raw/*.csv
    for ($i=0; $i -lt $files.Count; $i++) { Write-Host "$($i+1). $($files[$i].Name)" }
    $num = Read-Host "Välj filnummer"
    dvc add $files[$num-1].FullName
    git add "$($files[$num-1].FullName).dvc"
    git commit -m "Lägg till data $($files[$num-1].Name)"
}
if ($val -eq "3") { dvc status }
'@

Set-Content -Path $dvcScriptPath -Value $dvcScript -Encoding UTF8
Write-Host "  ✅ dvc-kommandon.ps1 skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 9. UPPDATERA .gitignore
# ------------------------------
Write-Host "8️⃣ Uppdaterar .gitignore..." -ForegroundColor Yellow
Add-Content -Path ".gitignore" -Value "`ndvc_cache/`n.dvc/tmp/`n*.mdf`n*.ldf"
Write-Host "  ✅ .gitignore uppdaterad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 10. KLAR!
# ------------------------------
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "✅ DVC SETUP KLAR!" -ForegroundColor Green
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Nästa steg:" -ForegroundColor Yellow
Write-Host "  .\dvc-kommandon.ps1" -ForegroundColor White