"""
app_ci.py - Enklare API för CI-miljö (utan psutil)
"""

from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
import joblib
import os
import time
from prometheus_client import Counter, Histogram, generate_latest, REGISTRY
from .models import PredictionRequest, PredictionResponse, HealthResponse
from .utils import find_latest_model, prepare_features, get_threat_type

# Grundläggande metrics (inga psutil-beroende)
REQUEST_COUNT = Counter('http_requests_total', 'Totala antalet anrop', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Svarstider i sekunder', ['method', 'endpoint'])
PREDICTION_COUNT = Counter('predictions_total', 'Antal prediktioner', ['threat_type'])
MODEL_INFO = Counter('model_info', 'Information om modellen', ['version'])

app = FastAPI(title="Endpoint Security ML API (CI)")

model = None
model_version = None

@app.middleware("http")
async def monitor_requests(request: Request, call_next):
    method = request.method
    endpoint = request.url.path
    start_time = time.time()
    response = await call_next(request)
    duration = time.time() - start_time
    REQUEST_COUNT.labels(method=method, endpoint=endpoint, status=response.status_code).inc()
    REQUEST_LATENCY.labels(method=method, endpoint=endpoint).observe(duration)
    return response

@app.on_event("startup")
async def load_model():
    global model, model_version
    model_path = find_latest_model()
    if model_path:
        model = joblib.load(model_path)
        model_version = os.path.basename(model_path).replace("endpoint_model_", "").replace(".pkl", "")
        print(f"✅ Modell laddad: {model_path}")
        if model_version:
            MODEL_INFO.labels(version=model_version).inc()

@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(status="ok", model_loaded=model is not None, model_version=model_version)

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Ingen modell laddad")
    features = prepare_features(request.NetworkConnections, request.ProcessName)
    pred = int(model.predict(features)[0])
    conf = float(model.predict_proba(features).max())
    threat = get_threat_type(pred)
    PREDICTION_COUNT.labels(threat_type=threat).inc()
    if model_version:
        MODEL_INFO.labels(version=model_version).inc()
    return PredictionResponse(
        prediction=pred,
        confidence=conf,
        threat_type=threat,
        model_version=model_version if model_version else "unknown"
    )

@app.get("/metrics")
async def get_metrics():
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

@app.get("/")
async def root():
    return {"message": "Endpoint Security ML API (CI version)"}
