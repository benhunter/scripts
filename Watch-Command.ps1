# Watch-Command.ps1 -Command "Get-Process" -Interval 2 -Clear
# Add to PowerShell profile: Set-Alias -Name watch -Value Watch-Command
# Add to PowerShell profile: Set-Alias -Name w -Value Watch-Command
# 
# Open your PowerShell profile: notepad $profile
# copy and paste the following code into your PowerShell profile

function Watch-Command {
  param (
    [string]$Command,
    [int]$Interval = 2,
    [switch]$Clear = $false
  )

  while ($true) {
    if ($Clear) {
      Clear-Host
    }
    Get-Date
    "Command: $Command"
    "Interval: $Interval"
    "Clear: $Clear"
    Invoke-Expression $Command
    Start-Sleep -Seconds $Interval
  }
}
