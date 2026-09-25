<#
.SYNOPSIS
    Wayne Enterprises Endpoint Diagnostic Launcher

.DESCRIPTION
    Runs the Windows endpoint diagnostic, generates the
    corresponding HTML command-center report, and optionally
    opens the report in the default browser.

.EXAMPLE
    .\Invoke-Wayne.ps1

.EXAMPLE
    .\Invoke-Wayne.ps1 -OpenReport
#>

param(
    [switch]$OpenReport
)

$ErrorActionPreference = "Stop"

$projectRoot = $PSScriptRoot

$diagnosticScript = Join-Path `
    $projectRoot `
    "src\Invoke-WayneDiagnostic.ps1"

$htmlScript = Join-Path `
    $projectRoot `
    "src\New-WayneHtmlReport.ps1"

$reportDirectory = Join-Path `
    $projectRoot `
    "reports"

Write-Host ""
Write-Host "====================================================="
Write-Host "            WAYNE ENTERPRISES SYSTEM"
Write-Host "====================================================="
Write-Host ""
Write-Host "Launching endpoint diagnostic..."
Write-Host ""

# ====================================================
# VALIDATE PROJECT FILES
# ====================================================

if (-not (Test-Path $diagnosticScript)) {

    Write-Host `
        "Diagnostic engine could not be found." `
        -ForegroundColor Red

    exit 1
}

if (-not (Test-Path $htmlScript)) {

    Write-Host `
        "HTML report generator could not be found." `
        -ForegroundColor Red

    exit 1
}

# ====================================================
# RECORD START TIME
# ====================================================

$runStartTime = Get-Date

# ====================================================
# RUN DIAGNOSTIC ENGINE
# ====================================================

try {

    & $diagnosticScript
}
catch {

    Write-Host ""
    Write-Host `
        "Diagnostic execution failed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message
    Write-Host ""

    exit 1
}

# ====================================================
# FIND REPORT CREATED BY THIS RUN
# ====================================================

$latestJson = Get-ChildItem `
    -Path $reportDirectory `
    -Filter "*.json" `
    -ErrorAction SilentlyContinue |
    Where-Object {
        $_.LastWriteTime -ge $runStartTime
    } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 1

if (-not $latestJson) {

    Write-Host ""
    Write-Host `
        "No new JSON report was detected." `
        -ForegroundColor Red

    Write-Host ""

    exit 1
}

# ====================================================
# GENERATE HTML REPORT
# ====================================================

try {

    & $htmlScript `
        -ReportPath $latestJson.FullName
}
catch {

    Write-Host ""
    Write-Host `
        "HTML report generation failed." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message
    Write-Host ""

    exit 1
}

# ====================================================
# FIND HTML REPORT
# ====================================================

$htmlReportPath = Join-Path `
    $reportDirectory `
    ($latestJson.BaseName + ".html")

# ====================================================
# FINAL SUMMARY
# ====================================================

Write-Host ""
Write-Host "WAYNE ENTERPRISES SCAN COMPLETE"
Write-Host "-----------------------------------------------------"

Write-Host "JSON : " -NoNewline

Write-Host `
    $latestJson.FullName `
    -ForegroundColor Cyan

Write-Host "HTML : " -NoNewline

Write-Host `
    $htmlReportPath `
    -ForegroundColor Green

# ====================================================
# OPTIONAL BROWSER LAUNCH
# ====================================================

if (
    $OpenReport -and
    (Test-Path $htmlReportPath)
) {

    Write-Host ""
    Write-Host "Opening command center..."

    Start-Process $htmlReportPath
}

Write-Host ""
Write-Host "====================================================="
Write-Host ""