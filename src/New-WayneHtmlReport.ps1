<#
.SYNOPSIS
    Wayne Enterprises HTML Report Generator

.DESCRIPTION
    Reads a JSON report produced by the Wayne Enterprises
    Endpoint Diagnostic and generates a visual HTML dashboard.

.NOTES
    Project: Wayne Enterprises Diagnostic
#>

param(
    [string]$ReportPath
)

# ====================================================
# PATHS
# ====================================================

$projectRoot = Split-Path -Parent $PSScriptRoot

$reportDirectory = Join-Path `
    $projectRoot `
    "reports"

# ====================================================
# SELECT REPORT
# ====================================================

if (-not $ReportPath) {

    $latestReport = Get-ChildItem `
        -Path $reportDirectory `
        -Filter "*.json" `
        -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latestReport) {

        Write-Host ""
        Write-Host "No JSON diagnostic reports were found." `
            -ForegroundColor Red

        Write-Host "Run Invoke-WayneDiagnostic.ps1 first."
        Write-Host ""

        exit 1
    }

    $ReportPath = $latestReport.FullName
}

if (-not (Test-Path $ReportPath)) {

    Write-Host ""
    Write-Host "Report file not found:" `
        -ForegroundColor Red

    Write-Host $ReportPath
    Write-Host ""

    exit 1
}

# ====================================================
# LOAD JSON
# ====================================================

try {

    $report = Get-Content `
        -Path $ReportPath `
        -Raw |
        ConvertFrom-Json
}
catch {

    Write-Host ""
    Write-Host "Failed to read diagnostic report." `
        -ForegroundColor Red

    Write-Host $_.Exception.Message
    Write-Host ""

    exit 1
}

# ====================================================
# HELPER FUNCTIONS
# ====================================================

function Encode-Html {

    param(
        [object]$Value
    )

    if ($null -eq $Value) {

        return "Unavailable"
    }

    return [System.Net.WebUtility]::HtmlEncode(
        $Value.ToString()
    )
}

function Format-State {

    param(
        [object]$Value,
        [string]$TrueText = "Enabled",
        [string]$FalseText = "Disabled"
    )

    if ($null -eq $Value) {

        return "Unavailable"
    }

    if (
        $Value -eq $true -or
        $Value -eq 1 -or
        $Value.ToString() -eq "True"
    ) {

        return $TrueText
    }

    return $FalseText
}

function Get-StateClass {

    param(
        [object]$Value
    )

    if ($null -eq $Value) {

        return "neutral"
    }

    if (
        $Value -eq $true -or
        $Value -eq 1 -or
        $Value.ToString() -eq "True"
    ) {

        return "good"
    }

    return "bad"
}

function Get-SeverityClass {

    param(
        [string]$Severity
    )

    switch ($Severity) {

        "PASS" {
            return "pass"
        }

        "WARN" {
            return "warn"
        }

        "FAIL" {
            return "fail"
        }

        default {
            return "info"
        }
    }
}

# ====================================================
# REPORT VALUES
# ====================================================

$healthScore = $report.Assessment.HealthScore
$healthStatus = $report.Assessment.Status

$computerName = Encode-Html `
    $report.Endpoint.ComputerName

$currentUser = Encode-Html `
    $report.Endpoint.CurrentUser

$operatingSystem = Encode-Html `
    $report.Endpoint.OperatingSystem

$osVersion = Encode-Html `
    $report.Endpoint.OSVersion

$uptimeDays = Encode-Html `
    $report.Endpoint.UptimeDays

$administrator = Format-State `
    $report.Endpoint.Administrator `
    "Yes" `
    "No"

$cpuModel = Encode-Html `
    $report.Hardware.CPU.Model

$cpuLoad = Encode-Html `
    $report.Hardware.CPU.LoadPercent

$memoryUsage = Encode-Html `
    $report.Hardware.Memory.UsagePercent

if ($report.Hardware.Memory.UsagePercent -ge 90) {

    $memoryClass = "bad"
}
elseif ($report.Hardware.Memory.UsagePercent -ge 75) {

    $memoryClass = "warning-value"
}
else {

    $memoryClass = "good"
}

$memoryUsed = Encode-Html `
    $report.Hardware.Memory.UsedGB

$memoryTotal = Encode-Html `
    $report.Hardware.Memory.TotalGB

$diskFreePercent = Encode-Html `
    $report.Hardware.Disk.FreePercent

$diskFreeGB = Encode-Html `
    $report.Hardware.Disk.FreeGB

$diskTotalGB = Encode-Html `
    $report.Hardware.Disk.TotalGB

$adapter = Encode-Html `
    $report.Network.Adapter

$ipv4Address = Encode-Html `
    $report.Network.IPv4Address

$defaultGateway = Encode-Html `
    $report.Network.DefaultGateway

$linkSpeed = Encode-Html `
    $report.Network.LinkSpeed

$gatewayLatency = Encode-Html `
    $report.Network.GatewayLatencyMs

$gatewayStatus = Format-State `
    $report.Network.GatewayReachable `
    "Operational" `
    "Offline"

$gatewayClass = Get-StateClass `
    $report.Network.GatewayReachable

$dnsStatus = Format-State `
    $report.Network.DnsResolution `
    "Operational" `
    "Failed"

$dnsClass = Get-StateClass `
    $report.Network.DnsResolution

$internetStatus = Format-State `
    $report.Network.InternetAccess `
    "Operational" `
    "Failed"

$internetClass = Get-StateClass `
    $report.Network.InternetAccess

$dnsServers = @(
    $report.Network.DnsServers
) -join ", "

$dnsServers = Encode-Html `
    $dnsServers

$registeredAntivirus = @(
    $report.Security.RegisteredAntivirus
) -join ", "

$registeredAntivirus = Encode-Html `
    $registeredAntivirus

$firewallDomain = Format-State `
    $report.Security.Firewall.DomainEnabled

$firewallPrivate = Format-State `
    $report.Security.Firewall.PrivateEnabled

$firewallPublic = Format-State `
    $report.Security.Firewall.PublicEnabled

$firewallDomainClass = Get-StateClass `
    $report.Security.Firewall.DomainEnabled

$firewallPrivateClass = Get-StateClass `
    $report.Security.Firewall.PrivateEnabled

$firewallPublicClass = Get-StateClass `
    $report.Security.Firewall.PublicEnabled

if ($report.Security.SecureBoot.Available) {

    $secureBoot = Format-State `
        $report.Security.SecureBoot.Enabled

    $secureBootClass = Get-StateClass `
        $report.Security.SecureBoot.Enabled
}
else {

    $secureBoot = "Unavailable"
    $secureBootClass = "neutral"
}

if ($report.Security.BitLocker.Available) {

    $bitLocker = Encode-Html `
        $report.Security.BitLocker.ProtectionStatus

    if (
        $report.Security.BitLocker.ProtectionStatus -eq "On"
    ) {

        $bitLockerClass = "good"
    }
    else {

        $bitLockerClass = "bad"
    }
}
else {

    $bitLocker = "Unavailable"
    $bitLockerClass = "neutral"
}

$scanTime = Encode-Html `
    $report.Metadata.Timestamp

$scanId = Encode-Html `
    $report.Metadata.ScanId

$toolVersion = Encode-Html `
    $report.Metadata.Version

# ====================================================
# FINDINGS HTML
# ====================================================

$findingsHtml = ""

foreach ($finding in $report.Assessment.Findings) {

    $severity = Encode-Html `
        $finding.Severity

    $check = Encode-Html `
        $finding.Check

    $message = Encode-Html `
        $finding.Message

    $deduction = Encode-Html `
        $finding.Deduction

    $severityClass = Get-SeverityClass `
        $finding.Severity

    $deductionDisplay = ""

    if ($finding.Deduction -gt 0) {

        $deductionDisplay = "-$deduction"
    }
    else {

        $deductionDisplay = "-"
    }

    $findingsHtml += @"
<tr>
    <td>
        <span class="severity $severityClass">
            $severity
        </span>
    </td>
    <td>$check</td>
    <td>$message</td>
    <td class="deduction">$deductionDisplay</td>
</tr>
"@
}

# ====================================================
# SCORE CLASS
# ====================================================

if ($healthScore -ge 95) {

    $scoreClass = "score-optimal"
}
elseif ($healthScore -ge 85) {

    $scoreClass = "score-operational"
}
elseif ($healthScore -ge 70) {

    $scoreClass = "score-warning"
}
else {

    $scoreClass = "score-critical"
}

# ====================================================
# HTML DOCUMENT
# ====================================================

$html = @"
<!DOCTYPE html>
<html lang="en">

<head>

<meta charset="UTF-8">

<meta
    name="viewport"
    content="width=device-width, initial-scale=1.0"
>

<title>
    Wayne Enterprises Endpoint Diagnostic
</title>

<style>

* {
    box-sizing: border-box;
}

body {
    margin: 0;

    font-family:
        "Segoe UI",
        Arial,
        sans-serif;

    background:
        radial-gradient(
            circle at top,
            #18212b 0%,
            #0b1016 38%,
            #05080c 100%
        );

    color: #e7edf3;

    min-height: 100vh;
}

.container {
    width: min(1400px, 94%);
    margin: 0 auto;

    padding:
        40px 0 70px;
}

.header {
    display: flex;

    justify-content:
        space-between;

    align-items:
        flex-end;

    gap: 30px;

    padding-bottom: 26px;

    border-bottom:
        1px solid #273341;

    margin-bottom: 28px;
}

.brand-eyebrow {
    color: #8897a6;

    letter-spacing:
        0.28em;

    font-size: 12px;

    font-weight: 700;
}

h1 {
    margin:
        8px 0 4px;

    font-size:
        clamp(
            30px,
            4vw,
            52px
        );

    letter-spacing:
        -0.03em;
}

.subtitle {
    color: #8d9cab;

    margin: 0;
}

.scan-meta {
    text-align: right;

    color: #778695;

    font-size: 13px;

    line-height: 1.8;
}

.hero {
    display: grid;

    grid-template-columns:
        minmax(250px, 0.8fr)
        minmax(400px, 2fr);

    gap: 22px;

    margin-bottom: 22px;
}

.panel {
    background:
        linear-gradient(
            145deg,
            rgba(23, 31, 40, 0.96),
            rgba(11, 16, 22, 0.98)
        );

    border:
        1px solid #263442;

    border-radius: 14px;

    padding: 24px;

    box-shadow:
        0 20px 50px
        rgba(0, 0, 0, 0.2);
}

.score-panel {
    display: flex;

    flex-direction:
        column;

    justify-content:
        center;

    text-align:
        center;
}

.score-label {
    color: #7f8e9d;

    letter-spacing:
        0.2em;

    font-size: 11px;

    font-weight: 700;
}

.score {
    font-size: 82px;

    font-weight: 750;

    line-height: 1;

    margin:
        18px 0 8px;
}

.score span {
    font-size: 22px;

    color: #657382;
}

.score-optimal {
    color: #58dfa3;
}

.score-operational {
    color: #9fdc74;
}

.score-warning {
    color: #f2c460;
}

.score-critical {
    color: #ff6b6b;
}

.status {
    display: inline-flex;

    align-self:
        center;

    padding:
        8px 14px;

    border:
        1px solid #354657;

    border-radius:
        100px;

    color: #cbd5df;

    font-size: 12px;

    letter-spacing:
        0.14em;

    font-weight: 700;
}

.endpoint-grid {
    display: grid;

    grid-template-columns:
        repeat(
            2,
            minmax(0, 1fr)
        );

    gap: 14px;
}

.metric {
    background:
        #0c1218;

    border:
        1px solid #202c38;

    border-radius:
        10px;

    padding:
        16px;
}

.metric-label {
    color:
        #71808f;

    font-size:
        11px;

    text-transform:
        uppercase;

    letter-spacing:
        0.14em;

    margin-bottom:
        8px;
}

.metric-value {
    font-size:
        17px;

    font-weight:
        600;

    overflow-wrap:
        anywhere;
}

.section-title {
    margin:
        0 0 18px;

    font-size:
        14px;

    text-transform:
        uppercase;

    letter-spacing:
        0.16em;

    color:
        #9aa9b8;
}

.dashboard-grid {
    display: grid;

    grid-template-columns:
        repeat(
            3,
            minmax(0, 1fr)
        );

    gap: 22px;

    margin-bottom:
        22px;
}

.list {
    display: grid;

    gap: 13px;
}

.list-row {
    display: flex;

    justify-content:
        space-between;

    gap: 20px;

    padding-bottom:
        12px;

    border-bottom:
        1px solid #1e2934;
}

.list-row:last-child {
    border-bottom:
        none;

    padding-bottom:
        0;
}

.list-label {
    color:
        #778695;
}

.list-value {
    font-weight:
        600;

    text-align:
        right;

    overflow-wrap:
        anywhere;
}

.good {
    color:
        #58dfa3;
}

.bad {
    color:
        #ff7474;
}

.warning-value {
    color:
        #f4c762;
}

.neutral {
    color:
        #a4b0bc;
}

.findings-panel {
    overflow-x:
        auto;
}

table {
    width:
        100%;

    border-collapse:
        collapse;

    min-width:
        760px;
}

th {
    color:
        #6f7f8f;

    text-align:
        left;

    font-size:
        11px;

    text-transform:
        uppercase;

    letter-spacing:
        0.12em;

    padding:
        0 14px 12px 0;
}

td {
    border-top:
        1px solid #202c37;

    padding:
        15px 14px 15px 0;

    vertical-align:
        top;

    color:
        #c9d3dd;
}

.severity {
    display:
        inline-block;

    padding:
        5px 9px;

    border-radius:
        6px;

    font-size:
        10px;

    font-weight:
        800;

    letter-spacing:
        0.1em;
}

.pass {
    color:
        #63e8aa;

    background:
        rgba(
            55,
            196,
            132,
            0.1
        );
}

.warn {
    color:
        #f4c762;

    background:
        rgba(
            244,
            199,
            98,
            0.1
        );
}

.fail {
    color:
        #ff7777;

    background:
        rgba(
            255,
            119,
            119,
            0.1
        );
}

.info {
    color:
        #72b7ff;

    background:
        rgba(
            114,
            183,
            255,
            0.1
        );
}

.deduction {
    font-family:
        Consolas,
        monospace;
}

.footer {
    color:
        #5f6e7c;

    text-align:
        center;

    padding-top:
        30px;

    font-size:
        12px;
}

@media (
    max-width: 950px
) {

    .hero {
        grid-template-columns:
            1fr;
    }

    .dashboard-grid {
        grid-template-columns:
            1fr;
    }
}

@media (
    max-width: 650px
) {

    .header {
        display:
            block;
    }

    .scan-meta {
        text-align:
            left;

        margin-top:
            18px;
    }

    .endpoint-grid {
        grid-template-columns:
            1fr;
    }
}

</style>

</head>

<body>

<div class="container">

    <header class="header">

        <div>

            <div class="brand-eyebrow">
                WAYNE ENTERPRISES
            </div>

            <h1>
                Endpoint Command Center
            </h1>

            <p class="subtitle">
                Automated Windows health,
                network and security assessment
            </p>

        </div>

        <div class="scan-meta">

            <div>
                Version $toolVersion
            </div>

            <div>
                $scanTime
            </div>

        </div>

    </header>

    <section class="hero">

        <div class="panel score-panel">

            <div class="score-label">
                ENDPOINT HEALTH
            </div>

            <div class="score $scoreClass">
                $healthScore<span>/100</span>
            </div>

            <div class="status">
                $healthStatus
            </div>

        </div>

        <div class="panel">

            <h2 class="section-title">
                Endpoint Identity
            </h2>

            <div class="endpoint-grid">

                <div class="metric">

                    <div class="metric-label">
                        Hostname
                    </div>

                    <div class="metric-value">
                        $computerName
                    </div>

                </div>

                <div class="metric">

                    <div class="metric-label">
                        Current User
                    </div>

                    <div class="metric-value">
                        $currentUser
                    </div>

                </div>

                <div class="metric">

                    <div class="metric-label">
                        Operating System
                    </div>

                    <div class="metric-value">
                        $operatingSystem
                    </div>

                </div>

                <div class="metric">

                    <div class="metric-label">
                        OS Version
                    </div>

                    <div class="metric-value">
                        $osVersion
                    </div>

                </div>

                <div class="metric">

                    <div class="metric-label">
                        Uptime
                    </div>

                    <div class="metric-value">
                        $uptimeDays days
                    </div>

                </div>

                <div class="metric">

                    <div class="metric-label">
                        Elevated Scan
                    </div>

                    <div class="metric-value">
                        $administrator
                    </div>

                </div>

            </div>

        </div>

    </section>

    <section class="dashboard-grid">

        <div class="panel">

            <h2 class="section-title">
                Hardware
            </h2>

            <div class="list">

                <div class="list-row">

                    <span class="list-label">
                        CPU
                    </span>

                    <span class="list-value">
                        $cpuLoad%
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Memory
                    </span>

                    <span class="list-value $memoryClass">
                        $memoryUsage%
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Memory Used
                    </span>

                    <span class="list-value">
                        $memoryUsed / $memoryTotal GB
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Disk Free
                    </span>

                    <span class="list-value">
                        $diskFreePercent%
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Free Capacity
                    </span>

                    <span class="list-value">
                        $diskFreeGB / $diskTotalGB GB
                    </span>

                </div>

            </div>

        </div>

        <div class="panel">

            <h2 class="section-title">
                Network
            </h2>

            <div class="list">

                <div class="list-row">

                    <span class="list-label">
                        Adapter
                    </span>

                    <span class="list-value">
                        $adapter
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        IPv4
                    </span>

                    <span class="list-value">
                        $ipv4Address
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Gateway
                    </span>

                    <span class="list-value">
                        $defaultGateway
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Link Speed
                    </span>

                    <span class="list-value">
                        $linkSpeed
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Gateway
                    </span>

                    <span class="list-value $gatewayClass">
                        $gatewayStatus
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Latency
                    </span>

                    <span class="list-value">
                        $gatewayLatency ms
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        DNS
                    </span>

                    <span class="list-value $dnsClass">
                        $dnsStatus
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Internet
                    </span>

                    <span class="list-value $internetClass">
                        $internetStatus
                    </span>

                </div>

            </div>

        </div>

        <div class="panel">

            <h2 class="section-title">
                Security
            </h2>

            <div class="list">

                <div class="list-row">

                    <span class="list-label">
                        Registered AV
                    </span>

                    <span class="list-value">
                        $registeredAntivirus
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Domain Firewall
                    </span>

                    <span class="list-value $firewallDomainClass">
                        $firewallDomain
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Private Firewall
                    </span>

                    <span class="list-value $firewallPrivateClass">
                        $firewallPrivate
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Public Firewall
                    </span>

                    <span class="list-value $firewallPublicClass">
                        $firewallPublic
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        Secure Boot
                    </span>

                    <span class="list-value $secureBootClass">
                        $secureBoot
                    </span>

                </div>

                <div class="list-row">

                    <span class="list-label">
                        BitLocker
                    </span>

                    <span class="list-value $bitLockerClass">
                        $bitLocker
                    </span>

                </div>

            </div>

        </div>

    </section>

    <section class="panel findings-panel">

        <h2 class="section-title">
            Diagnostic Findings
        </h2>

        <table>

            <thead>

                <tr>

                    <th>
                        Severity
                    </th>

                    <th>
                        Check
                    </th>

                    <th>
                        Finding
                    </th>

                    <th>
                        Score
                    </th>

                </tr>

            </thead>

            <tbody>

                $findingsHtml

            </tbody>

        </table>

    </section>

    <footer class="footer">

        Wayne Enterprises Endpoint Diagnostic
        &nbsp;|&nbsp;
        Scan ID: $scanId

    </footer>

</div>

</body>

</html>
"@

# ====================================================
# OUTPUT PATH
# ====================================================

$jsonFile = Get-Item `
    $ReportPath

$htmlFileName = (
    $jsonFile.BaseName +
    ".html"
)

$htmlReportPath = Join-Path `
    $reportDirectory `
    $htmlFileName

# ====================================================
# WRITE HTML
# ====================================================

$html |
    Set-Content `
        -Path $htmlReportPath `
        -Encoding UTF8

# ====================================================
# COMPLETE
# ====================================================

Write-Host ""
Write-Host "====================================================="
Write-Host "        WAYNE ENTERPRISES REPORT GENERATOR"
Write-Host "====================================================="
Write-Host ""

Write-Host "Source Report : " `
    -NoNewline

Write-Host `
    $ReportPath `
    -ForegroundColor Cyan

Write-Host "HTML Report   : " `
    -NoNewline

Write-Host `
    $htmlReportPath `
    -ForegroundColor Green

Write-Host ""
Write-Host "Report generation complete."
Write-Host "====================================================="
Write-Host ""