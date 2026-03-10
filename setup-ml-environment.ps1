# setup-ml-environment.ps1
# Automatisk setup för EndpointSecurityML-projektet

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "SETUP MILJÖ - EndpointSecurityML" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# ------------------------------
# 1. TESTA SQL SERVER-KOPPLING
# ------------------------------
Write-Host "1️⃣ Testar SQL Server-koppling..." -ForegroundColor Yellow

$sqlTest = @"
import pyodbc
try:
    conn = pyodbc.connect('DRIVER={ODBC Driver 17 for SQL Server};SERVER=localhost;DATABASE=master;Trusted_Connection=yes;', timeout=3)
    print('✅ SQL Server connection OK')
    conn.close()
except Exception as e:
    print(f'❌ SQL Server connection failed: {e}')
    exit(1)
"@

$result = python -c $sqlTest 2>&1
Write-Host $result

if ($result -match "❌") {
    Write-Host ""
    Write-Host "❌ Kan inte ansluta till SQL Server!" -ForegroundColor Red
    Write-Host "Kontrollera att:" -ForegroundColor Yellow
    Write-Host "  - SQL Server är igång" -ForegroundColor Yellow
    Write-Host "  - ODBC Driver 17 är installerat" -ForegroundColor Yellow
    Write-Host "  - Du använder Windows-autentisering" -ForegroundColor Yellow
    exit 1
}

# ------------------------------
# 2. SKAPA requirements.txt
# ------------------------------
Write-Host ""
Write-Host "2️⃣ Skapar requirements.txt..." -ForegroundColor Yellow

$requirementsPath = Join-Path $PSScriptRoot "requirements.txt"
$requirements = @"
pyodbc==5.0.0
pandas==2.0.3
scikit-learn==1.3.0
joblib==1.3.2
numpy==1.24.3
"@
Set-Content -Path $requirementsPath -Value $requirements -Encoding UTF8
Write-Host "  ✅ requirements.txt skapad" -ForegroundColor Green

# ------------------------------
# 3. INSTALLERA BIBLIOTEK
# ------------------------------
Write-Host ""
Write-Host "3️⃣ Installerar Python-bibliotek..." -ForegroundColor Yellow

pip install -r $requirementsPath

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Installation misslyckades!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  ✅ Bibliotek installerade" -ForegroundColor Green
}

# ------------------------------
# 4. SKAPA train_from_sql.py (KORREKT VERSION)
# ------------------------------
Write-Host ""
Write-Host "4️⃣ Skapar träningsskript..." -ForegroundColor Yellow

$trainDir = Join-Path $PSScriptRoot "src" "training"
if (-not (Test-Path $trainDir)) {
    New-Item -ItemType Directory -Path $trainDir -Force | Out-Null
}

$trainScriptPath = Join-Path $trainDir "train_from_sql.py"

$trainScript = @'
"""
train_from_sql.py
Läser träningsdata från SQL Server och förbereder för ML
"""

import pandas as pd
import pyodbc
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report
import joblib
from datetime import datetime

# ------------------------------
# 1. ANSLUT TILL SQL SERVER
# ------------------------------
print("Ansluter till SQL Server...")

conn_str = (
    "DRIVER={ODBC Driver 17 for SQL Server};"
    "SERVER=localhost;"
    "DATABASE=EndpointSecurityML;"
    "Trusted_Connection=yes;"
)

conn = pyodbc.connect(conn_str)

# ------------------------------
# 2. HÄMTA TRÄNINGSDATA
# ------------------------------
print("Hämtar träningsdata...")

query = """
SELECT 
    ActivityID,
    Timestamp,
    ComputerName,
    Username,
    ProcessName,
    ParentProcess,
    NetworkConnections,
    IsAttack,
    ThreatType,
    DATEPART(HOUR, Timestamp) as Hour,
    DATEPART(WEEKDAY, Timestamp) as DayOfWeek
FROM EndpointActivities
"""

df = pd.read_sql(query, conn)
print(f"Hämtade {len(df)} rader")

# ------------------------------
# 3. FÖRBERED DATA FÖR ML
# ------------------------------
print("Förbereder features...")

# Skapa features
df['IsSystemUser'] = (df['Username'] == 'system').astype(int)
df['IsSuspiciousProcess'] = df['ProcessName'].isin([
    'powershell.exe', 'cmd.exe', 'wannacry.exe', 'mimikatz.exe'
]).astype(int)

# Välj features och target
feature_cols = ['NetworkConnections', 'Hour', 'DayOfWeek', 
                'IsSystemUser', 'IsSuspiciousProcess']
X = df[feature_cols]
y = df['IsAttack']

# ------------------------------
# 4. DELA UPP DATA
# ------------------------------
X_train, X_test, y_train, y_test = train_test_split(
    X, y, test_size=0.2, random_state=42
)

print(f"Träningsdata: {len(X_train)} rader")
print(f"Testdata: {len(X_test)} rader")

# ------------------------------
# 5. TRÄNA MODELL
# ------------------------------
print("Tränar Random Forest-modell...")

model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# ------------------------------
# 6. UTVÄRDERA
# ------------------------------
y_pred = model.predict(X_test)
print("\nKlassificeringsrapport:")
print(classification_report(y_test, y_pred))

# ------------------------------
# 7. SPARA MODELL
# ------------------------------
timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
model_path = f"models/production/endpoint_model_{timestamp}.pkl"
joblib.dump(model, model_path)
print(f"\nModell sparad: {model_path}")

# ------------------------------
# 8. SPARA RESULTAT TILLBAKA TILL SQL
# ------------------------------
print("Sparar prediktioner till SQL Server...")

# Gör prediktioner på ALL data
df['PredictedAttack'] = model.predict(X)
df['Confidence'] = model.predict_proba(X).max(axis=1)

# Spara till ThreatDetections-tabellen
cursor = conn.cursor()

for _, row in df.iterrows():
    cursor.execute("""
        INSERT INTO ThreatDetections 
        (ActivityID, Timestamp, PredictedThreatType, ConfidenceScore, ModelVersion)
        VALUES (?, ?, ?, ?, ?)
    """, 
    row['ActivityID'], 
    datetime.now(), 
    'Attack' if row['PredictedAttack'] == 1 else 'Normal',
    row['Confidence'],
    f"v{timestamp}"
    )

conn.commit()
print(f"Sparad {len(df)} prediktioner till databasen")

conn.close()
print("Klart!")
'@

Set-Content -Path $trainScriptPath -Value $trainScript -Encoding UTF8
Write-Host "  ✅ train_from_sql.py skapad i src/training/" -ForegroundColor Green

# ------------------------------
# 5. SKAPA KÖR-SKRIPT
# ------------------------------
Write-Host ""
Write-Host "5️⃣ Skapar kör-skript..." -ForegroundColor Yellow

$runScriptPath = Join-Path $PSScriptRoot "run-training.ps1"
$runScript = @'
# run-training.ps1
Write-Host "Kör ML-träning..." -ForegroundColor Cyan
python src/training/train_from_sql.py
'@

Set-Content -Path $runScriptPath -Value $runScript -Encoding UTF8
Write-Host "  ✅ run-training.ps1 skapad" -ForegroundColor Green

# ------------------------------
# 6. SAMMANFATTNING
# ------------------------------
Write-Host ""
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "✅ SETUP KLAR!" -ForegroundColor Green
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "📋 Nästa steg:" -ForegroundColor Yellow
Write-Host "  1. Öppna SSMS och kör setup-database.sql" -ForegroundColor White
Write-Host "  2. Kör: .\run-training.ps1" -ForegroundColor White
Write-Host ""
Write-Host "   Detta kommer att:" -ForegroundColor Gray
Write-Host "   - Hämta data från SQL Server" -ForegroundColor Gray
Write-Host "   - Träna en Random Forest-modell" -ForegroundColor Gray
Write-Host "   - Spara resultat tillbaka till SQL" -ForegroundColor Gray