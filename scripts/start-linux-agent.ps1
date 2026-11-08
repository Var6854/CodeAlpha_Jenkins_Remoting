# start-linux-agent.ps1
# Connects an isolated Linux Inbound Agent Docker container to the Jenkins Controller

param (
    [string]$ControllerUrl = "http://jenkins-controller:8080",
    [string]$AgentName = "remote-linux-agent",
    [string]$Secret = $env:JENKINS_AGENT_SECRET_LINUX,
    [string]$WorkDir = "/home/jenkins/agent",
    [string]$EnvFile = "$PSScriptRoot\..\.env"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Linux Inbound Agent ($AgentName)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load from .env if secret not explicitly provided
if (-not $Secret -and (Test-Path $EnvFile)) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $key, $val = $line.Split("=", 2)
            if ($key.Trim() -eq "JENKINS_AGENT_SECRET_LINUX") {
                $Secret = $val.Trim()
            }
        }
    }
}

if (-not $Secret) {
    Write-Host "ERROR: Inbound Agent Secret is required but was not provided." -ForegroundColor Red
    Write-Host "Provide via -Secret parameter, export JENKINS_AGENT_SECRET_LINUX, or define in '.env'." -ForegroundColor Yellow
    Write-Host "To find your agent secret:" -ForegroundColor Gray
    Write-Host "1. Navigate to: http://localhost:8080/computer/$AgentName/" -ForegroundColor Gray
    Write-Host "2. Copy the secret shown on the node page." -ForegroundColor Gray
    exit 1
}

# 2. Remove old container if running
docker rm -f jenkins-linux-agent 2>$null

$currentDir = (Get-Location).Path

Write-Host "[1/2] Launching container with volume mount for source repo..." -ForegroundColor Yellow
docker run -d `
  --name jenkins-linux-agent `
  --network jenkins-net `
  -v "${currentDir}:/repo:ro" `
  jenkins/inbound-agent:latest-jdk21 `
  -url $ControllerUrl `
  -secret $Secret `
  -name $AgentName `
  -workDir $WorkDir

Write-Host "[2/2] Verifying connection status..." -ForegroundColor Yellow
Start-Sleep -Seconds 4
docker logs jenkins-linux-agent | Select-String -Pattern "Connected|INFO: Trying protocol"

if (Test-Path "$env:USERPROFILE\.gradle\wrapper") {
    docker cp "$env:USERPROFILE\.gradle\wrapper" jenkins-linux-agent:/home/jenkins/.gradle/wrapper 2>$null
    if (Test-Path "$env:USERPROFILE\.gradle\caches") {
        docker cp "$env:USERPROFILE\.gradle\caches" jenkins-linux-agent:/home/jenkins/.gradle/caches 2>$null
    }
    docker exec -u 0 jenkins-linux-agent chown -R jenkins:jenkins /home/jenkins/.gradle 2>$null
}

Write-Host "`nLinux Agent is running and connected to Jenkins Controller!" -ForegroundColor Green
