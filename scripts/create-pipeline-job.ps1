# scripts/create-pipeline-job.ps1
# Creates or updates the codealpha-distributed-job Pipeline in Jenkins using Jenkinsfile

param (
    [string]$JobName = "codealpha-distributed-job",
    [string]$ControllerUrl = "http://localhost:8080",
    [string]$EnvFile = "$PSScriptRoot\..\.env",
    [string]$JenkinsfilePath = "$PSScriptRoot\..\Jenkinsfile"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $EnvFile)) {
    Write-Error "Environment file '$EnvFile' not found."
    exit 1
}

$adminUser = "admin"
$adminPassword = ""

Get-Content $EnvFile | ForEach-Object {
    $line = $_.Trim()
    if ($line -and -not $line.StartsWith("#") -and $line.Contains("=")) {
        $key, $val = $line.Split("=", 2)
        if ($key.Trim() -eq "JENKINS_ADMIN_USER") { $adminUser = $val.Trim() }
        if ($key.Trim() -eq "JENKINS_ADMIN_PASSWORD") { $adminPassword = $val.Trim() }
        if ($key.Trim() -eq "JENKINS_CONTROLLER_URL") { $ControllerUrl = $val.Trim() }
    }
}

if ([string]::IsNullOrWhiteSpace($adminPassword)) {
    Write-Error "JENKINS_ADMIN_PASSWORD is empty in .env"
    exit 1
}

$userPass = $adminUser + ":" + $adminPassword
$cookiesFile = Join-Path $PSScriptRoot "cookies_job.txt"
$xmlConfigPath = Join-Path $PSScriptRoot "temp_job_config.xml"

try {
    # 1. Fetch CSRF crumb
    $crumbJson = curl.exe -s -c $cookiesFile -u $userPass "$ControllerUrl/crumbIssuer/api/json"
    $crumbObj = $crumbJson | ConvertFrom-Json
    $crumbHeader = "$($crumbObj.crumbRequestField): $($crumbObj.crumb)"

    # 2. Prepare Pipeline XML config
    $jenkinsfileContent = Get-Content -Path $JenkinsfilePath -Raw
    $xmlContent = @"
<?xml version='1.1' encoding='UTF-8'?>
<flow-definition plugin="workflow-job">
  <actions/>
  <description>CodeAlpha Distributed Java Build Execution on Remote Inbound Agent</description>
  <keepDependencies>false</keepDependencies>
  <properties/>
  <definition class="org.jenkinsci.plugins.workflow.cps.CpsFlowDefinition" plugin="workflow-cps">
    <script><![CDATA[$jenkinsfileContent]]></script>
    <sandbox>true</sandbox>
  </definition>
  <triggers/>
  <disabled>false</disabled>
</flow-definition>
"@
    [System.IO.File]::WriteAllText($xmlConfigPath, $xmlContent, [System.Text.Encoding]::UTF8)

    # 3. Check if job exists
    $checkHttp = curl.exe -s -o /dev/null -w "%{http_code}" -u $userPass "$ControllerUrl/job/$JobName/api/json"
    if ($checkHttp -eq "200") {
        Write-Host "Updating existing job config for '$JobName'..." -ForegroundColor Cyan
        $res = curl.exe -s -i -b $cookiesFile -u $userPass -H $crumbHeader -H "Content-Type: application/xml" --data-binary "@$xmlConfigPath" -X POST "$ControllerUrl/job/$JobName/config.xml"
    } else {
        Write-Host "Creating new Pipeline job '$JobName'..." -ForegroundColor Cyan
        $res = curl.exe -s -i -b $cookiesFile -u $userPass -H $crumbHeader -H "Content-Type: application/xml" --data-binary "@$xmlConfigPath" -X POST "$ControllerUrl/createItem?name=$JobName"
    }

    Write-Host "[SUCCESS] Pipeline job '$JobName' configured successfully." -ForegroundColor Green
} finally {
    Remove-Item -Path $cookiesFile -Force -ErrorAction SilentlyContinue
    Remove-Item -Path $xmlConfigPath -Force -ErrorAction SilentlyContinue
}
