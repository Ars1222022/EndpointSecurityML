FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y gcc curl && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir numpy==1.24.3
RUN pip install --no-cache-dir pandas==2.0.3
RUN pip install --no-cache-dir scikit-learn==1.3.0 joblib==1.3.2 pyodbc==5.0.0
RUN pip install --no-cache-dir fastapi==0.104.1 uvicorn[standard]==0.24.0 pydantic==2.5.0
RUN pip install --no-cache-dir mlflow

COPY . .

RUN mkdir -p /app/mlruns /app/models/production /app/data/raw /app/src/api

EXPOSE 5000 8000

CMD sh -c "mlflow ui --host 0.0.0.0 --port 5000 --backend-store-uri /app/mlruns & uvicorn src.api.app:app --host 0.0.0.0 --port 8000"
