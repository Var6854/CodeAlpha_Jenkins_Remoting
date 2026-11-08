# start-controller.ps1
# Automates building and starting the Jenkins Controller container

param (
    [string]$EnvFile = "$PSScriptRoot\..\.env"
)

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Starting Jenkins Controller (CodeAlpha Distributed Build)" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Load local environment variables from .env if present
if (Test-Path $EnvFile) {
    Write-Host "[0/3] Loading environment variables from .env..." -ForegroundColor Gray
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $key, $val = $line.Split("=", 2)
            [System.Environment]::SetEnvironmentVariable($key.Trim(), $val.Trim(), "Process")
        }
    }
}

if (-not $env:JENKINS_ADMIN_PASSWORD) {
    Write-Host "WARNING: 'JENKINS_ADMIN_PASSWORD' is not set." -ForegroundColor Yellow
    Write-Host "Please create a '.env' file from '.env.example' and configure a secure password." -ForegroundColor Yellow
    $env:JENKINS_ADMIN_PASSWORD = Read-Host -Prompt "Enter Jenkins Admin Password" -AsSecureString | ForEach-Object {
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))
    }
}

if (-not $env:JENKINS_ADMIN_USER) {
    $env:JENKINS_ADMIN_USER = "admin"
}

# 2. Ensure Docker network exists
docker network create jenkins-net 2>$null

# 3. Build custom controller image with plugins & CasC
Write-Host "[1/3] Building Jenkins Controller image..." -ForegroundColor Yellow
docker build -t codealpha-jenkins-controller -f Dockerfile.controller .

# 4. Remove any existing container
docker rm -f jenkins-controller 2>$null

# 5. Start controller container with secure environment variables
Write-Host "[2/3] Launching container on ports 8080 (UI/HTTP) and 50000 (JNLP)..." -ForegroundColor Yellow
docker run -d `
  --name jenkins-controller `
  --network jenkins-net `
  -e "JENKINS_ADMIN_USER=$env:JENKINS_ADMIN_USER" `
  -e "JENKINS_ADMIN_PASSWORD=$env:JENKINS_ADMIN_PASSWORD" `
  -p 8080:8080 `
  -p 50000:50000 `
  codealpha-jenkins-controller

Write-Host "[3/3] Waiting for Jenkins to start..." -ForegroundColor Yellow
$started = $false
for ($i = 0; $i -lt 35; $i++) {
    Start-Sleep -Seconds 2
    $logs = docker logs jenkins-controller 2>&1
    if ($logs -match "Jenkins is fully up and running") {
        $started = $true
        break
    }
}

if ($started) {
    Write-Host "`nSUCCESS: Jenkins Controller is ONLINE!" -ForegroundColor Green
    Write-Host "----------------------------------------------------------"
    Write-Host "Dashboard URL: http://localhost:8080/" -ForegroundColor White
    Write-Host "Admin User:    $env:JENKINS_ADMIN_USER" -ForegroundColor White
    Write-Host "Password:      [CONFIGURED VIA ENVIRONMENT VARIABLE]" -ForegroundColor White
    Write-Host "----------------------------------------------------------"
    Write-Host "To obtain or rotate agent secret tokens securely:" -ForegroundColor Cyan
    Write-Host "1. Log in to http://localhost:8080/" -ForegroundColor Gray
    Write-Host "2. Navigate to: Manage Jenkins -> Nodes -> [Agent Name]" -ForegroundColor Gray
    Write-Host "3. View the generated secret and add it to your '.env' file." -ForegroundColor Gray
    Write-Host "----------------------------------------------------------"
} else {
    Write-Host "Warning: Jenkins is taking longer than expected to start. Check 'docker logs jenkins-controller'." -ForegroundColor Red
}
