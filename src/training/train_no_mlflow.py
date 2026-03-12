"""train_no_mlflow.py - Tränar modell utan MLflow (för API:t)"""
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import glob
import os
from datetime import datetime

print("📊 Tränar modell för API...")

# Hitta senaste data
csv_files = glob.glob('data/raw/*.csv')
if not csv_files:
    print("❌ Ingen data hittad! Kopiera först data till containern.")
    exit(1)
    
latest_data = max(csv_files, key=os.path.getctime)
print(f"📁 Använder data: {latest_data}")

# Läs data
df = pd.read_csv(latest_data)
print(f"📊 Laddade {len(df)} rader")

# Förbered features
df['IsSuspicious'] = df['ProcessName'].isin(['powershell.exe','cmd.exe','wannacry.exe']).astype(int)
X = df[['NetworkConnections', 'IsSuspicious']]
y = df['IsAttack']

print(f"📈 Attack: {y.sum()}, Normal: {len(y)-y.sum()}")

# Dela data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# Träna
model = RandomForestClassifier(n_estimators=100, random_state=42)
model.fit(X_train, y_train)

# Utvärdera
accuracy = accuracy_score(y_test, model.predict(X_test))
print(f"🎯 Accuracy: {accuracy:.3f}")

# Spara
timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
model_path = f'models/production/endpoint_model_{timestamp}.pkl'
joblib.dump(model, model_path)
print(f"💾 Modell sparad: {model_path}")
print("✅ Träning klar!")
