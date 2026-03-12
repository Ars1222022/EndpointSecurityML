"""models.py - Pydantic-modeller för API:et"""
from pydantic import BaseModel
from typing import Optional

class PredictionRequest(BaseModel):
    NetworkConnections: int
    ProcessName: str

class PredictionResponse(BaseModel):
    prediction: int
    confidence: float
    threat_type: str
    model_version: str

class HealthResponse(BaseModel):
    status: str
    model_loaded: bool
    model_version: Optional[str] = None
