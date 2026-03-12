import pytest
from fastapi.testclient import TestClient
import sys
import os
sys.path.append(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from src.api.app import app

client = TestClient(app)

def test_health():
    response = client.get("/health")
    assert response.status_code == 200

def test_predict_normal():
    response = client.post("/predict", json={"NetworkConnections": 0, "ProcessName": "notepad.exe"})
    assert response.status_code == 200
    assert response.json()["prediction"] == 0

def test_predict_attack():
    response = client.post("/predict", json={"NetworkConnections": 1, "ProcessName": "powershell.exe"})
    assert response.status_code == 200
    assert response.json()["prediction"] == 1
