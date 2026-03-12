"""
tests/test_api.py - Enhetstester för API:et
"""

import pytest
import requests

API_URL = "http://localhost:8000"

def test_health():
    """Testar att health endpoint fungerar"""
    response = requests.get(f"{API_URL}/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"

def test_predict_normal():
    """Testar prediktion med normal process"""
    response = requests.post(
        f"{API_URL}/predict",
        json={"NetworkConnections": 0, "ProcessName": "notepad.exe"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] == 0
    assert data["threat_type"] == "Normal"

def test_predict_attack():
    """Testar prediktion med misstänkt process"""
    response = requests.post(
        f"{API_URL}/predict",
        json={"NetworkConnections": 1, "ProcessName": "powershell.exe"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["prediction"] == 1
    assert data["threat_type"] == "Attack"