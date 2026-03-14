# =====================================================
# setup-mlflow.ps1 - UNIVERSAL MLflow-installation
# =====================================================
# Detta skript fungerar på ALLA datorer oavsett sökväg
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📊 MLFLOW - UNIVERSAL INSTALLATION" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. HITTA PROJEKTROTEN (fungerar alltid)
# ------------------------------
$ProjectRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ProjectRoot
Write-Host "📁 Projektmapp: $ProjectRoot" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 2. RENSA GAMLA PROBLEMATISKA PAKET
# ------------------------------
Write-Host "1️⃣ Rensar paket som skapar konflikter..." -ForegroundColor Yellow

$problemPackets = @("contourpy", "skops", "matplotlib", "opentelemetry*")
foreach ($paket in $problemPackets) {
    pip uninstall $paket -y 2>$null
}
Write-Host "  ✅ Rensning klar" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 3. INSTALLERA MLflow (utan extra paket)
# ------------------------------
Write-Host "2️⃣ Installerar MLflow (utan extra paket)..." -ForegroundColor Yellow

# Först, se till att rätt numpy-version finns
pip install numpy==1.24.3 pandas==2.0.3 --force-reinstall

# Installera endast mlflow-skinny (mindre version)
pip install mlflow-skinny

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Installation misslyckades!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  ✅ MLflow installerat" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 4. HITTA VAR MLflow INSTALLERADES (AUTOMATISKT)
# ------------------------------
Write-Host "3️⃣ Letar efter MLflow (automatiskt)..." -ForegroundColor Yellow

# Metod 1: Leta i vanliga Python-mappar
$possiblePaths = @(
    "$env:USERPROFILE\AppData\Local\Programs\Python\Python311\Scripts",
    "$env:USERPROFILE\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\LocalCache\local-packages\Python311\Scripts",
    "C:\Python311\Scripts",
    "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts"
)

$mlflowFound = $false
$mlflowPath = "mlflow"  # default

foreach ($path in $possiblePaths) {
    $testPath = Join-Path $path "mlflow.exe"
    if (Test-Path $testPath) {
        $mlflowPath = $testPath
        $mlflowFound = $true
        Write-Host "  ✅ Hittade MLflow på: $mlflowPath" -ForegroundColor Green
        
        # Lägg till i PATH för denna session
        $env:Path += ";$path"
        Write-Host "  ✅ Lade till i PATH (för denna session)" -ForegroundColor Green
        break
    }
}

if (-not $mlflowFound) {
    Write-Host "  ⚠️ Kunde inte hitta MLflow, använder 'mlflow' direkt" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 5. SKAPA MLFLOW-MAPP
# ------------------------------
Write-Host "4️⃣ Skapar mapp för MLflow-experiment..." -ForegroundColor Yellow
$mlflowDir = Join-Path $ProjectRoot "mlruns"
if (-not (Test-Path $mlflowDir)) {
    New-Item -ItemType Directory -Path $mlflowDir -Force | Out-Null
    Write-Host "  ✅ Mapp skapad: mlruns/" -ForegroundColor Green
} else {
    Write-Host "  ⏩ Mapp finns redan" -ForegroundColor Gray
}
Write-Host ""

# ------------------------------
# 6. SKAPA TRÄNINGSSKRIPT MED MLflow
# ------------------------------
Write-Host "5️⃣ Skapar träningsskript med MLflow..." -ForegroundColor Yellow

$trainDir = Join-Path $ProjectRoot "src" "training"
New-Item -ItemType Directory -Path $trainDir -Force | Out-Null
$trainScriptPath = Join-Path $trainDir "train_with_mlflow.py"

$trainScript = @'
"""
train_with_mlflow.py - Tränar modell och loggar med MLflow
"""

import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score, precision_score, recall_score, f1_score
import mlflow
import mlflow.sklearn
import joblib
import os
from datetime import datetime
import glob

print("📊 Versioner:")
print(f"  • Pandas: {pd.__version__}")
print(f"  • NumPy: {np.__version__}")
print(f"  • MLflow: {mlflow.__version__}")
print("")

# Hitta senaste data
print("🔍 Letar efter senaste data...")
csv_files = glob.glob("data/raw/*.csv")
if not csv_files:
    print("❌ Inga CSV-filer hittade!")
    exit(1)

latest_data = max(csv_files, key=os.path.getctime)
print(f"  ✅ Använder data: {latest_data}")

# Läs data
df = pd.read_csv(latest_data)
print(f"  📊 Laddade {len(df)} rader")

# Förbered features
print("🔧 Förbereder features...")
df['IsSystemUser'] = (df['Username'] == 'system').astype(int)
df['IsSuspiciousProcess'] = df['ProcessName'].isin([
    'powershell.exe', 'cmd.exe', 'wannacry.exe', 'mimikatz.exe'
]).astype(int)

feature_cols = ['NetworkConnections', 'IsSystemUser', 'IsSuspiciousProcess']
X = df[feature_cols]
y = df['IsAttack']

print(f"  ✅ Features: {feature_cols}")
print(f"  ✅ Attack: {y.sum()}, Normal: {len(y)-y.sum()}")

# Dela upp data
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42, stratify=y
)

print(f"  ✅ Träningsdata: {len(X_train)} rader")
print(f"  ✅ Testdata: {len(X_test)} rader")
print("")

# MLflow tracking
print("📊 Startar MLflow tracking...")
experiment_name = f"EndpointSecurity_{datetime.now().strftime('%Y%m%d')}"
mlflow.set_experiment(experiment_name)

with mlflow.start_run() as run:
    
    print("  📝 Loggar parametrar...")
    n_estimators = 100
    max_depth = 10
    
    mlflow.log_param("model_type", "RandomForest")
    mlflow.log_param("n_estimators", n_estimators)
    mlflow.log_param("max_depth", max_depth)
    mlflow.log_param("data_file", os.path.basename(latest_data))
    
    print("  🤖 Tränar modell...")
    model = RandomForestClassifier(
        n_estimators=n_estimators,
        max_depth=max_depth,
        random_state=42
    )
    model.fit(X_train, y_train)
    
    print("  📈 Utvärderar modell...")
    y_pred = model.predict(X_test)
    
    accuracy = accuracy_score(y_test, y_pred)
    precision = precision_score(y_test, y_pred)
    recall = recall_score(y_test, y_pred)
    f1 = f1_score(y_test, y_pred)
    
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("precision", precision)
    mlflow.log_metric("recall", recall)
    mlflow.log_metric("f1_score", f1)
    
    print(f"\n  ✅ Accuracy: {accuracy:.3f}")
    print(f"  ✅ Precision: {precision:.3f}")
    print(f"  ✅ Recall: {recall:.3f}")
    print(f"  ✅ F1-score: {f1:.3f}")
    
    print("\n  💾 Sparar modell...")
    mlflow.sklearn.log_model(model, "random_forest_model")
    
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    model_path = f"models/production/endpoint_model_{timestamp}.pkl"
    joblib.dump(model, model_path)
    
    print(f"  ✅ Modell sparad: {model_path}")
    
    # Feature importance
    for feature, importance in zip(feature_cols, model.feature_importances_):
        mlflow.log_metric(f"importance_{feature}", importance)
        print(f"  ✅ Feature importance - {feature}: {importance:.3f}")
    
    print(f"\n📊 MLflow run ID: {run.info.run_id}")
    print(f"📁 MLflow experiment: {experiment_name}")

print("\n✅ Träning klar!")
'@

Set-Content -Path $trainScriptPath -Value $trainScript -Encoding UTF8
Write-Host "  ✅ train_with_mlflow.py skapad" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 7. SKAPA MLFLOW-MENY (UNIVERSAL - FUNGERAR ÖVERALLT)
# ------------------------------
Write-Host "6️⃣ Skapar MLflow-menyskript (UNIVERSAL)..." -ForegroundColor Yellow

$mlflowMenuPath = Join-Path $ProjectRoot "mlflow-kommandon.ps1"

$mlflowMenu = @'
# =====================================================
# mlflow-kommandon.ps1 - UNIVERSAL (fungerar på alla datorer)
# =====================================================

# Hitta MLflow automatiskt
function Find-MLflow {
    $possiblePaths = @(
        "$env:USERPROFILE\AppData\Local\Programs\Python\Python311\Scripts\mlflow.exe",
        "$env:USERPROFILE\AppData\Local\Packages\PythonSoftwareFoundation.Python.3.11_qbz5n2kfra8p0\LocalCache\local-packages\Python311\Scripts\mlflow.exe",
        "C:\Python311\Scripts\mlflow.exe",
        "$env:LOCALAPPDATA\Programs\Python\Python311\Scripts\mlflow.exe"
    )
    
    foreach ($path in $possiblePaths) {
        if (Test-Path $path) {
            return $path
        }
    }
    return "mlflow"  # fallback
}

$mlflowExe = Find-MLflow

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📊 MLFLOW - ENKLA KOMMANDON" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "VAD VILL DU GÖRA?" -ForegroundColor Yellow
Write-Host "  1. Träna modell och logga i MLflow" -ForegroundColor White
Write-Host "  2. Starta MLflow UI (webbgränssnitt)" -ForegroundColor White
Write-Host "  3. Visa senaste experiment" -ForegroundColor White
Write-Host "  4. Avsluta" -ForegroundColor White
Write-Host ""

$val = Read-Host "Välj (1-4)"

switch ($val) {
    "1" {
        Write-Host ""
        Write-Host "🤖 Tränar modell med MLflow tracking..." -ForegroundColor Cyan
        Write-Host ""
        python src/training/train_with_mlflow.py
    }
    "2" {
        Write-Host ""
        Write-Host "🌐 Startar MLflow UI på http://localhost:5000" -ForegroundColor Cyan
        Write-Host "Tryck Ctrl+C för att stoppa servern" -ForegroundColor Yellow
        Write-Host ""
        
        # Ta bort gammal databas om den finns
        if (Test-Path "mlflow.db") {
            Remove-Item "mlflow.db" -Force
        }
        
        # Starta UI med rätt backend
        & $mlflowExe ui --backend-store-uri mlruns
    }
    "3" {
        Write-Host ""
        Write-Host "📋 Senaste experiment i mlruns/ :" -ForegroundColor Cyan
        Write-Host ""
        if (Test-Path "mlruns") {
            Get-ChildItem -Path "mlruns" -Directory | Where-Object { $_.Name -match "^\d+$" } | ForEach-Object {
                $expId = $_.Name
                $metaFile = "mlruns/$expId/meta.yaml"
                if (Test-Path $metaFile) {
                    $expName = (Get-Content $metaFile | Select-String "name:" | Select-Object -First 1).ToString().Split(':')[1].Trim()
                    Write-Host "  📁 Experiment: $expName (ID: $expId)" -ForegroundColor Yellow
                    
                    # Visa runs i detta experiment
                    Get-ChildItem -Path "mlruns/$expId" -Directory | Where-Object { $_.Name -match "^[a-f0-9]+$" } | Select-Object -Last 3 | ForEach-Object {
                        $runId = $_.Name
                        Write-Host "      • Run: $runId" -ForegroundColor White
                    }
                }
            }
        } else {
            Write-Host "  ❌ Inga experiment ännu. Kör först alternativ 1." -ForegroundColor Red
        }
    }
    "4" {
        Write-Host ""
        Write-Host "Hej då!" -ForegroundColor Cyan
        exit
    }
    default {
        Write-Host ""
        Write-Host "❌ Ogiltigt val" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Tryck på valfri tangent för att avsluta..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

Set-Content -Path $mlflowMenuPath -Value $mlflowMenu -Encoding UTF8
Write-Host "  ✅ mlflow-kommandon.ps1 skapad (UNIVERSAL)" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 8. UPPDATERA .gitignore
# ------------------------------
Write-Host "7️⃣ Uppdaterar .gitignore med MLflow..." -ForegroundColor Yellow

$gitignorePath = Join-Path $ProjectRoot ".gitignore"
$mlflowIgnore = @"

# MLflow
mlruns/
mlartifacts/
mlflow.db
"@

# Lägg bara till om det inte redan finns
$currentContent = Get-Content $gitignorePath -Raw
if ($currentContent -notmatch "mlruns/") {
    Add-Content -Path $gitignorePath -Value $mlflowIgnore
    Write-Host "  ✅ .gitignore uppdaterad" -ForegroundColor Green
} else {
    Write-Host "  ⏩ .gitignore redan uppdaterad" -ForegroundColor Gray
}
Write-Host ""

# ------------------------------
# 9. RENSA GAMMAL KORRUPT DATA
# ------------------------------
Write-Host "8️⃣ Rensar eventuell korrupt data..." -ForegroundColor Yellow

if (Test-Path "mlruns\1") {
    # Kolla om det är korrupt
    if (-not (Test-Path "mlruns\1\meta.yaml")) {
        Remove-Item -Path "mlruns\1" -Recurse -Force
        Write-Host "  ✅ Rensade korrupt experiment-mapp" -ForegroundColor Green
    }
}

if (Test-Path "mlflow.db") {
    Remove-Item "mlflow.db" -Force
    Write-Host "  ✅ Rensade gammal databas" -ForegroundColor Green
}
Write-Host ""

# ------------------------------
# 10. TESTA MLflow
# ------------------------------
Write-Host "9️⃣ Testar MLflow..." -ForegroundColor Yellow

try {
    if ($mlflowFound) {
        $version = & $mlflowPath --version
        Write-Host "  ✅ MLflow fungerar: $version" -ForegroundColor Green
    } else {
        Write-Host "  ⚠️ MLflow test hoppades över" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  ⚠️ MLflow test misslyckades - men menyn hanterar det" -ForegroundColor Yellow
}
Write-Host ""

# ------------------------------
# 11. KLAR!
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ MLFLOW SETUP KLAR! (UNIVERSAL)" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 NÄSTA STEG:" -ForegroundColor Green
Write-Host "  1. Kör: .\mlflow-kommandon.ps1" -ForegroundColor Yellow
Write-Host "  2. Välj 1 för att träna en modell" -ForegroundColor Yellow
Write-Host "  3. Välj 2 för att starta MLflow UI" -ForegroundColor Yellow
Write-Host "  4. Öppna webbläsaren på http://localhost:5000" -ForegroundColor Yellow
Write-Host ""
Write-Host "📁 MLflow experiment sparas i: mlruns/" -ForegroundColor Gray