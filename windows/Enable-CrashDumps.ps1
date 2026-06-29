<# 
Enable-CrashDumps.ps1
Run as Administrator. Configures Windows to reliably write BSOD crash dumps.
#>

#-------------------------------#
# Helpers
#-------------------------------#
function Require-Admin {
  if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "Please run this script in an elevated PowerShell (Run as Administrator)."
    exit 1
  }
}

function Set-RegistryValue {
  param(
    [Parameter(Mandatory=$true)][string] $Path,
    [Parameter(Mandatory=$true)][string] $Name,
    [Parameter(Mandatory=$true)] $Value,
    [Microsoft.Win32.RegistryValueKind] $Type = [Microsoft.Win32.RegistryValueKind]::String
  )
  if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
  New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force | Out-Null
}

function Ensure-Folder {
  param([Parameter(Mandatory=$true)][string] $Path)
  if (-not (Test-Path $Path)) { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
}

#-------------------------------#
# Start
#-------------------------------#
Require-Admin
Write-Host "=== Configuring BSOD crash dump collection ===" -ForegroundColor Cyan

# 1) Crash dump + BSOD behavior
$crashKey = "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"

# Disable automatic restart after failure
Set-RegistryValue -Path $crashKey -Name "AutoReboot" -Value 0 -Type DWord

# Enable Small memory dump (256 KB) [3]. Reliable and sufficient for WHEA triage.
# (0=None, 1=Complete, 2=Kernel, 3=Small, 7=Automatic)
Set-RegistryValue -Path $crashKey -Name "CrashDumpEnabled" -Value 3 -Type DWord

# Overwrite any existing dump if needed; log an event on crash
Set-RegistryValue -Path $crashKey -Name "Overwrite" -Value 1 -Type DWord
Set-RegistryValue -Path $crashKey -Name "LogEvent"  -Value 1 -Type DWord

# Minidump directory
$minidump = "C:\Windows\Minidump"
Ensure-Folder $minidump
Set-RegistryValue -Path $crashKey -Name "MinidumpDir" -Value $minidump -Type ExpandString

# Make sure SYSTEM can write there (usually already true, but ensure just in case)
icacls $minidump /grant "*S-1-5-18:(OI)(CI)(F)" /T | Out-Null  # *S-1-5-18 = SYSTEM SID

# Optional: alternative icacls command to only grant Modify (M) rights instead of Full (F)
# icacls $minidump /grant "*S-1-5-18:(M)" | Out-Null

# 2) Pagefile: ensure system-managed sizing on the system drive (via explicit entry)
$mmKey = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

Set-RegistryValue -Path $mmKey -Name "PagingFiles"       -Value @("$($env:SystemDrive)\pagefile.sys 0 0") -Type ([Microsoft.Win32.RegistryValueKind]::MultiString)
Set-RegistryValue -Path $mmKey -Name "ExistingPageFiles" -Value @("$($env:SystemDrive)\pagefile.sys")     -Type ([Microsoft.Win32.RegistryValueKind]::MultiString)
Set-RegistryValue -Path $mmKey -Name "TempPageFile"      -Value 0 -Type DWord

# (Optional) Remove/skip the AutomaticManagedPagefile toggle to avoid mixed modes
# try {
#   $cs = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
#   if ($cs.AutomaticManagedPagefile -ne $false) {
#     $null = Set-CimInstance -InputObject $cs -Property @{ AutomaticManagedPagefile = $false } -ErrorAction Stop
#   }
# } catch { }

# 3) Sanity checks
Write-Host "`n=== Verifying configuration ===" -ForegroundColor Cyan

# Check free space on C:
try {
  $cDrive = Get-PSDrive -Name C -ErrorAction Stop
  $freeGB = [math]::Round($cDrive.Free/1GB,2)
  Write-Host ("Free space on C: {0} GB" -f $freeGB)
  if ($cDrive.Free -lt 2GB) {
    Write-Warning "Less than 2 GB free on C:. Low free space can block dump writing."
  }
} catch {
  Write-Warning "Could not query free space on C: $_"
}

# Check pagefile presence (post-reboot it will be active)
try {
  $pf = Get-CimInstance Win32_PageFileUsage -ErrorAction SilentlyContinue
  if ($pf) {
    $pf | ForEach-Object {
      Write-Host ("Pagefile: {0} (PeakUsageMB={1})" -f $_.Name, $_.PeakUsage)
    }
  } else {
    Write-Warning "Win32_PageFileUsage returned no entries (expected before reboot)."
  }
} catch {
  Write-Warning "Could not query Win32_PageFileUsage. $_"
}

# Confirm registry values
$dumpType = (Get-ItemProperty $crashKey -Name CrashDumpEnabled).CrashDumpEnabled
$autoReboot = (Get-ItemProperty $crashKey -Name AutoReboot).AutoReboot
$dumpDir = (Get-ItemProperty $crashKey -Name MinidumpDir).MinidumpDir
$paging = (Get-ItemProperty $mmKey -Name PagingFiles).PagingFiles

Write-Host "`nDump type: $dumpType (3 = Small dump)"
Write-Host "Auto-restart disabled: $([bool]($autoReboot -eq 0))"
Write-Host "Minidump directory: $dumpDir"
Write-Host "PagingFiles: $paging"
Write-Host "`nMinidump ACL check:"
icacls $minidump | Out-String | Write-Host

Write-Host "`n=== Done ===" -ForegroundColor Green
Write-Host "Please REBOOT now to finalize pagefile settings."
Write-Host "After the next BSOD, check for files in: $minidump"