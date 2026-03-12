"""utils.py - utan pandas för att undvika numpy-konflikter"""
import glob
import os
import joblib
import numpy as np

def find_latest_model():
    """Hittar den senast tränade modellen"""
    files = glob.glob("models/production/*.pkl")
    if not files:
        return None
    return max(files, key=os.path.getctime)

def prepare_features(network_connections, process_name):
    """Förbereder features som numpy array (istället för pandas)"""
    suspicious = 1 if process_name.lower() in ['powershell.exe','cmd.exe','wannacry.exe'] else 0
    return np.array([[network_connections, suspicious]], dtype=np.float64)

def get_threat_type(prediction):
    """Konverterar prediction till hottyp"""
    return 'Attack' if prediction == 1 else 'Normal'
