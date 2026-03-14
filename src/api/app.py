"""
app.py - Huvud-API med Prometheus metrics och A/B-test
"""
from fastapi import FastAPI, HTTPException, Request
from fastapi.responses import Response
import joblib
import os
import time
import psutil
from prometheus_client import Counter, Histogram, Gauge, generate_latest, REGISTRY
from .models import PredictionRequest, PredictionResponse, HealthResponse
from .utils import find_latest_model, prepare_features, get_threat_type

# Prometheus metrics
REQUEST_COUNT = Counter('http_requests_total', 'Totala antalet anrop', ['method', 'endpoint', 'status'])
REQUEST_LATENCY = Histogram('http_request_duration_seconds', 'Svarstider i sekunder', ['method', 'endpoint'])
PREDICTION_COUNT = Counter('predictions_total', 'Antal prediktioner', ['threat_type'])
MODEL_INFO = Counter('model_info', 'Information om modellen', ['version'])
ERROR_COUNT = Counter('http_errors_total', 'Antal felanrop', ['method', 'endpoint'])
CPU_USAGE = Gauge('app_cpu_seconds_total', 'Appens CPU-användning')
MEMORY_USAGE = Gauge('app_memory_bytes', 'Appens minnesanvändning')
PREDICTION_CONFIDENCE = Histogram('prediction_confidence', 'Modellens confidence-värden', 
                                   buckets=(0.5, 0.6, 0.7, 0.8, 0.9, 0.95, 0.99, 1.0))

app = FastAPI(title="Endpoint Security ML API")

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
    if response.status_code >= 400:
        ERROR_COUNT.labels(method=method, endpoint=endpoint).inc()
    return response

@app.on_event("startup")
async def load_model():
    global model, model_version
    model_path = find_latest_model()
    if model_path:
        try:
            model = joblib.load(model_path)
            model_version = os.path.basename(model_path).replace("endpoint_model_", "").replace(".pkl", "")
            print(f"✅ Modell laddad: {model_path}")
            if model_version:
                MODEL_INFO.labels(version=model_version).inc()
        except Exception as e:
            print(f"❌ Kunde inte ladda modell: {e}")
    else:
        print("❌ Ingen modell hittad!")

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
    PREDICTION_CONFIDENCE.observe(conf)
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
    CPU_USAGE.set(time.process_time())
    MEMORY_USAGE.set(psutil.Process().memory_info().rss)
    return Response(content=generate_latest(REGISTRY), media_type="text/plain")

@app.get("/")
async def root():
    return {"message": "Endpoint Security ML API", "docs": "/docs", "health": "/health", 
            "metrics": "/metrics", "predict": "/predict (POST)"}
# A/B-test endpoints
@app.get("/version")
async def get_version():
    import os
    version = os.environ.get('MODEL_VERSION', 'unknown')
    return {"version": version, "pod": os.environ.get('HOSTNAME', 'unknown')}
