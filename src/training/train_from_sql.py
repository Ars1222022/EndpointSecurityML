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
