# start-windows-agent.ps1
# Connects a separate Windows Inbound Agent process to the Jenkins Controller

param (
    [string]$ControllerUrl = "http://localhost:8080/",
    [string]$AgentName = "windows-agent",
    [string]$Secret = "68593def9818b1b1c3671411167c47f6285b20a549d92c2a606676496f4521a0",
    [string]$WorkDir = "C:\jenkins-agent-workspace"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Windows Inbound Agent ($AgentName)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Create dedicated workspace
Write-Host "[1/4] Ensuring isolated workspace directory: $WorkDir" -ForegroundColor Yellow
if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
}

# 2. Configure Java 21 environment
Write-Host "[2/4] Setting up Java JDK 21 environment..." -ForegroundColor Yellow
if (-not $env:JAVA_HOME) {
    $env:JAVA_HOME = "C:\Program Files\Eclipse Adoptium\jdk-21.0.13.9-hotspot"
}
$env:Path = "$env:JAVA_HOME\bin;" + $env:Path

# 3. Fetch agent.jar from Controller if missing
if (-not (Test-Path "agent.jar")) {
    Write-Host "[3/4] Fetching agent.jar from $ControllerUrl/jnlpJars/agent.jar ..." -ForegroundColor Yellow
    curl.exe -s -o agent.jar "$ControllerUrl/jnlpJars/agent.jar"
} else {
    Write-Host "[3/4] agent.jar already present." -ForegroundColor Green
}

# 4. Launch agent using Jenkins Remoting
Write-Host "[4/4] Connecting inbound agent via WebSocket..." -ForegroundColor Yellow
Write-Host "Command: java -jar agent.jar -url $ControllerUrl -secret [REDACTED] -name $AgentName -workDir $WorkDir -webSocket" -ForegroundColor DarkGray

java -jar agent.jar `
  -url $ControllerUrl `
  -secret $Secret `
  -name $AgentName `
  -workDir $WorkDir `
  -webSocket
