import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import mlflow
import glob
import os

print("📊 MLflow version:", mlflow.__version__)
print("")

# Hitta data
print("🔍 Letar efter data...")
csv_files = glob.glob("data/raw/*.csv")
if not csv_files:
    print("❌ Ingen data hittad! Kör först dvc-kommandon.ps1 (val 1)")
    exit(1)

latest_data = max(csv_files, key=os.path.getctime)
print(f"  ✅ Använder: {latest_data}")
df = pd.read_csv(latest_data)
print(f"  📊 Laddade {len(df)} rader")
print("")

# Förbered features
print("🔧 Förbereder features...")
df['IsSuspicious'] = df['ProcessName'].isin(['powershell.exe', 'cmd.exe', 'wannacry.exe']).astype(int)
X = df[['NetworkConnections', 'IsSuspicious']]
y = df['IsAttack']

print(f"  ✅ Attack: {y.sum()}, Normal: {len(y)-y.sum()}")
print("")

# Dela data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

# MLflow
mlflow.set_experiment("EndpointSecurity_Docker")

with mlflow.start_run() as run:
    print("🤖 Tränar modell...")
    model = RandomForestClassifier(n_estimators=300, random_state=42)
    model.fit(X_train, y_train)
    
    print("📈 Utvärderar...")
    y_pred = model.predict(X_test)
    accuracy = float(accuracy_score(y_test, y_pred))
    
    # Logga
    mlflow.log_param("n_estimators", 100)
    mlflow.log_param("model_type", "RandomForest")
    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("attack_count", int(y.sum()))
    mlflow.log_metric("normal_count", int(len(y)-y.sum()))
    
    # Feature importance
    for feature, importance in zip(['NetworkConnections', 'IsSuspicious'], model.feature_importances_):
        mlflow.log_metric(f"importance_{feature}", float(importance))
    
    print(f"\n  ✅ Accuracy: {accuracy:.3f}")
    print(f"  ✅ Feature importance - NetworkConnections: {model.feature_importances_[0]:.3f}")
    print(f"  ✅ Feature importance - IsSuspicious: {model.feature_importances_[1]:.3f}")
    print(f"\n📊 Run ID: {run.info.run_id}")
    print(f"📁 Experiment: EndpointSecurity_Docker")
    print(f"🔗 MLflow UI: http://localhost:5000")
