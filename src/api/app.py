"""app.py - Huvud-API för modellprediktioner"""
from fastapi import FastAPI, HTTPException
import joblib
import os
from .models import PredictionRequest, PredictionResponse, HealthResponse
from .utils import find_latest_model, prepare_features, get_threat_type

app = FastAPI(title="Endpoint Security ML API")

model = None
model_version = None

@app.on_event("startup")
async def load_model():
    """Laddar senaste modellen vid startup"""
    global model, model_version
    model_path = find_latest_model()
    
    if model_path:
        try:
            model = joblib.load(model_path)
            model_version = os.path.basename(model_path).replace("endpoint_model_", "").replace(".pkl", "")
            print(f"✅ Modell laddad: {model_path}")
        except Exception as e:
            print(f"❌ Kunde inte ladda modell: {e}")
    else:
        print("❌ Ingen modell hittad!")

@app.get("/health", response_model=HealthResponse)
async def health_check():
    return HealthResponse(
        status="ok",
        model_loaded=model is not None,
        model_version=model_version
    )

@app.post("/predict", response_model=PredictionResponse)
async def predict(request: PredictionRequest):
    if model is None:
        raise HTTPException(status_code=503, detail="Ingen modell laddad")
    
    features = prepare_features(request.NetworkConnections, request.ProcessName)
    pred = int(model.predict(features)[0])
    conf = float(model.predict_proba(features).max())
    
    return PredictionResponse(
        prediction=pred,
        confidence=conf,
        threat_type=get_threat_type(pred),
        model_version=model_version
    )

@app.get("/")
async def root():
    return {
        "message": "Endpoint Security ML API",
        "docs": "/docs",
        "health": "/health",
        "predict": "/predict (POST)"
    }
