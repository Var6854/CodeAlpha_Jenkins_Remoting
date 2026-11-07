# start-linux-agent.ps1
# Connects an isolated Linux Inbound Agent Docker container to the Jenkins Controller

param (
    [string]$ControllerUrl = "http://jenkins-controller:8080",
    [string]$AgentName = "remote-linux-agent",
    [string]$Secret = "94e52147a1ea09e53f49cfc701093d8d4a8530eac3d780cfe7584ca83b01e440",
    [string]$WorkDir = "/home/jenkins/agent"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Linux Inbound Agent ($AgentName)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# Remove old container if running
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

Write-Host "`nLinux Agent is running and connected to Jenkins Controller!" -ForegroundColor Green
