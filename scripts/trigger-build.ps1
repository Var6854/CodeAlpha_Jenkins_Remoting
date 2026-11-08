# trigger-build.ps1
# Triggers pipeline build on Jenkins Controller and tails console log

param (
    [string]$JobName = "codealpha-distributed-job",
    [string]$JenkinsUrl = "http://localhost:8080",
    [string]$AdminUser = $env:JENKINS_ADMIN_USER,
    [string]$AdminPassword = $env:JENKINS_ADMIN_PASSWORD,
    [string]$EnvFile = "$PSScriptRoot\..\.env"
)

# 1. Load credentials from .env if not set
if ((-not $AdminUser -or -not $AdminPassword) -and (Test-Path $EnvFile)) {
    Get-Content $EnvFile | ForEach-Object {
        $line = $_.Trim()
        if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
            $key, $val = $line.Split("=", 2)
            if ($key.Trim() -eq "JENKINS_ADMIN_USER" -and -not $AdminUser) {
                $AdminUser = $val.Trim()
            }
            if ($key.Trim() -eq "JENKINS_ADMIN_PASSWORD" -and -not $AdminPassword) {
                $AdminPassword = $val.Trim()
            }
            if ($key.Trim() -eq "JENKINS_CONTROLLER_URL" -and -not $JenkinsUrl) {
                $JenkinsUrl = $val.Trim()
            }
        }
    }
}

if (-not $AdminUser) { $AdminUser = "admin" }
if (-not $AdminPassword) {
    Write-Host "Please enter the password for Jenkins user '$AdminUser':" -ForegroundColor Yellow
    $AdminPassword = Read-Host -Prompt "Password" -AsSecureString | ForEach-Object {
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($_))
    }
}

$userPass = "${AdminUser}:${AdminPassword}"
$authHeader = "Basic " + [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($userPass))

# 2. Check if job exists, create if missing
$checkJob = curl.exe -s -o /dev/null -w "%{http_code}" -u $userPass "$JenkinsUrl/job/$JobName/api/json"
if ($checkJob -ne "200") {
    Write-Host "Job '$JobName' not found on controller. Configuring automatically..." -ForegroundColor Yellow
    & "$PSScriptRoot\create-pipeline-job.ps1" -JobName $JobName -ControllerUrl $JenkinsUrl -EnvFile $EnvFile
}

Write-Host "Triggering build for job [$JobName] on $JenkinsUrl as user [$AdminUser]..." -ForegroundColor Cyan

# 3. Fetch CSRF Crumb
$crumbObj = curl.exe -s -c cookies.txt -u $userPass "$JenkinsUrl/crumbIssuer/api/json" | ConvertFrom-Json
$crumbField = $crumbObj.crumbRequestField
$crumb = $crumbObj.crumb

# Get previous build number
$prevBuildNum = 0
try {
    $info = (Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/api/json" -Headers @{Authorization=$authHeader})
    if ($info.lastBuild) { $prevBuildNum = $info.lastBuild.number }
} catch {}

# 4. Trigger build
curl.exe -s -b cookies.txt -u $userPass -H "${crumbField}: ${crumb}" -X POST "$JenkinsUrl/job/$JobName/build"
Remove-Item -Path cookies.txt -Force -ErrorAction SilentlyContinue

Write-Host "Build request submitted. Waiting for executor to pick up build..." -ForegroundColor Yellow

$buildNum = 0
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    try {
        $info = (Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/api/json" -Headers @{Authorization=$authHeader})
        if ($info.lastBuild -and $info.lastBuild.number -gt $prevBuildNum) {
            $buildNum = $info.lastBuild.number
            break
        }
    } catch {}
}

if ($buildNum -eq 0) {
    Write-Host "Timed out waiting for new build to start." -ForegroundColor Red
    exit 1
}

Write-Host "Current Build: #$buildNum" -ForegroundColor Green
Write-Host "Streaming build execution log from remote agent:`n" -ForegroundColor Cyan

# Poll until complete
$isBuilding = $true
while ($isBuilding) {
    Start-Sleep -Seconds 3
    try {
        $bInfo = (Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/$buildNum/api/json" -Headers @{Authorization=$authHeader})
        $isBuilding = $bInfo.building
    } catch {
        $isBuilding = $false
    }
}

curl.exe -s -u $userPass "$JenkinsUrl/job/$JobName/$buildNum/consoleText"

$finalInfo = (Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/$buildNum/api/json" -Headers @{Authorization=$authHeader})
$resultColor = if ($finalInfo.result -eq "SUCCESS") { "Green" } else { "Red" }
Write-Host "`nBuild #$buildNum Status: $($finalInfo.result)" -ForegroundColor $resultColor
