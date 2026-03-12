from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator
import requests

default_args = {'owner': 'ml_team', 'start_date': datetime(2026, 3, 1)}
dag = DAG('api_monitoring', default_args=default_args, schedule_interval='0 * * * *')

def check():
    r = requests.get("http://api:8000/health", timeout=5)
    return "OK" if r.status_code == 200 else "Fail"

PythonOperator(task_id='check', python_callable=check, dag=dag)
