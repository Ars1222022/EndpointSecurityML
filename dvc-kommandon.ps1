Write-Host "==================================" -ForegroundColor Cyan
Write-Host "DVC - ENKLA KOMMANDON" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host "1. Exportera data från SQL"
Write-Host "2. Lägg till CSV-fil i DVC"
Write-Host "3. Visa status"
Write-Host "4. Avsluta"
$val = Read-Host "Välj (1-4)"

if ($val -eq "1") { python src/data_generation/export_to_csv.py }
if ($val -eq "2") { 
    $files = Get-ChildItem data/raw/*.csv
    for ($i=0; $i -lt $files.Count; $i++) { Write-Host "$($i+1). $($files[$i].Name)" }
    $num = Read-Host "Välj filnummer"
    dvc add $files[$num-1].FullName
    git add "$($files[$num-1].FullName).dvc"
    git commit -m "Lägg till data $($files[$num-1].Name)"
}
if ($val -eq "3") { dvc status }
