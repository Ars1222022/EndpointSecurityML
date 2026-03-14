# Docker för EndpointSecurityML

## Grundläggande kommandon

| Kommando | Funktion |
|----------|----------|
| `docker-compose up -d` | Starta alla tjänster i bakgrunden |
| `docker-compose down` | Stoppa alla tjänster |
| `docker-compose logs -f` | Följ loggar från alla tjänster |
| `docker-compose build` | Bygg om alla images |
| `docker ps` | Lista körande containers |

## Tjänster och portar

| Tjänst | Port | URL |
|--------|------|-----|
| API | 8000 | http://localhost:8000/docs |
| MLflow | 5000 | http://localhost:5000 |
| Grafana | 3000 | http://localhost:3000 |
| Airflow | 8080 | http://localhost:8080 |
| Prometheus | 9090 | http://localhost:9090 |

## Felsökning

```powershell
# Se loggar för en specifik tjänst
docker-compose logs api
docker-compose logs mlflow
docker-compose logs airflow-webserver

# Starta om en tjänst
docker-compose restart api