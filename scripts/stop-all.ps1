# stop-all.ps1
# Cleanly terminates running agents and controller

Write-Host "Stopping Jenkins distributed build infrastructure..." -ForegroundColor Yellow

# 1. Stop background Windows agent processes
Get-Process -Name "java" -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*agent.jar*" } | Stop-Process -Force -ErrorAction SilentlyContinue

# 2. Stop Docker containers
docker rm -f jenkins-linux-agent 2>$null
docker rm -f jenkins-controller 2>$null

Write-Host "All Jenkins controller and agent processes stopped." -ForegroundColor Green
