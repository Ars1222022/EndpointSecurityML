# run-training.ps1
Write-Host "Kör ML-träning..." -ForegroundColor Cyan
python src/training/train_from_sql.py
