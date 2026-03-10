USE EndpointSecurityML;
GO

-- =====================================================
-- Tabell 1: EndpointActivities
-- =====================================================
CREATE TABLE EndpointActivities (
    ActivityID INT IDENTITY(1,1) PRIMARY KEY,
    Timestamp DATETIME DEFAULT GETDATE(),
    ComputerName NVARCHAR(100),
    Username NVARCHAR(100),
    ProcessName NVARCHAR(255),
    ProcessID INT,
    ParentProcess NVARCHAR(255),
    NetworkConnections BIT DEFAULT 0,
    IsAttack BIT DEFAULT 0,
    ThreatType NVARCHAR(50)
);
GO

-- =====================================================
-- Tabell 2: ThreatDetections
-- =====================================================
CREATE TABLE ThreatDetections (
    DetectionID INT IDENTITY(1,1) PRIMARY KEY,
    ActivityID INT FOREIGN KEY REFERENCES EndpointActivities(ActivityID),
    Timestamp DATETIME DEFAULT GETDATE(),
    PredictedThreatType NVARCHAR(50),
    ConfidenceScore FLOAT,
    ModelVersion NVARCHAR(20),
    WasCorrect BIT NULL
);
GO

-- =====================================================
-- Fyll med normal aktivitet (2000 rader)
-- =====================================================
INSERT INTO EndpointActivities (Timestamp, ComputerName, Username, ProcessName, 
                               ProcessID, ParentProcess, NetworkConnections, IsAttack, ThreatType)
SELECT 
    DATEADD(day, -30 + (number % 30), GETDATE()),
    CASE WHEN number % 5 = 0 THEN 'WORKSTATION01'
         WHEN number % 5 = 1 THEN 'WORKSTATION02'
         WHEN number % 5 = 2 THEN 'WORKSTATION03'
         WHEN number % 5 = 3 THEN 'WORKSTATION04'
         ELSE 'WORKSTATION05' END,
    CASE WHEN number % 4 = 0 THEN 'anna.johansson'
         WHEN number % 4 = 1 THEN 'bjorn.svensson'
         WHEN number % 4 = 2 THEN 'carina.karlsson'
         ELSE 'david.lindberg' END,
    CASE WHEN number % 6 = 0 THEN 'chrome.exe'
         WHEN number % 6 = 1 THEN 'winword.exe'
         WHEN number % 6 = 2 THEN 'excel.exe'
         WHEN number % 6 = 3 THEN 'outlook.exe'
         WHEN number % 6 = 4 THEN 'spotify.exe'
         ELSE 'teams.exe' END,
    1000 + number,
    'explorer.exe',
    CASE WHEN number % 3 = 0 THEN 1 ELSE 0 END,
    0,
    'Normal'
FROM (SELECT TOP 2000 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS number FROM sys.objects a CROSS JOIN sys.objects b) numbers;
GO

-- =====================================================
-- Fyll med ransomware (100 rader)
-- =====================================================
INSERT INTO EndpointActivities (Timestamp, ComputerName, Username, ProcessName, 
                               ProcessID, ParentProcess, NetworkConnections, IsAttack, ThreatType)
SELECT 
    DATEADD(day, -5 - (number % 5), GETDATE()),
    'WORKSTATION05',
    'elin.nilsson',
    'wannacry.exe',
    6000 + number,
    'explorer.exe',
    1,
    1,
    'Ransomware'
FROM (SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS number FROM sys.objects) numbers;
GO

-- =====================================================
-- Fyll med malware (100 rader)
-- =====================================================
INSERT INTO EndpointActivities (Timestamp, ComputerName, Username, ProcessName, 
                               ProcessID, ParentProcess, NetworkConnections, IsAttack, ThreatType)
SELECT 
    DATEADD(day, -2 - (number % 2), GETDATE()),
    'WORKSTATION02',
    'bjorn.svensson',
    'mimikatz.exe',
    9000 + number,
    'explorer.exe',
    1,
    1,
    'Malware'
FROM (SELECT TOP 100 ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS number FROM sys.objects) numbers;
GO

-- =====================================================
-- Kontrollera resultatet
-- =====================================================
SELECT ThreatType, COUNT(*) AS Antal 
FROM EndpointActivities 
GROUP BY ThreatType
ORDER BY Antal DESC;
GO