[CmdletBinding()]
param(
    [Parameter()]
    [string]$GroupName = "Domain Admins",

    [Parameter()]
    [string]$StateDirectory = (Join-Path $env:ProgramData "ScriptSecurity\ADGroupMonitor")
)

$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory -ErrorAction Stop

function Protect-CsvValue {
    param([AllowNull()][object]$Value)

    $text = [string]$Value
    if ($text -match '^[=+\-@]') {
        return "'$text"
    }
    return $text
}

function Set-RestrictedDirectoryAcl {
    param([Parameter(Mandatory)][string]$Path)

    $acl = Get-Acl -LiteralPath $Path
    $acl.SetAccessRuleProtection($true, $false)
    foreach ($rule in @($acl.Access)) {
        [void]$acl.RemoveAccessRuleAll($rule)
    }

    $identities = @(
        "NT AUTHORITY\SYSTEM",
        "BUILTIN\Administrators",
        [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    ) | Select-Object -Unique

    foreach ($identity in $identities) {
        $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
            $identity,
            [System.Security.AccessControl.FileSystemRights]::FullControl,
            [System.Security.AccessControl.InheritanceFlags]"ContainerInherit, ObjectInherit",
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        )
        $acl.AddAccessRule($rule)
    }
    Set-Acl -LiteralPath $Path -AclObject $acl
}

function ConvertTo-StateRecord {
    param([Parameter(Mandatory)]$DirectoryObject)

    [pscustomobject]@{
        Name           = Protect-CsvValue $DirectoryObject.Name
        SamAccountName = Protect-CsvValue $DirectoryObject.SamAccountName
        DN             = Protect-CsvValue $DirectoryObject.DistinguishedName
        ObjectClass    = Protect-CsvValue $DirectoryObject.ObjectClass
    }
}

if (-not (Test-Path -LiteralPath $StateDirectory)) {
    New-Item -Path $StateDirectory -ItemType Directory -Force | Out-Null
}
$StateDirectory = (Resolve-Path -LiteralPath $StateDirectory).Path
Set-RestrictedDirectoryAcl -Path $StateDirectory

$group = Get-ADGroup -Identity $GroupName -ErrorAction Stop
$safeGroupName = $group.SamAccountName -replace '[^A-Za-z0-9_.-]', '_'
$stateFile = Join-Path $StateDirectory "$safeGroupName-membership.csv"

$members = @(
    Get-ADGroupMember -Identity $group -Recursive -ErrorAction Stop |
        Where-Object { $_.ObjectClass -in @("user", "computer", "group") } |
        ForEach-Object { ConvertTo-StateRecord $_ } |
        Sort-Object ObjectClass, SamAccountName, DN
)

if (Test-Path -LiteralPath $stateFile) {
    $previous = @(Import-Csv -LiteralPath $stateFile)
    $changes = Compare-Object `
        -ReferenceObject $previous `
        -DifferenceObject $members `
        -Property Name, SamAccountName, DN, ObjectClass |
        ForEach-Object {
            [pscustomobject]@{
                DateTime      = Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"
                State         = if ($_.SideIndicator -eq "=>") { "Added" } else { "Removed" }
                Name          = $_.Name
                SamAccountName = $_.SamAccountName
                DN            = $_.DN
                ObjectClass   = $_.ObjectClass
            }
        }
    $changes
}

$temporaryFile = Join-Path $StateDirectory ([System.IO.Path]::GetRandomFileName())
try {
    $members | Export-Csv -LiteralPath $temporaryFile -NoTypeInformation -Encoding Unicode
    Move-Item -LiteralPath $temporaryFile -Destination $stateFile -Force
}
finally {
    if (Test-Path -LiteralPath $temporaryFile) {
        Remove-Item -LiteralPath $temporaryFile -Force
    }
}
