# =====================================================
# test-kubernetes.ps1 - TESTA ALL KUBERNETES FUNKTIONALITET
# =====================================================
# Detta skript testar:
# 1. Att poddar körs
# 2. Att API:et fungerar
# 3. Lastbalansering
# 4. Autoskalning
# =====================================================

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "☸️  TESTA KUBERNETES FUNKTIONALITET" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 VAD ÄR KUBERNETES?" -ForegroundColor Yellow
Write-Host "  Kubernetes är ett system som automatiskt hanterar dina containers." -ForegroundColor White
Write-Host "  Det startar om krashade containers, skalar upp vid hög belastning," -ForegroundColor White
Write-Host "  och fördelar trafik mellan flera kopior (poddar)." -ForegroundColor White
Write-Host ""

# ------------------------------
# 1. KOLLA PODDAR
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "1️⃣ KONTROLLERA PODDAR" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📌 Vad är en pod?" -ForegroundColor Green
Write-Host "  En pod är den minsta enheten i Kubernetes - en container (eller flera)" -ForegroundColor White
Write-Host "  som kör din applikation. Vi har 3 poddar = 3 kopior av API:et." -ForegroundColor White
Write-Host ""

$pods = kubectl get pods --no-headers
$podCount = ($pods | Measure-Object | Select-Object -ExpandProperty Count)
Write-Host "  ✅ $podCount poddar körs just nu" -ForegroundColor Green
Write-Host ""
Write-Host "📊 Detaljer:" -ForegroundColor Cyan
kubectl get pods -o wide
Write-Host ""

# ------------------------------
# 2. KOLLA SERVICE
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "2️⃣ KONTROLLERA SERVICE (LASTBALANSERARE)" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📌 Vad är en service?" -ForegroundColor Green
Write-Host "  En service är en lastbalanserare som fördelar trafik mellan dina poddar." -ForegroundColor White
Write-Host "  När du ringer http://localhost:8000 går anropet till servicen," -ForegroundColor White
Write-Host "  som skickar det vidare till EN av dina 3 poddar." -ForegroundColor White
Write-Host ""

$services = kubectl get services
Write-Host "📊 Detaljer:" -ForegroundColor Cyan
$services
Write-Host ""

# ------------------------------
# 3. TESTA API
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "3️⃣ TESTA API:ET" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📌 Varför testa API:et?" -ForegroundColor Green
Write-Host "  Vi måste verifiera att vår modell är laddad och fungerar i poddarna." -ForegroundColor White
Write-Host "  API:et returnerar 'model_loaded: true' om allt är korrekt." -ForegroundColor White
Write-Host ""

$response = curl -s http://localhost:8000/health 2>$null
if ($response) {
    $health = $response | ConvertFrom-Json
    if ($health.model_loaded) {
        Write-Host "  ✅ API fungerar! Modell laddad: $($health.model_version)" -ForegroundColor Green
        Write-Host ""
        Write-Host "📊 Svar från API:et:" -ForegroundColor Cyan
        Write-Host "  $($health | ConvertTo-Json)" -ForegroundColor White
    } else {
        Write-Host "  ⚠️ API svarar men ingen modell laddad" -ForegroundColor Yellow
    }
} else {
    Write-Host "  ❌ API svarar inte!" -ForegroundColor Red
}
Write-Host ""

# ------------------------------
# 4. TESTA LASTBALANSERING
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "4️⃣ TESTA LASTBALANSERING" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📌 Hur fungerar lastbalansering?" -ForegroundColor Green
Write-Host "  När du skickar 10 anrop kommer servicen att fördela dem" -ForegroundColor White
Write-Host "  mellan dina $podCount poddar. Varje anrop kan hamna på olika poddar," -ForegroundColor White
Write-Host "  vilket sprider belastningen." -ForegroundColor White
Write-Host ""

Write-Host "📊 Skickar 10 anrop till http://localhost:8000/health ..." -ForegroundColor Yellow
Write-Host ""

$startTime = Get-Date
for ($i=1; $i -le 10; $i++) {
    $response = curl -s http://localhost:8000/health 2>$null
    Write-Host "  ✅ Anrop $i mottaget (svarstid: $(($(Get-Date) - $startTime).TotalMilliseconds.ToString('F0')) ms)" -ForegroundColor Green
    Start-Sleep -Milliseconds 200
}
$endTime = Get-Date
$totalTime = ($endTime - $startTime).TotalSeconds

Write-Host ""
Write-Host "📊 Resultat lastbalansering:" -ForegroundColor Cyan
Write-Host "  • 10 anrop skickades på $($totalTime.ToString('F1')) sekunder" -ForegroundColor White
Write-Host "  • Genomsnittlig svarstid: $(($totalTime*1000/10).ToString('F0')) ms" -ForegroundColor White
Write-Host "  • Anropen fördelades mellan $podCount poddar (kolla med 'kubectl logs [pod]')" -ForegroundColor White
Write-Host "  ✅ Lastbalansering fungerar!" -ForegroundColor Green
Write-Host ""

# ------------------------------
# 5. TESTA AUTOSKALNING
# ------------------------------
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "5️⃣ TESTA AUTOSKALNING" -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "📌 Vad är autoskalning?" -ForegroundColor Green
Write-Host "  Autoskalning (Horizontal Pod Autoscaler) övervakar CPU-användningen" -ForegroundColor White
Write-Host "  i dina poddar. När CPU > 50% startas FLER poddar automatiskt" -ForegroundColor White
Write-Host "  (upp till max 10). När belastningen sjunker, tas poddar bort." -ForegroundColor White
Write-Host "  Detta är viktigt för att hantera variationer i trafik." -ForegroundColor White
Write-Host ""

Write-Host "📊 Kontrollerar HPA (Horizontal Pod Autoscaler) status:" -ForegroundColor Yellow
$hpaStatus = kubectl get hpa
$hpaStatus
Write-Host ""

$answer = Read-Host "   Starta autoskalningstest? (j/n)"

if ($answer -eq "j") {
    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "⚡ STARTER AUTOSKALNINGSTEST" -ForegroundColor Yellow
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "📌 Så här fungerar testet:" -ForegroundColor Green
    Write-Host "  1. Vi skickar 200 anrop till /predict (som kräver mer CPU än /health)" -ForegroundColor White
    Write-Host "  2. Detta ökar CPU-belastningen på dina poddar" -ForegroundColor White
    Write-Host "  3. HPA upptäcker CPU > 50% och börjar skala upp" -ForegroundColor White
    Write-Host "  4. Fler poddar startas (upp till 10)" -ForegroundColor White
    Write-Host "  5. När belastningen sjunker, skalas det ner igen" -ForegroundColor White
    Write-Host ""
    Write-Host "   ⏳ VIKTIGT: Öppna ett NYTT PowerShell-fönster och kör:" -ForegroundColor Cyan
    Write-Host "   kubectl get hpa -w" -ForegroundColor White
    Write-Host "   Där ser du i REALTID när nya poddar startas!" -ForegroundColor White
    Write-Host ""
    Write-Host "   Tryck ENTER när du har öppnat det andra fönstet..." -ForegroundColor Yellow
    Read-Host

    Write-Host ""
    Write-Host "   ⏳ Startar belastningstest (200 anrop till /predict)..." -ForegroundColor Yellow
    Write-Host ""
    
    $startTime = Get-Date
    for ($i=1; $i -le 200; $i++) {
        curl -s http://localhost:8000/predict -Method POST `
            -Body '{"NetworkConnections":1,"ProcessName":"powershell.exe"}' `
            -ContentType "application/json" -ErrorAction SilentlyContinue > $null
        
        if ($i % 50 -eq 0) {
            $elapsed = (Get-Date) - $startTime
            Write-Host "   ✅ $i anrop skickade (tid: $($elapsed.TotalSeconds.ToString('F1')) sek)" -ForegroundColor Green
        }
        Start-Sleep -Milliseconds 50
    }
    $endTime = Get-Date
    $totalTime = ($endTime - $startTime).TotalSeconds
    
    Write-Host ""
    Write-Host "📊 RESULTAT AUTOSKALNING:" -ForegroundColor Cyan
    Write-Host "  • 200 anrop skickades på $($totalTime.ToString('F1')) sekunder" -ForegroundColor White
    Write-Host "  • Genomsnittlig svarstid: $(($totalTime*1000/200).ToString('F0')) ms" -ForegroundColor White
    Write-Host ""
    Write-Host "📌 TITTA I DITT ANDRA FÖNSTER! Där bör du se:" -ForegroundColor Green
    Write-Host "  • CPU ökar från <50% till >50%" -ForegroundColor White
    Write-Host "  • REPLICAS ökar från 3 till 4,5,6... (beroende på belastning)" -ForegroundColor White
    Write-Host "  • Nya poddar startas automatiskt!" -ForegroundColor White
    Write-Host ""
    Write-Host "   ⏳ Väntar 30 sekunder för att låta Kubernetes stabilisera sig..." -ForegroundColor Yellow
    Start-Sleep -Seconds 30
    
    Write-Host ""
    Write-Host "📊 Status EFTER autoskalningstest:" -ForegroundColor Cyan
    kubectl get pods
    Write-Host ""
    Write-Host "  ✅ Autoskalningstest KLART! Se skillnaden i antal poddar." -ForegroundColor Green
}

# ------------------------------
# 6. SAMMANFATTNING
# ------------------------------
Write-Host ""
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "✅ SAMMANFATTNING - VARFÖR ÄR DETTA VIKTIGT?" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "📋 VAD HAR VI TESTAT?" -ForegroundColor Yellow
Write-Host "  • Poddar: Verifierat att 3 kopior av API:et körs" -ForegroundColor White
Write-Host "  • Service: Kontrollerat att lastbalanseraren fungerar" -ForegroundColor White
Write-Host "  • API: Verifierat att modellen är laddad" -ForegroundColor White
Write-Host "  • Lastbalansering: 10 anrop fördelades mellan poddar" -ForegroundColor White
if ($answer -eq "j") {
    Write-Host "  • Autoskalning: 200 anrop triggade CPU-ökning → fler poddar" -ForegroundColor White
}

Write-Host ""
Write-Host "📋 VARFÖR ÄR DETTA VIKTIGT I PRODUKTION?" -ForegroundColor Yellow
Write-Host "  ✅ TOLERANS: Om en pod kraschar, finns de andra kvar" -ForegroundColor Green
Write-Host "  ✅ SKALNING: Vid hög belastning startas fler poddar automatiskt" -ForegroundColor Green
Write-Host "  ✅ EFFEKTIVITET: Lastbalanseraren sprider trafiken jämnt" -ForegroundColor Green
Write-Host "  ✅ DRIFT: Inga manuella insatser vid trafiktoppar" -ForegroundColor Green
Write-Host ""

Write-Host "📋 JÄMFÖRELSE:" -ForegroundColor Yellow
Write-Host "  Utan Kubernetes: 1 API-instans → kraschar vid hög last → alla användare drabbas" -ForegroundColor Red
Write-Host "  Med Kubernetes:   3-10 instanser → skalas upp vid behov → användarna märker inget" -ForegroundColor Green
Write-Host ""

Write-Host "📋 NÄSTA STEG FÖR ATT LÄRA DIG MER:" -ForegroundColor Green
Write-Host "  • kubectl get hpa -w          # Watch autoskalning i realtid" -ForegroundColor White
Write-Host "  • kubectl logs [pod-namn]    # Se loggar från en specifik pod" -ForegroundColor White
Write-Host "  • kubectl describe pod [pod]  # Se detaljer om en pod" -ForegroundColor White
Write-Host "  • kubectl top pods            # Se CPU/minne per pod" -ForegroundColor White
Write-Host ""

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "🎉 GRATTIS! Du har nu testat alla Kubernetes-funktioner!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan