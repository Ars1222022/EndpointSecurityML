-- Kolla ThreatDetections (ML-resultaten)
SELECT TOP 20 * FROM ThreatDetections;

-- Kolla EndpointActivities (rådata)
SELECT ThreatType, COUNT(*) AS Antal 
FROM EndpointActivities 
GROUP BY ThreatType;

-- Jämför attacker (verkligt vs predikterat)
SELECT 
    ea.ActivityID,
    ea.ThreatType AS VerkligtHot,
    td.PredictedThreatType AS PredikteratHot,
    td.ConfidenceScore
FROM EndpointActivities ea
JOIN ThreatDetections td ON ea.ActivityID = td.ActivityID
WHERE ea.IsAttack = 1
ORDER BY td.ConfidenceScore DESC;