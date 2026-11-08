# start-windows-agent.ps1
# Connects a separate Windows Inbound Agent process to the Jenkins Controller

param (
    [string]$ControllerUrl = "http://localhost:8080/",
    [string]$AgentName = "windows-agent",
    [string]$Secret = $env:JENKINS_AGENT_SECRET_WINDOWS,
    [string]$WorkDir = "C:\jenkins-agent-workspace",
    [string]$EnvFile = "$PSScriptRoot\..\.env"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Windows Inbound Agent ($AgentName)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load from .env if secret not explicitly provided
if (-not $Secret -and (Test-Path $EnvFile)) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $key, $val = $line.Split("=", 2)
            if ($key.Trim() -eq "JENKINS_AGENT_SECRET_WINDOWS") {
                $Secret = $val.Trim()
            }
        }
    }
}

if (-not $Secret) {
    Write-Host "ERROR: Inbound Agent Secret is required but was not provided." -ForegroundColor Red
    Write-Host "Provide via -Secret parameter, export JENKINS_AGENT_SECRET_WINDOWS, or define in '.env'." -ForegroundColor Yellow
    Write-Host "To find your agent secret:" -ForegroundColor Gray
    Write-Host "1. Navigate to: http://localhost:8080/computer/$AgentName/" -ForegroundColor Gray
    Write-Host "2. Copy the secret shown on the node page." -ForegroundColor Gray
    exit 1
}

# 2. Create dedicated workspace
Write-Host "[1/4] Ensuring isolated workspace directory: $WorkDir" -ForegroundColor Yellow
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
}

# 3. Configure Java 21 environment
Write-Host "[2/4] Setting up Java JDK 21 environment..." -ForegroundColor Yellow
if (-not $env:JAVA_HOME) {
    $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot"
}
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

# 4. Fetch agent.jar from Controller if missing
if (-not (Test-Path "agent.jar")) {
    Write-Host "[3/4] Fetching agent.jar from $ControllerUrl/jnlpJars/agent.jar ..." -ForegroundColor Yellow
    curl.exe -s -o agent.jar "$ControllerUrl/jnlpJars/agent.jar"
} else {
    Write-Host "[3/4] agent.jar already present." -ForegroundColor Green
}

# 5. Launch agent using Jenkins Remoting
Write-Host "[4/4] Connecting inbound agent via WebSocket..." -ForegroundColor Yellow
Write-Host "Command: java -jar agent.jar -url $ControllerUrl -secret [REDACTED] -name $AgentName -workDir $WorkDir -webSocket" -ForegroundColor DarkGray

java -jar agent.jar `
  -url $ControllerUrl `
  -secret $Secret `
  -name $AgentName `
  -workDir $WorkDir `
  -webSocket
