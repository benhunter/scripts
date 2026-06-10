function Watch-Command {
  [CmdletBinding()]
  param (
    [Parameter(Mandatory)]
    [scriptblock]$Command,

    [ValidateRange(1, 86400)]
    [int]$Interval = 2,

    [switch]$Clear
  )

  while ($true) {
    if ($Clear) {
      Clear-Host
    }
    Get-Date
    "Command: $Command"
    "Interval: $Interval"
    & $Command
    Start-Sleep -Seconds $Interval
  }
}
