<#
.SYNOPSIS
  Windows BSOD / storage troubleshooting script for stop codes like:
  UNEXPECTED_STORE_EXCEPTION (0x154)

.DESCRIPTION
  Collects:
    - System and OS info
    - Recent bugcheck / kernel-power events
    - Disk / partition / volume info
    - Storage health and reliability counters
    - BitLocker status
    - Filesystem scan results
    - SFC / DISM health status
    - Installed drivers and Surface-related devices
    - Minidump inventory
    - Optional export of system event logs
    - Optional repair actions

.PARAMETER OutputDir
  Directory to store results. Default: Desktop\SurfaceCrashTroubleshooting_<timestamp>

.PARAMETER DaysBack
  Number of days of logs to inspect. Default: 14

.PARAMETER RunChkdskScan
  Runs: chkdsk /scan on system drive

.PARAMETER RunSfc
  Runs: sfc /scannow

.PARAMETER RunDismRestoreHealth
  Runs: DISM /Online /Cleanup-Image /RestoreHealth

.PARAMETER ExportEventLogs
  Exports System and Application event logs to .evtx files

.EXAMPLE
  .\troubleshoot-bsod.ps1

.EXAMPLE
  .\troubleshoot-bsod.ps1 -RunChkdskScan -ExportEventLogs

.EXAMPLE
  .\troubleshoot-bsod.ps1 -RunChkdskScan -RunSfc -RunDismRestoreHealth -ExportEventLogs

.NOTES
  Recommended: Run from an elevated PowerShell session.
#>

[CmdletBinding()]
param(
    [string]$OutputDir = "$([Environment]::GetFolderPath('Desktop'))\SurfaceCrashTroubleshooting_$(Get-Date -Format 'yyyyMMdd_HHmmss')",
    [int]$DaysBack = 14,
    [switch]$RunChkdskScan,
    [switch]$RunSfc,
    [switch]$RunDismRestoreHealth,
    [switch]$ExportEventLogs
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

# ---------------------------
# Helpers
# ---------------------------
function Write-Section {
    param([string]$Title)
    $line = ('=' * 80)
    $msg = "`r`n$line`r`n$Title`r`n$line`r`n"
    Write-Host $msg -ForegroundColor Cyan
    Add-Content -Path $script:SummaryFile -Value $msg
}

function Write-Info {
    param([string]$Message)
    Write-Host $Message
    Add-Content -Path $script:SummaryFile -Value ($Message + "`r`n")
}

function Save-Text {
    param(
        [string]$Path,
        [string]$Text
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    Set-Content -Path $Path -Value $Text -Encoding UTF8
}

function Save-CommandOutput {
    param(
        [string]$Title,
        [string]$Path,
        [scriptblock]$ScriptBlock
    )
    try {
        Write-Info "Collecting: $Title"
        $output = & $ScriptBlock 2>&1 | Out-String
        Save-Text -Path $Path -Text $output
    }
    catch {
        $err = "Failed to collect [$Title]: $($_.Exception.Message)"
        Write-Warning $err
        Save-Text -Path $Path -Text $err
    }
}

function Save-ObjectAsTable {
    param(
        [string]$Title,
        [string]$Path,
        [scriptblock]$ScriptBlock
    )
    try {
        Write-Info "Collecting: $Title"
        $obj = & $ScriptBlock
        $text = $obj | Format-Table -AutoSize | Out-String -Width 4096
        Save-Text -Path $Path -Text $text
    }
    catch {
        $err = "Failed to collect [$Title]: $($_.Exception.Message)"
        Write-Warning $err
        Save-Text -Path $Path -Text $err
    }
}

function Save-ObjectAsList {
    param(
        [string]$Title,
        [string]$Path,
        [scriptblock]$ScriptBlock
    )
    try {
        Write-Info "Collecting: $Title"
        $obj = & $ScriptBlock
        $text = $obj | Format-List * | Out-String -Width 4096
        Save-Text -Path $Path -Text $text
    }
    catch {
        $err = "Failed to collect [$Title]: $($_.Exception.Message)"
        Write-Warning $err
        Save-Text -Path $Path -Text $err
    }
}

function Require-Admin {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Safe-Get {
    param([scriptblock]$ScriptBlock)
    try { & $ScriptBlock } catch { $null }
}

function Get-EventMessageSafe {
    param([Parameter(Mandatory = $true)]$EventRecord)
    try {
        $EventRecord.Message
    }
    catch {
        "<Unable to read event message: $($_.Exception.Message)>"
    }
}

# ---------------------------
# Init
# ---------------------------
$IsAdmin = Require-Admin

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
$script:SummaryFile = Join-Path $OutputDir "00_summary.txt"
$rawDir = Join-Path $OutputDir "raw"
$logsDir = Join-Path $OutputDir "logs"
$eventsDir = Join-Path $OutputDir "events"
$dumpsDir = Join-Path $OutputDir "dumps"
$repairDir = Join-Path $OutputDir "repair"
$driversDir = Join-Path $OutputDir "drivers"

New-Item -ItemType Directory -Path $rawDir, $logsDir, $eventsDir, $dumpsDir, $repairDir, $driversDir -Force | Out-Null

Write-Section "Surface / Windows Crash Troubleshooting"
Write-Info "Started: $(Get-Date)"
Write-Info "Output directory: $OutputDir"
Write-Info "Running as admin: $IsAdmin"
Write-Info "Days back for event analysis: $DaysBack"

# ---------------------------
# Basic system info
# ---------------------------
Write-Section "System Information"

Save-ObjectAsList -Title "Computer Info" -Path (Join-Path $rawDir "computerinfo.txt") -ScriptBlock {
    Get-ComputerInfo
}

Save-ObjectAsList -Title "OS Info" -Path (Join-Path $rawDir "os.txt") -ScriptBlock {
    Get-CimInstance Win32_OperatingSystem
}

Save-ObjectAsList -Title "BIOS / Firmware Info" -Path (Join-Path $rawDir "bios.txt") -ScriptBlock {
    Get-CimInstance Win32_BIOS
}

Save-ObjectAsList -Title "Computer System" -Path (Join-Path $rawDir "computer_system.txt") -ScriptBlock {
    Get-CimInstance Win32_ComputerSystem
}

Save-ObjectAsList -Title "Memory Modules" -Path (Join-Path $rawDir "memory_modules.txt") -ScriptBlock {
    Get-CimInstance Win32_PhysicalMemory
}

Save-CommandOutput -Title "systeminfo.exe" -Path (Join-Path $rawDir "systeminfo.txt") -ScriptBlock {
    systeminfo
}

# ---------------------------
# Crash and event log analysis
# ---------------------------
Write-Section "Crash and Event Analysis"

$startTime = (Get-Date).AddDays(-$DaysBack)

Save-ObjectAsTable -Title "Recent BugCheck / Kernel-Power / Disk / NTFS / volmgr events" -Path (Join-Path $eventsDir "key_events.txt") -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        StartTime = $startTime
    } | Where-Object {
        ($_.Id -in 41, 55, 98, 129, 153, 157, 161, 6008, 1001, 7, 11, 15, 50, 51, 140) -or
        ($_.ProviderName -match 'disk|storahci|stornvme|Ntfs|volmgr|volsnap|Microsoft-Windows-WER-SystemErrorReporting|Kernel-Power')
    } | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, @{
        Name       = 'Message'
        Expression = { Get-EventMessageSafe -EventRecord $_ }
    }
}

Save-ObjectAsTable -Title "Recent BugCheck events only" -Path (Join-Path $eventsDir "bugcheck_events.txt") -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Id        = 1001
        StartTime = $startTime
    } | Select-Object TimeCreated, Id, ProviderName, Message
}

Save-ObjectAsTable -Title "Recent Kernel-Power events" -Path (Join-Path $eventsDir "kernel_power_41.txt") -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        Id        = 41
        StartTime = $startTime
    } | Select-Object TimeCreated, Id, ProviderName, Message
}

Save-ObjectAsTable -Title "Recent disk-related events" -Path (Join-Path $eventsDir "disk_related_events.txt") -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'System'
        StartTime = $startTime
    } | Where-Object {
        $_.ProviderName -match 'disk|storahci|stornvme|Ntfs|volmgr|volsnap'
    } | Select-Object TimeCreated, Id, LevelDisplayName, ProviderName, Message
}

if ($ExportEventLogs) {
    Write-Info "Exporting event logs..."
    try {
        wevtutil epl System (Join-Path $logsDir "System.evtx")
    }
    catch {
        Write-Warning "Failed to export System.evtx: $($_.Exception.Message)"
    }

    try {
        wevtutil epl Application (Join-Path $logsDir "Application.evtx")
    }
    catch {
        Write-Warning "Failed to export Application.evtx: $($_.Exception.Message)"
    }
}

# ---------------------------
# Storage and volume health
# ---------------------------
Write-Section "Storage, Volume, and Filesystem Health"

Save-ObjectAsTable -Title "Disk drives" -Path (Join-Path $rawDir "physical_disks.txt") -ScriptBlock {
    Get-PhysicalDisk | Select-Object FriendlyName, Manufacturer, Model, SerialNumber, MediaType, BusType, HealthStatus, OperationalStatus, Size
}

Save-ObjectAsTable -Title "Win32 disk drives" -Path (Join-Path $rawDir "win32_diskdrive.txt") -ScriptBlock {
    Get-CimInstance Win32_DiskDrive | Select-Object Model, InterfaceType, SerialNumber, Size, Status, PNPDeviceID
}

Save-ObjectAsTable -Title "Partitions" -Path (Join-Path $rawDir "partitions.txt") -ScriptBlock {
    Get-Partition | Select-Object DiskNumber, PartitionNumber, DriveLetter, Type, Size, GptType, IsBoot, IsSystem
}

Save-ObjectAsTable -Title "Volumes" -Path (Join-Path $rawDir "volumes.txt") -ScriptBlock {
    Get-Volume | Select-Object DriveLetter, FileSystem, HealthStatus, SizeRemaining, Size, Path
}

Save-ObjectAsTable -Title "Storage reliability counters" -Path (Join-Path $rawDir "storage_reliability.txt") -ScriptBlock {
    Get-PhysicalDisk | ForEach-Object {
        $pd = $_
        $rc = Safe-Get { Get-StorageReliabilityCounter -PhysicalDisk $pd }
        if ($rc) {
            [PSCustomObject]@{
                FriendlyName        = $pd.FriendlyName
                SerialNumber        = $pd.SerialNumber
                HealthStatus        = $pd.HealthStatus
                Temperature         = $rc.Temperature
                ReadErrorsTotal     = $rc.ReadErrorsTotal
                WriteErrorsTotal    = $rc.WriteErrorsTotal
                ReadLatencyMax      = $rc.ReadLatencyMax
                WriteLatencyMax     = $rc.WriteLatencyMax
                ReadLatencyAverage  = $rc.ReadLatencyAverage
                WriteLatencyAverage = $rc.WriteLatencyAverage
                Wear                = $rc.Wear
                PowerOnHours        = $rc.PowerOnHours
                UnsafeShutdownCount = $rc.UnsafeShutdownCount
                MediaErrors         = $rc.MediaErrors
            }
        }
        else {
            [PSCustomObject]@{
                FriendlyName        = $pd.FriendlyName
                SerialNumber        = $pd.SerialNumber
                HealthStatus        = $pd.HealthStatus
                Temperature         = $null
                ReadErrorsTotal     = $null
                WriteErrorsTotal    = $null
                ReadLatencyMax      = $null
                WriteLatencyMax     = $null
                ReadLatencyAverage  = $null
                WriteLatencyAverage = $null
                Wear                = $null
                PowerOnHours        = $null
                UnsafeShutdownCount = $null
                MediaErrors         = $null
            }
        }
    }
}

Save-CommandOutput -Title "WMIC disk status" -Path (Join-Path $rawDir "wmic_disk_status.txt") -ScriptBlock {
    cmd /c "wmic diskdrive get model,serialnumber,status,size"
}

Save-CommandOutput -Title "fsutil dirty query" -Path (Join-Path $rawDir "fsutil_dirty.txt") -ScriptBlock {
    cmd /c "fsutil dirty query $env:SystemDrive"
}

Save-CommandOutput -Title "BitLocker status" -Path (Join-Path $rawDir "bitlocker_status.txt") -ScriptBlock {
    manage-bde -status
}

# ---------------------------
# Filesystem / image integrity
# ---------------------------
Write-Section "Windows Integrity Checks"

Save-CommandOutput -Title "DISM CheckHealth" -Path (Join-Path $repairDir "dism_checkhealth.txt") -ScriptBlock {
    DISM /Online /Cleanup-Image /CheckHealth
}

Save-CommandOutput -Title "DISM ScanHealth" -Path (Join-Path $repairDir "dism_scanhealth.txt") -ScriptBlock {
    DISM /Online /Cleanup-Image /ScanHealth
}

$systemDrive = $env:SystemDrive

if ($RunChkdskScan) {
    Save-CommandOutput -Title "CHKDSK /scan" -Path (Join-Path $repairDir "chkdsk_scan.txt") -ScriptBlock {
        chkdsk $systemDrive /scan
    }
}
else {
    Save-Text -Path (Join-Path $repairDir "chkdsk_scan.txt") -Text "Skipped. Re-run with -RunChkdskScan to execute: chkdsk $systemDrive /scan"
}

if ($RunSfc) {
    Save-CommandOutput -Title "SFC /scannow" -Path (Join-Path $repairDir "sfc_scannow.txt") -ScriptBlock {
        sfc /scannow
    }
}
else {
    Save-Text -Path (Join-Path $repairDir "sfc_scannow.txt") -Text "Skipped. Re-run with -RunSfc to execute: sfc /scannow"
}

if ($RunDismRestoreHealth) {
    Save-CommandOutput -Title "DISM RestoreHealth" -Path (Join-Path $repairDir "dism_restorehealth.txt") -ScriptBlock {
        DISM /Online /Cleanup-Image /RestoreHealth
    }
}
else {
    Save-Text -Path (Join-Path $repairDir "dism_restorehealth.txt") -Text "Skipped. Re-run with -RunDismRestoreHealth to execute: DISM /Online /Cleanup-Image /RestoreHealth"
}

# ---------------------------
# Driver / firmware inventory
# ---------------------------
Write-Section "Drivers and Devices"

Save-CommandOutput -Title "Installed drivers" -Path (Join-Path $driversDir "driverquery.txt") -ScriptBlock {
    driverquery /v /fo csv
}

Save-ObjectAsTable -Title "Signed PnP drivers" -Path (Join-Path $driversDir "signed_drivers.txt") -ScriptBlock {
    Get-CimInstance Win32_PnPSignedDriver |
    Sort-Object DeviceName |
    Select-Object DeviceName, DriverVersion, DriverDate, Manufacturer, InfName
}

Save-ObjectAsTable -Title "Storage / disk / controller devices" -Path (Join-Path $driversDir "storage_devices.txt") -ScriptBlock {
    Get-PnpDevice | Where-Object {
        $_.Class -match 'DiskDrive|SCSIAdapter|HDC|Storage|System'
        -or $_.FriendlyName -match 'NVMe|Storage|Disk|Controller|Surface'
    } | Select-Object Status, Class, FriendlyName, InstanceId
}

Save-ObjectAsTable -Title "Surface-related drivers" -Path (Join-Path $driversDir "surface_related_drivers.txt") -ScriptBlock {
    Get-CimInstance Win32_PnPSignedDriver |
    Where-Object {
        $_.DeviceName -match 'Surface|UEFI|Firmware|NVMe|Storage'
        -or $_.Manufacturer -match 'Microsoft'
    } |
    Sort-Object DeviceName |
    Select-Object DeviceName, DriverVersion, DriverDate, Manufacturer, InfName
}

# ---------------------------
# Crash dump inventory
# ---------------------------
Write-Section "Crash Dump Inventory"

$minidumpPath = "C:\Windows\Minidump"
$memoryDmpPath = "C:\Windows\MEMORY.DMP"

if (Test-Path $minidumpPath) {
    Save-ObjectAsTable -Title "Minidump files" -Path (Join-Path $dumpsDir "minidumps.txt") -ScriptBlock {
        Get-ChildItem $minidumpPath -File |
        Sort-Object LastWriteTime -Descending |
        Select-Object Name, Length, CreationTime, LastWriteTime, FullName
    }

    try {
        Copy-Item "$minidumpPath\*" -Destination $dumpsDir -Force -ErrorAction Stop
        Write-Info "Copied minidumps to: $dumpsDir"
    }
    catch {
        Write-Warning "Could not copy minidumps: $($_.Exception.Message)"
    }
}
else {
    Save-Text -Path (Join-Path $dumpsDir "minidumps.txt") -Text "C:\Windows\Minidump not found."
}

if (Test-Path $memoryDmpPath) {
    Save-ObjectAsTable -Title "MEMORY.DMP info" -Path (Join-Path $dumpsDir "memory_dmp.txt") -ScriptBlock {
        Get-Item $memoryDmpPath | Select-Object Name, Length, CreationTime, LastWriteTime, FullName
    }
}
else {
    Save-Text -Path (Join-Path $dumpsDir "memory_dmp.txt") -Text "C:\Windows\MEMORY.DMP not found."
}

# ---------------------------
# Reliability and update history
# ---------------------------
Write-Section "Reliability and Update Signals"

Save-CommandOutput -Title "QuickFix Engineering (installed updates)" -Path (Join-Path $rawDir "installed_updates.txt") -ScriptBlock {
    Get-HotFix | Sort-Object InstalledOn -Descending | Format-Table -AutoSize
}

Save-ObjectAsTable -Title "Recent application crashes / WER events" -Path (Join-Path $eventsDir "wer_events.txt") -ScriptBlock {
    Get-WinEvent -FilterHashtable @{
        LogName   = 'Application'
        StartTime = $startTime
    } | Where-Object {
        $_.ProviderName -match 'Windows Error Reporting|Application Error'
    } | Select-Object TimeCreated, Id, ProviderName, Message
}

# ---------------------------
# Heuristic summary
# ---------------------------
Write-Section "Heuristic Findings"

$summaryFindings = New-Object System.Collections.Generic.List[string]

# Physical disk health
$physicalDisks = Safe-Get {
    Get-PhysicalDisk | Select-Object FriendlyName, HealthStatus, OperationalStatus
}

if ($physicalDisks) {
    foreach ($disk in $physicalDisks) {
        if ($disk.HealthStatus -ne 'Healthy' -or ($disk.OperationalStatus -notcontains 'OK' -and $disk.OperationalStatus -ne 'OK')) {
            $summaryFindings.Add("Disk health concern: $($disk.FriendlyName) | HealthStatus=$($disk.HealthStatus) | OperationalStatus=$($disk.OperationalStatus)")
        }
    }
}

# Reliability counters
$reliability = Safe-Get {
    Get-PhysicalDisk | ForEach-Object {
        $pd = $_
        $rc = Safe-Get { Get-StorageReliabilityCounter -PhysicalDisk $pd }
        if ($rc) {
            [PSCustomObject]@{
                FriendlyName        = $pd.FriendlyName
                MediaErrors         = $rc.MediaErrors
                ReadErrorsTotal     = $rc.ReadErrorsTotal
                WriteErrorsTotal    = $rc.WriteErrorsTotal
                UnsafeShutdownCount = $rc.UnsafeShutdownCount
                Temperature         = $rc.Temperature
            }
        }
    }
}

if ($reliability) {
    foreach ($r in $reliability) {
        if (($r.MediaErrors -as [int]) -gt 0 -or ($r.ReadErrorsTotal -as [int]) -gt 0 -or ($r.WriteErrorsTotal -as [int]) -gt 0) {
            $summaryFindings.Add("Storage reliability concern: $($r.FriendlyName) | MediaErrors=$($r.MediaErrors) | ReadErrorsTotal=$($r.ReadErrorsTotal) | WriteErrorsTotal=$($r.WriteErrorsTotal)")
        }
    }
}

# Event counts
$bugcheckCount = (Safe-Get {
        (Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 1001; StartTime = $startTime } | Measure-Object).Count
    }) ?? 0

$kernelPowerCount = (Safe-Get {
        (Get-WinEvent -FilterHashtable @{ LogName = 'System'; Id = 41; StartTime = $startTime } | Measure-Object).Count
    }) ?? 0

$diskEventCount = (Safe-Get {
        (Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $startTime } |
        Where-Object { $_.ProviderName -match 'disk|storahci|stornvme|Ntfs|volmgr|volsnap' } |
        Measure-Object).Count
    }) ?? 0

$summaryFindings.Add("BugCheck events in last $DaysBack days: $bugcheckCount")
$summaryFindings.Add("Kernel-Power 41 events in last $DaysBack days: $kernelPowerCount")
$summaryFindings.Add("Disk / NTFS / storage-related events in last $DaysBack days: $diskEventCount")

if (Test-Path $minidumpPath) {
    $dumpCount = (Get-ChildItem $minidumpPath -File | Measure-Object).Count
    $summaryFindings.Add("Minidump files present: $dumpCount")
}

if ($summaryFindings.Count -eq 0) {
    $summaryFindings.Add("No obvious storage-health indicators were detected by the script. Review event logs, dump files, and repair output manually.")
}

$summaryFindings | ForEach-Object {
    Write-Info "- $_"
}

# ---------------------------
# Final guidance
# ---------------------------
Write-Section "Recommended Next Steps"

$nextSteps = @(
    "1. Review: events\bugcheck_events.txt and events\disk_related_events.txt",
    "2. Review: raw\storage_reliability.txt and raw\physical_disks.txt",
    "3. If disk or NTFS errors are present, run again with -RunChkdskScan",
    "4. If Windows integrity issues are suspected, run again with -RunSfc and optionally -RunDismRestoreHealth",
    "5. If crashes repeat, inspect files in dumps\ and consider warranty / hardware replacement",
    "6. Make sure Windows Update and Surface firmware are fully current"
)

$nextSteps | ForEach-Object { Write-Info $_ }

Write-Info ""
Write-Info "Completed: $(Get-Date)"
Write-Info "All output saved to: $OutputDir"
