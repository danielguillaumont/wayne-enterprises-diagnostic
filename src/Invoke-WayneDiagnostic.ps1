<#
.SYNOPSIS
    Wayne Enterprises Endpoint Diagnostic

.DESCRIPTION
    Performs hardware, network, and security diagnostic checks
    against a Windows endpoint.

    The diagnostic engine interprets collected telemetry,
    assigns findings and severity levels, calculates an endpoint
    health score, and generates a structured JSON report.

.NOTES
    Project: Wayne Enterprises Diagnostic
#>

Clear-Host

Write-Host ""
Write-Host "====================================================="
Write-Host "        WAYNE ENTERPRISES ENDPOINT DIAGNOSTIC"
Write-Host "====================================================="
Write-Host ""
Write-Host "Initializing system scan..."
Write-Host ""

# ====================================================
# SCAN METADATA
# ====================================================

$scanTime = Get-Date
$scanId = [guid]::NewGuid().ToString()

# ====================================================
# ADMINISTRATOR STATUS
# ====================================================

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()

$currentPrincipal = New-Object `
    Security.Principal.WindowsPrincipal($currentIdentity)

$isAdministrator = $currentPrincipal.IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)

# ====================================================
# ENDPOINT INFORMATION
# ====================================================

$computerName = $env:COMPUTERNAME
$currentUser = $env:USERNAME
$os = Get-CimInstance Win32_OperatingSystem

$uptime = (Get-Date) - $os.LastBootUpTime
$uptimeDays = [math]::Round($uptime.TotalDays, 1)

Write-Host "ENDPOINT INFORMATION"
Write-Host "-----------------------------------------------------"
Write-Host "Computer Name : $computerName"
Write-Host "Current User  : $currentUser"
Write-Host "Operating OS  : $($os.Caption)"
Write-Host "OS Version    : $($os.Version)"
Write-Host "Uptime        : $uptimeDays days"
Write-Host "Administrator : $isAdministrator"

# ====================================================
# CPU HEALTH
# ====================================================

$processors = Get-CimInstance Win32_Processor

$cpuLoad = [math]::Round(
    (
        $processors |
        Measure-Object `
            -Property LoadPercentage `
            -Average
    ).Average,
    1
)

$cpuName = (
    $processors |
    Select-Object -First 1
).Name.Trim()

# ====================================================
# MEMORY HEALTH
# ====================================================

$totalMemoryGB = [math]::Round(
    $os.TotalVisibleMemorySize / 1MB,
    2
)

$freeMemoryGB = [math]::Round(
    $os.FreePhysicalMemory / 1MB,
    2
)

$usedMemoryGB = [math]::Round(
    $totalMemoryGB - $freeMemoryGB,
    2
)

$memoryUsagePercent = [math]::Round(
    ($usedMemoryGB / $totalMemoryGB) * 100,
    1
)

# ====================================================
# DISK HEALTH
# ====================================================

$systemDrive = Get-CimInstance `
    Win32_LogicalDisk `
    -Filter "DeviceID='$($env:SystemDrive)'"

$totalDiskGB = [math]::Round(
    $systemDrive.Size / 1GB,
    2
)

$freeDiskGB = [math]::Round(
    $systemDrive.FreeSpace / 1GB,
    2
)

$usedDiskGB = [math]::Round(
    $totalDiskGB - $freeDiskGB,
    2
)

$diskFreePercent = [math]::Round(
    ($systemDrive.FreeSpace / $systemDrive.Size) * 100,
    1
)

# ====================================================
# HARDWARE OUTPUT
# ====================================================

Write-Host ""
Write-Host "HARDWARE HEALTH"
Write-Host "-----------------------------------------------------"

Write-Host "CPU            : $cpuName"
Write-Host "CPU Load       : $cpuLoad%"

Write-Host ""
Write-Host "Memory Total   : $totalMemoryGB GB"
Write-Host "Memory Used    : $usedMemoryGB GB"
Write-Host "Memory Free    : $freeMemoryGB GB"
Write-Host "Memory Usage   : $memoryUsagePercent%"

Write-Host ""
Write-Host "System Drive   : $($env:SystemDrive)"
Write-Host "Disk Total     : $totalDiskGB GB"
Write-Host "Disk Used      : $usedDiskGB GB"
Write-Host "Disk Free      : $freeDiskGB GB"
Write-Host "Disk Free %    : $diskFreePercent%"

# ====================================================
# NETWORK DISCOVERY
# ====================================================

$activeNetwork = Get-NetIPConfiguration |
    Where-Object {
        $_.IPv4DefaultGateway -ne $null -and
        $_.NetAdapter.Status -eq "Up"
    } |
    Select-Object -First 1

if ($activeNetwork) {

    $adapterName = $activeNetwork.InterfaceAlias

    $ipv4Address = (
        $activeNetwork.IPv4Address |
        Select-Object -First 1
    ).IPAddress

    $defaultGateway = (
        $activeNetwork.IPv4DefaultGateway |
        Select-Object -First 1
    ).NextHop

    $dnsServerArray = @(
        $activeNetwork.DNSServer.ServerAddresses |
        Where-Object {
            $_ -match '^\d{1,3}(\.\d{1,3}){3}$'
        }
    )

    if ($dnsServerArray.Count -gt 0) {

        $dnsServers = $dnsServerArray -join ", "
    }
    else {

        $dnsServers = "Unavailable"
    }

    $networkAdapter = Get-NetAdapter `
        -InterfaceIndex $activeNetwork.InterfaceIndex `
        -ErrorAction SilentlyContinue

    if ($networkAdapter) {

        $linkSpeed = $networkAdapter.LinkSpeed
    }
    else {

        $linkSpeed = "Unavailable"
    }
}
else {

    $adapterName = "Unavailable"
    $ipv4Address = "Unavailable"
    $defaultGateway = "Unavailable"
    $dnsServerArray = @()
    $dnsServers = "Unavailable"
    $linkSpeed = "Unavailable"
}

# ====================================================
# GATEWAY TEST
# ====================================================

$gatewayReachable = $false
$gatewayLatency = $null

if ($defaultGateway -ne "Unavailable") {

    $gatewayTest = Test-Connection `
        -ComputerName $defaultGateway `
        -Count 2 `
        -ErrorAction SilentlyContinue

    if ($gatewayTest) {

        $gatewayReachable = $true

        $gatewayLatency = [math]::Round(
            (
                $gatewayTest |
                Measure-Object `
                    -Property ResponseTime `
                    -Average
            ).Average,
            1
        )
    }
}

# ====================================================
# DNS TEST
# ====================================================

$dnsWorking = $false

try {

    $dnsResult = Resolve-DnsName `
        microsoft.com `
        -ErrorAction Stop

    if ($dnsResult) {

        $dnsWorking = $true
    }
}
catch {

    $dnsWorking = $false
}

# ====================================================
# INTERNET CONNECTIVITY TEST
# ====================================================

$internetWorking = Test-Connection `
    -ComputerName 1.1.1.1 `
    -Count 1 `
    -Quiet `
    -ErrorAction SilentlyContinue

# ====================================================
# NETWORK OUTPUT
# ====================================================

Write-Host ""
Write-Host "NETWORK HEALTH"
Write-Host "-----------------------------------------------------"

Write-Host "Active Adapter : $adapterName"
Write-Host "IPv4 Address   : $ipv4Address"
Write-Host "Default Gateway: $defaultGateway"
Write-Host "DNS Servers    : $dnsServers"
Write-Host "Link Speed     : $linkSpeed"

Write-Host ""
Write-Host "Gateway Online : $gatewayReachable"

if ($gatewayReachable) {

    Write-Host "Gateway Latency: $gatewayLatency ms"
}
else {

    Write-Host "Gateway Latency: Unavailable"
}

Write-Host "DNS Resolution : $dnsWorking"
Write-Host "Internet Access: $internetWorking"

# ====================================================
# WINDOWS DEFENDER
# ====================================================

$defenderAvailable = $false
$defenderEnabled = $null
$realTimeProtection = $null
$signatureAge = $null
$signatureAgeDisplay = "Unavailable"

try {

    $defenderStatus = Get-MpComputerStatus `
        -ErrorAction Stop

    $defenderAvailable = $true
    $defenderEnabled = $defenderStatus.AntivirusEnabled
    $realTimeProtection = $defenderStatus.RealTimeProtectionEnabled

    if (
        $defenderEnabled -eq $true -and
        $defenderStatus.AntivirusSignatureAge -ne 65535
    ) {

        $signatureAge = $defenderStatus.AntivirusSignatureAge
        $signatureAgeDisplay = "$signatureAge days"
    }
}
catch {

    $defenderAvailable = $false
}

# ====================================================
# REGISTERED ANTIVIRUS PRODUCTS
# ====================================================

$registeredAntivirus = @()

try {

    $registeredAntivirus = @(
        Get-CimInstance `
            -Namespace "root/SecurityCenter2" `
            -ClassName AntivirusProduct `
            -ErrorAction Stop |
        Select-Object -ExpandProperty displayName |
        Sort-Object -Unique
    )
}
catch {

    $registeredAntivirus = @()
}

if ($registeredAntivirus.Count -gt 0) {

    $registeredAntivirusDisplay = (
        $registeredAntivirus -join ", "
    )
}
else {

    $registeredAntivirusDisplay = "Unavailable"
}

$thirdPartyAntivirus = @(
    $registeredAntivirus |
    Where-Object {
        $_ -notmatch "Windows Defender" -and
        $_ -notmatch "Microsoft Defender"
    }
)

# ====================================================
# WINDOWS FIREWALL
# ====================================================

$domainFirewall = $null
$privateFirewall = $null
$publicFirewall = $null
$firewallAvailable = $false

try {

    $firewallProfiles = Get-NetFirewallProfile `
        -ErrorAction Stop

    $domainProfile = $firewallProfiles |
        Where-Object Name -eq "Domain"

    $privateProfile = $firewallProfiles |
        Where-Object Name -eq "Private"

    $publicProfile = $firewallProfiles |
        Where-Object Name -eq "Public"

    $domainFirewall = $domainProfile.Enabled
    $privateFirewall = $privateProfile.Enabled
    $publicFirewall = $publicProfile.Enabled

    $firewallAvailable = $true
}
catch {

    $firewallAvailable = $false
}

# ====================================================
# SECURE BOOT
# ====================================================

$secureBootAvailable = $false
$secureBootEnabled = $null

try {

    $secureBootEnabled = Confirm-SecureBootUEFI `
        -ErrorAction Stop

    $secureBootAvailable = $true
}
catch {

    $secureBootAvailable = $false
}

# ====================================================
# BITLOCKER
# ====================================================

$bitLockerAvailable = $false
$bitLockerStatus = $null
$bitLockerProtection = $null

try {

    $bitLockerVolume = Get-BitLockerVolume `
        -MountPoint $env:SystemDrive `
        -ErrorAction Stop

    if ($bitLockerVolume) {

        $bitLockerAvailable = $true
        $bitLockerStatus = $bitLockerVolume.VolumeStatus.ToString()
        $bitLockerProtection = $bitLockerVolume.ProtectionStatus.ToString()
    }
}
catch {

    $bitLockerAvailable = $false
}

# ====================================================
# SECURITY OUTPUT
# ====================================================

Write-Host ""
Write-Host "SECURITY POSTURE"
Write-Host "-----------------------------------------------------"

Write-Host "Defender Found : $defenderAvailable"

if ($defenderEnabled -ne $null) {

    Write-Host "Antivirus      : $defenderEnabled"
    Write-Host "Real-Time Prot.: $realTimeProtection"
}
else {

    Write-Host "Antivirus      : Unavailable"
    Write-Host "Real-Time Prot.: Unavailable"
}

Write-Host "Signature Age  : $signatureAgeDisplay"
Write-Host "Registered AV  : $registeredAntivirusDisplay"

Write-Host ""
Write-Host "Firewall"

if ($firewallAvailable) {

    Write-Host "  Domain       : $domainFirewall"
    Write-Host "  Private      : $privateFirewall"
    Write-Host "  Public       : $publicFirewall"
}
else {

    Write-Host "  Domain       : Unavailable"
    Write-Host "  Private      : Unavailable"
    Write-Host "  Public       : Unavailable"
}

Write-Host ""

if ($secureBootAvailable) {

    Write-Host "Secure Boot    : $secureBootEnabled"
}
else {

    Write-Host "Secure Boot    : Unavailable"
}

if ($bitLockerAvailable) {

    Write-Host "BitLocker      : $bitLockerStatus"
    Write-Host "BL Protection  : $bitLockerProtection"
}
else {

    Write-Host "BitLocker      : Unavailable"
    Write-Host "BL Protection  : Unavailable"
}

# ====================================================
# DIAGNOSTIC ENGINE
# ====================================================

$healthScore = 100
$findings = @()

function Add-Finding {

    param(
        [string]$Severity,
        [string]$Check,
        [string]$Message,
        [int]$Deduction = 0
    )

    $script:findings += [PSCustomObject]@{
        Severity  = $Severity
        Check     = $Check
        Message   = $Message
        Deduction = $Deduction
    }

    $script:healthScore -= $Deduction
}

# ====================================================
# CPU ASSESSMENT
# ====================================================

if ($cpuLoad -ge 90) {

    Add-Finding `
        -Severity "WARN" `
        -Check "CPU" `
        -Message "CPU utilization is currently very high at $cpuLoad%." `
        -Deduction 5
}
else {

    Add-Finding `
        -Severity "PASS" `
        -Check "CPU" `
        -Message "CPU utilization is within the expected range at $cpuLoad%."
}

# ====================================================
# MEMORY ASSESSMENT
# ====================================================

if ($memoryUsagePercent -ge 90) {

    Add-Finding `
        -Severity "FAIL" `
        -Check "Memory" `
        -Message "Memory utilization is critically high at $memoryUsagePercent%." `
        -Deduction 15
}
elseif ($memoryUsagePercent -ge 75) {

    Add-Finding `
        -Severity "WARN" `
        -Check "Memory" `
        -Message "Memory utilization is elevated at $memoryUsagePercent%." `
        -Deduction 5
}
else {

    Add-Finding `
        -Severity "PASS" `
        -Check "Memory" `
        -Message "Memory utilization is healthy at $memoryUsagePercent%."
}

# ====================================================
# DISK ASSESSMENT
# ====================================================

if ($diskFreePercent -lt 10) {

    Add-Finding `
        -Severity "FAIL" `
        -Check "Disk" `
        -Message "System drive capacity is critically low with $diskFreePercent% free." `
        -Deduction 20
}
elseif ($diskFreePercent -lt 20) {

    Add-Finding `
        -Severity "WARN" `
        -Check "Disk" `
        -Message "System drive is running low with $diskFreePercent% free." `
        -Deduction 10
}
else {

    Add-Finding `
        -Severity "PASS" `
        -Check "Disk" `
        -Message "System drive capacity is healthy with $diskFreePercent% free."
}

# ====================================================
# NETWORK ASSESSMENT
# ====================================================

if ($gatewayReachable) {

    Add-Finding `
        -Severity "PASS" `
        -Check "Gateway" `
        -Message "Default gateway is reachable with $gatewayLatency ms average latency."
}
else {

    Add-Finding `
        -Severity "FAIL" `
        -Check "Gateway" `
        -Message "Default gateway could not be reached." `
        -Deduction 15
}

if ($dnsWorking) {

    Add-Finding `
        -Severity "PASS" `
        -Check "DNS" `
        -Message "DNS resolution is operational."
}
else {

    Add-Finding `
        -Severity "FAIL" `
        -Check "DNS" `
        -Message "DNS resolution failed." `
        -Deduction 15
}

if ($internetWorking) {

    Add-Finding `
        -Severity "PASS" `
        -Check "Internet" `
        -Message "External network connectivity is operational."
}
else {

    Add-Finding `
        -Severity "FAIL" `
        -Check "Internet" `
        -Message "External network connectivity failed." `
        -Deduction 20
}

# ====================================================
# ANTIVIRUS ASSESSMENT
# ====================================================

if (-not $defenderAvailable) {

    Add-Finding `
        -Severity "INFO" `
        -Check "Defender" `
        -Message "Microsoft Defender status could not be determined."
}
elseif ($defenderEnabled -eq $true) {

    Add-Finding `
        -Severity "PASS" `
        -Check "Defender" `
        -Message "Microsoft Defender Antivirus is active."
}
elseif ($thirdPartyAntivirus.Count -gt 0) {

    $thirdPartyDisplay = $thirdPartyAntivirus -join ", "

    Add-Finding `
        -Severity "INFO" `
        -Check "Antivirus" `
        -Message "Microsoft Defender is not active. A third-party antivirus product is registered: $thirdPartyDisplay."
}
else {

    Add-Finding `
        -Severity "WARN" `
        -Check "Antivirus" `
        -Message "Microsoft Defender is not active and no third-party antivirus product was detected." `
        -Deduction 10
}

# ====================================================
# DEFENDER REAL-TIME PROTECTION
# ====================================================

if ($defenderEnabled -eq $true) {

    if ($realTimeProtection -eq $true) {

        Add-Finding `
            -Severity "PASS" `
            -Check "Real-Time Protection" `
            -Message "Microsoft Defender real-time protection is enabled."
    }
    else {

        Add-Finding `
            -Severity "WARN" `
            -Check "Real-Time Protection" `
            -Message "Microsoft Defender is active but real-time protection is disabled." `
            -Deduction 10
    }
}
else {

    Add-Finding `
        -Severity "INFO" `
        -Check "Real-Time Protection" `
        -Message "Defender real-time protection was not assessed because Microsoft Defender Antivirus is not active."
}

# ====================================================
# ANTIVIRUS SIGNATURE ASSESSMENT
# ====================================================

if (
    $defenderEnabled -eq $true -and
    $signatureAge -ne $null
) {

    if ($signatureAge -gt 7) {

        Add-Finding `
            -Severity "WARN" `
            -Check "AV Signatures" `
            -Message "Microsoft Defender signatures are $signatureAge days old." `
            -Deduction 5
    }
    else {

        Add-Finding `
            -Severity "PASS" `
            -Check "AV Signatures" `
            -Message "Microsoft Defender signatures are current."
    }
}
else {

    Add-Finding `
        -Severity "INFO" `
        -Check "AV Signatures" `
        -Message "Defender signature age was not assessed because Microsoft Defender Antivirus is not active."
}

# ====================================================
# FIREWALL ASSESSMENT
# ====================================================

if (-not $firewallAvailable) {

    Add-Finding `
        -Severity "INFO" `
        -Check "Firewall" `
        -Message "Windows Firewall profiles could not be evaluated."
}
elseif (
    $domainFirewall -eq $true -and
    $privateFirewall -eq $true -and
    $publicFirewall -eq $true
) {

    Add-Finding `
        -Severity "PASS" `
        -Check "Firewall" `
        -Message "All Windows Firewall profiles are enabled."
}
else {

    Add-Finding `
        -Severity "WARN" `
        -Check "Firewall" `
        -Message "One or more Windows Firewall profiles are disabled." `
        -Deduction 10
}

# ====================================================
# SECURE BOOT ASSESSMENT
# ====================================================

if (-not $secureBootAvailable) {

    Add-Finding `
        -Severity "INFO" `
        -Check "Secure Boot" `
        -Message "Secure Boot could not be evaluated. Elevated permissions or supported UEFI firmware may be required."
}
elseif ($secureBootEnabled -eq $true) {

    Add-Finding `
        -Severity "PASS" `
        -Check "Secure Boot" `
        -Message "Secure Boot is enabled."
}
else {

    Add-Finding `
        -Severity "WARN" `
        -Check "Secure Boot" `
        -Message "Secure Boot is disabled." `
        -Deduction 8
}

# ====================================================
# BITLOCKER ASSESSMENT
# ====================================================

if (-not $bitLockerAvailable) {

    Add-Finding `
        -Severity "INFO" `
        -Check "BitLocker" `
        -Message "BitLocker status could not be evaluated. Elevated permissions or supported Windows configuration may be required."
}
elseif ($bitLockerProtection -eq "On") {

    Add-Finding `
        -Severity "PASS" `
        -Check "BitLocker" `
        -Message "BitLocker protection is enabled on the system drive."
}
else {

    Add-Finding `
        -Severity "WARN" `
        -Check "BitLocker" `
        -Message "BitLocker protection is not enabled on the system drive." `
        -Deduction 10
}

# ====================================================
# ADMINISTRATOR ASSESSMENT
# ====================================================

if (-not $isAdministrator) {

    Add-Finding `
        -Severity "INFO" `
        -Check "Privileges" `
        -Message "Diagnostic is running without administrator privileges. Some security checks may be unavailable."
}

# ====================================================
# SCORE NORMALIZATION
# ====================================================

if ($healthScore -lt 0) {

    $healthScore = 0
}

# ====================================================
# FINDING COUNTS
# ====================================================

$warningCount = @(
    $findings |
    Where-Object {
        $_.Severity -eq "WARN"
    }
).Count

$failureCount = @(
    $findings |
    Where-Object {
        $_.Severity -eq "FAIL"
    }
).Count

# ====================================================
# HEALTH STATUS
# ====================================================

if (
    $healthScore -ge 95 -and
    $warningCount -eq 0 -and
    $failureCount -eq 0
) {

    $healthStatus = "OPTIMAL"
}
elseif (
    $healthScore -ge 85 -and
    $failureCount -eq 0
) {

    $healthStatus = "OPERATIONAL"
}
elseif ($healthScore -ge 70) {

    $healthStatus = "ATTENTION REQUIRED"
}
else {

    $healthStatus = "ACTION REQUIRED"
}

# ====================================================
# DIAGNOSTIC ASSESSMENT OUTPUT
# ====================================================

Write-Host ""
Write-Host "WAYNE ENTERPRISES DIAGNOSTIC ASSESSMENT"
Write-Host "====================================================="

foreach ($finding in $findings) {

    switch ($finding.Severity) {

        "PASS" {

            Write-Host `
                "[PASS] " `
                -ForegroundColor Green `
                -NoNewline
        }

        "WARN" {

            Write-Host `
                "[WARN] " `
                -ForegroundColor Yellow `
                -NoNewline
        }

        "FAIL" {

            Write-Host `
                "[FAIL] " `
                -ForegroundColor Red `
                -NoNewline
        }

        "INFO" {

            Write-Host `
                "[INFO] " `
                -ForegroundColor Cyan `
                -NoNewline
        }
    }

    Write-Host "$($finding.Check): $($finding.Message)"
}

Write-Host ""
Write-Host "-----------------------------------------------------"
Write-Host "ENDPOINT HEALTH SCORE : $healthScore / 100"
Write-Host "STATUS                : $healthStatus"
Write-Host "-----------------------------------------------------"

# ====================================================
# STRUCTURED REPORT OBJECT
# ====================================================

$report = [PSCustomObject]@{

    Metadata = [PSCustomObject]@{

        ScanId = $scanId

        Timestamp = $scanTime.ToString(
            "yyyy-MM-ddTHH:mm:ssK"
        )

        Tool = "Wayne Enterprises Endpoint Diagnostic"

        Version = "0.1.0"
    }

    Endpoint = [PSCustomObject]@{

        ComputerName = $computerName

        CurrentUser = $currentUser

        OperatingSystem = $os.Caption

        OSVersion = $os.Version

        UptimeDays = $uptimeDays

        Administrator = $isAdministrator
    }

    Hardware = [PSCustomObject]@{

        CPU = [PSCustomObject]@{

            Model = $cpuName

            LoadPercent = $cpuLoad
        }

        Memory = [PSCustomObject]@{

            TotalGB = $totalMemoryGB

            UsedGB = $usedMemoryGB

            FreeGB = $freeMemoryGB

            UsagePercent = $memoryUsagePercent
        }

        Disk = [PSCustomObject]@{

            Drive = $env:SystemDrive

            TotalGB = $totalDiskGB

            UsedGB = $usedDiskGB

            FreeGB = $freeDiskGB

            FreePercent = $diskFreePercent
        }
    }

    Network = [PSCustomObject]@{

        Adapter = $adapterName

        IPv4Address = $ipv4Address

        DefaultGateway = $defaultGateway

        DnsServers = $dnsServerArray

        LinkSpeed = $linkSpeed

        GatewayReachable = $gatewayReachable

        GatewayLatencyMs = $gatewayLatency

        DnsResolution = $dnsWorking

        InternetAccess = $internetWorking
    }

    Security = [PSCustomObject]@{

        Defender = [PSCustomObject]@{

            Available = $defenderAvailable

            AntivirusEnabled = $defenderEnabled

            RealTimeProtection = $realTimeProtection

            SignatureAgeDays = $signatureAge
        }

        RegisteredAntivirus = $registeredAntivirus

        Firewall = [PSCustomObject]@{

            Available = $firewallAvailable

            DomainEnabled = $domainFirewall

            PrivateEnabled = $privateFirewall

            PublicEnabled = $publicFirewall
        }

        SecureBoot = [PSCustomObject]@{

            Available = $secureBootAvailable

            Enabled = $secureBootEnabled
        }

        BitLocker = [PSCustomObject]@{

            Available = $bitLockerAvailable

            VolumeStatus = $bitLockerStatus

            ProtectionStatus = $bitLockerProtection
        }
    }

    Assessment = [PSCustomObject]@{

        HealthScore = $healthScore

        Status = $healthStatus

        WarningCount = $warningCount

        FailureCount = $failureCount

        Findings = $findings
    }
}

# ====================================================
# REPORT DIRECTORY
# ====================================================

$projectRoot = Split-Path `
    -Parent `
    $PSScriptRoot

$reportDirectory = Join-Path `
    $projectRoot `
    "reports"

if (-not (Test-Path $reportDirectory)) {

    New-Item `
        -Path $reportDirectory `
        -ItemType Directory |
        Out-Null
}

# ====================================================
# JSON REPORT
# ====================================================

$fileTimestamp = Get-Date `
    -Format "yyyyMMdd-HHmmss"

$jsonFileName = "wayne-diagnostic-$fileTimestamp.json"

$jsonReportPath = Join-Path `
    $reportDirectory `
    $jsonFileName

$report |
    ConvertTo-Json -Depth 10 |
    Set-Content `
        -Path $jsonReportPath `
        -Encoding UTF8

# ====================================================
# REPORT OUTPUT
# ====================================================

Write-Host ""
Write-Host "REPORT GENERATED"
Write-Host "-----------------------------------------------------"

Write-Host "JSON Report : " -NoNewline

Write-Host `
    $jsonReportPath `
    -ForegroundColor Cyan

# ====================================================
# COMPLETE
# ====================================================

Write-Host ""
Write-Host "System scan complete."
Write-Host "====================================================="
Write-Host ""