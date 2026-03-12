from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import pandas as pd
import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score
import joblib
import glob
import os

default_args = {
    'owner': 'ml_team',
    'start_date': datetime(2026, 3, 1),
    'retries': 1,
}

dag = DAG('ml_training', default_args=default_args, schedule_interval='0 3 * * *')

def train():
    files = glob.glob('/opt/airflow/data/raw/*.csv')
    if not files: return "No data"
    latest = max(files, key=os.path.getctime)
    df = pd.read_csv(latest)
    df['IsSuspicious'] = df['ProcessName'].isin(['powershell.exe','cmd.exe','wannacry.exe']).astype(int)
    X = df[['NetworkConnections','IsSuspicious']]
    y = df['IsAttack']
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2)
    model = RandomForestClassifier(n_estimators=100)
    model.fit(X_train, y_train)
    acc = float(accuracy_score(y_test, model.predict(X_test)))
    path = f'/opt/airflow/models/production/model_{datetime.now().strftime("%Y%m%d_%H%M%S")}.pkl'
    joblib.dump(model, path)
    return f"Accuracy: {acc:.3f}"

PythonOperator(task_id='train', python_callable=train, dag=dag)
