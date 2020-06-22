# Monitor-ADGroupMemberChanges
#
# 1. Get members.
# 2. Compare to previous members. 
# 3. Output changes.
#
# Credit to https://github.com/lazywinadmin/Monitor-ADGroupMembership
# Portions Copyright (c) 2015 Francois-Xavier Cat

# The MIT License (MIT)

# Copyright (c) 2020 Benjamin Hunter
# Copyright (c) 2015 Francois-Xavier Cat

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

#######################################
# Simple version


$item = "Domain Admins"
$ScriptName = $MyInvocation.MyCommand
$ScriptPath = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$ScriptPathOutput = $ScriptPath + "\Output"

$MemberObjs = Get-ADGroupMember -Identity $item -Recursive -ErrorAction Stop
[Array]$Members = $MemberObjs | Where-Object {$_.objectClass -eq "user" } | Get-ADUser -Properties PasswordExpired | Select-Object -Property *,@{ Name = 'DN'; Expression = { $_.DistinguishedName } }
$Members += $MemberObjs | Where-Object {$_.objectClass -eq "computer" } | Get-ADComputer -Properties PasswordExpired | Select-Object -Property *,@{ Name = 'DN'; Expression = { $_.DistinguishedName } }

# Load previous membership
$ImportCSV = Import-Csv -Path (Join-Path -Path $ScriptPathOutput -ChildPath $StateFile) -ErrorAction Stop -ErrorVariable ErrorProcessImportCSV

# Write twice - time stamped and reference file for next comparison.
$Members | Export-Csv -Path (Join-Path -Path $ScriptPathOutput -ChildPath ($StateFile + (Get-Date -Format FileDateTimeUniversal)) -NoTypeInformation -Encoding Unicode
$Members | Export-Csv -Path (Join-Path -Path $ScriptPathOutput -ChildPath $StateFile) -NoTypeInformation -Encoding Unicode

$Changes = Compare-Object -DifferenceObject $ImportCSV -ReferenceObject $Members -ErrorAction Stop -ErrorVariable ErrorProcessCompareObject -Property Name, SamAccountName, DN |
Select-Object -Property @{ Name = "DateTime"; Expression = { Get-Date -Format "yyyyMMdd-hh:mm:ss" } }, @{
    Name = 'State'; expression = {
        if ($_.SideIndicator -eq "=>") { "Removed" }
        else { "Added" }
    }
}, DisplayName, Name, SamAccountName, DN | Where-Object { $_.name -notlike "*no user or group*" }

Write-Output $Changes



#######################################
# Work in progress
# Based on https://github.com/lazywinadmin/Monitor-ADGroupMembership




$item = "Domain Admins"

$ScriptName = $MyInvocation.MyCommand
$ScriptPath = (Split-Path -Path ((Get-Variable -Name MyInvocation).Value).MyCommand.Path)
$ScriptPathOutput = $ScriptPath + "\Output"

if (-not(Test-Path -Path $ScriptPathOutput))
{
    Write-Verbose -Message "[$ScriptName][Begin] Creating the Output Folder : $ScriptPathOutput"
    New-Item -Path $ScriptPathOutput -ItemType Directory | Out-Null
}

$GroupName = Get-ADGroup @GroupSplatting -Properties * -ErrorAction Continue -ErrorVariable ErrorProcessGetADGroup
Write-Verbose -Message "[$ScriptName][Process] Extracting Domain Name from $($GroupName.CanonicalName)"
$DomainName = ($GroupName.CanonicalName -split '/')[0]
$RealGroupName = $GroupName.Name

$MemberObjs = Get-ADGroupMember -Identity $item -Recursive -ErrorAction Stop
[Array]$Members = $MemberObjs | Where-Object {$_.objectClass -eq "user" } | Get-ADUser -Properties PasswordExpired | Select-Object -Property *,@{ Name = 'DN'; Expression = { $_.DistinguishedName } }
$Members += $MemberObjs | Where-Object {$_.objectClass -eq "computer" } | Get-ADComputer -Properties PasswordExpired | Select-Object -Property *,@{ Name = 'DN'; Expression = { $_.DistinguishedName } }

# GroupName Membership File
# if the file doesn't exist, assume we don't have a record to refer to
$StateFile = "$($DomainName)_$($RealGroupName)-membership.csv"

if (-not (Test-Path -Path (Join-Path -Path $ScriptPathOutput -ChildPath $StateFile)))
{
    Write-Verbose -Message "[$ScriptName][Process] $item - The following file did not exist: $StateFile"
    Write-Verbose -Message "[$ScriptName][Process] $item - Exporting the current membership information into the file: $StateFile"

    $Members | Export-Csv -Path (Join-Path -Path $ScriptPathOutput -ChildPath $StateFile) -NoTypeInformation -Encoding Unicode
}
else
{
    Write-Verbose -Message "[$ScriptName][Process] $item - The following file exists: $StateFile"
}

# GroupName Membership File is compared with the current GroupName Membership
Write-Verbose -Message "[$ScriptName][Process] $item - Comparing Current and Before"

$ImportCSV = Import-Csv -Path (Join-Path -Path $ScriptPathOutput -ChildPath $StateFile) -ErrorAction Stop -ErrorVariable ErrorProcessImportCSV

$Changes = Compare-Object -DifferenceObject $ImportCSV -ReferenceObject $Members -ErrorAction Stop -ErrorVariable ErrorProcessCompareObject -Property Name, SamAccountName, DN |
Select-Object -Property @{ Name = "DateTime"; Expression = { Get-Date -Format "yyyyMMdd-hh:mm:ss" } }, @{
    Name = 'State'; expression = {
        if ($_.SideIndicator -eq "=>") { "Removed" }
        else { "Added" }
    }
}, DisplayName, Name, SamAccountName, DN | Where-Object { $_.name -notlike "*no user or group*" }

Write-Verbose -Message "[$ScriptName][Process] $item - Compare Block Done!"






