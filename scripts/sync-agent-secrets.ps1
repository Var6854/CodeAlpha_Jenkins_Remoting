# scripts/sync-agent-secrets.ps1
# Retrieves rotated agent secrets from the running Jenkins controller and safely updates local .env

$ErrorActionPreference = "Stop"

if (-not (Test-Path ".env")) {
    Write-Error ".env file not found."
    exit 1
}

$envLines = Get-Content ".env"
$adminUser = "admin"
$adminPassword = ""
$controllerUrl = "http://localhost:8080"

foreach ($line in $envLines) {
    if ($line -match '^\s*JENKINS_ADMIN_USER=(.+)$') {
        $adminUser = $matches[1].Trim()
    }
    if ($line -match '^\s*JENKINS_ADMIN_PASSWORD=(.+)$') {
        $adminPassword = $matches[1].Trim()
    }
    if ($line -match '^\s*JENKINS_CONTROLLER_URL=(.+)$') {
        $controllerUrl = $matches[1].Trim()
    }
}

if ([string]::IsNullOrWhiteSpace($adminPassword)) {
    Write-Error "JENKINS_ADMIN_PASSWORD is empty in .env"
    exit 1
}

$auth = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes("${adminUser}:${adminPassword}"))
$headers = @{
    "Authorization" = "Basic $auth"
}

$userPass = "${adminUser}:${adminPassword}"

# Fetch CSRF crumb using curl
$crumbJson = curl.exe -s -c cookies.txt -u $userPass "$controllerUrl/crumbIssuer/api/json"
$crumbObj = $crumbJson | ConvertFrom-Json
$crumbField = $crumbObj.crumbRequestField
$crumb = $crumbObj.crumb

$scriptPath = Join-Path $PSScriptRoot "get-secrets.groovy"
$response = curl.exe -s -b cookies.txt -u $userPass -H "${crumbField}: ${crumb}" --data-urlencode "script@$scriptPath" -X POST "$controllerUrl/scriptText"
Remove-Item -Path "cookies.txt" -Force -ErrorAction SilentlyContinue

$responseText = ($response | Out-String)

$linuxSecret = ""
$winSecret = ""

if ($responseText -match 'AGENT_NODE:remote-linux-agent=([a-f0-9]+)') {
    $linuxSecret = $matches[1]
}
if ($responseText -match 'AGENT_NODE:windows-agent=([a-f0-9]+)') {
    $winSecret = $matches[1]
}

if ([string]::IsNullOrEmpty($linuxSecret) -or [string]::IsNullOrEmpty($winSecret)) {
    Write-Error "Failed to retrieve one or more agent secrets from Jenkins controller. Raw output: $responseText"
    exit 1
}

# Update .env safely without printing secrets
$newEnv = @()
$foundLinux = $false
$foundWin = $false

foreach ($line in $envLines) {
    if ($line -match '^\s*JENKINS_AGENT_SECRET_LINUX=') {
        $newEnv += "JENKINS_AGENT_SECRET_LINUX=$linuxSecret"
        $foundLinux = $true
    } elseif ($line -match '^\s*JENKINS_AGENT_SECRET_WINDOWS=') {
        $newEnv += "JENKINS_AGENT_SECRET_WINDOWS=$winSecret"
        $foundWin = $true
    } else {
        $newEnv += $line
    }
}

if (-not $foundLinux) {
    $newEnv += "JENKINS_AGENT_SECRET_LINUX=$linuxSecret"
}
if (-not $foundWin) {
    $newEnv += "JENKINS_AGENT_SECRET_WINDOWS=$winSecret"
}

Set-Content -Path ".env" -Value $newEnv -Encoding utf8
Write-Host "[SUCCESS] Agent secrets successfully retrieved and synced to local .env (untracked)."
