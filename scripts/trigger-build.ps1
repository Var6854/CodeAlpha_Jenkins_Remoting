# trigger-build.ps1
# Triggers pipeline build on Jenkins Controller and tails console log

param (
    [string]$JobName = "codealpha-distributed-job",
    [string]$JenkinsUrl = "http://localhost:8080"
)

Write-Host "Triggering build for job [$JobName] on $JenkinsUrl..." -ForegroundColor Cyan

# Fetch CSRF Crumb
$crumbObj = curl.exe -s -c cookies.txt -u admin:admin123 "$JenkinsUrl/crumbIssuer/api/json" | ConvertFrom-Json
$crumbField = $crumbObj.crumbRequestField
$crumb = $crumbObj.crumb

# Trigger build
curl.exe -s -b cookies.txt -u admin:admin123 -H "${crumbField}: ${crumb}" -X POST "$JenkinsUrl/job/$JobName/build"
Remove-Item -Path cookies.txt -Force -ErrorAction SilentlyContinue

Write-Host "Build queued. Fetching build number and streaming console output..." -ForegroundColor Yellow
Start-Sleep -Seconds 4

$jobInfo = (Invoke-RestMethod -Uri "$JenkinsUrl/job/$JobName/api/json" -Headers @{Authorization="Basic YWRtaW46YWRtaW4xMjM="})
$buildNum = $jobInfo.lastBuild.number
Write-Host "Current Build: #$buildNum" -ForegroundColor Green

Start-Sleep -Seconds 6
curl.exe -s -u admin:admin123 "$JenkinsUrl/job/$JobName/$buildNum/consoleText"
