<#

THIS SCRIPT NEEDS TO PLACED ONTO THE LOCAL MACHINE AND IS INVOKED VIA THE Remove-AvdSessionHostFromDomain Function in the core module.

#>


[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)][string]$DomainUserName,
    [Parameter(Mandatory = $true)][string]$DomainPassword
)

$root = "LDAP://$((Get-WmiObject -Namespace root\cimv2 -Class Win32_ComputerSystem | Select-Object Name, Domain).Domain)"

try { 
    $domain = New-Object System.DirectoryServices.DirectoryEntry($root, $DomainUserName, $DomainPassword) -ErrorAction Stop
    $search = New-Object -TypeName System.DirectoryServices.DirectorySearcher($domain) -ErrorAction Stop
}
catch {
    Write-Error "Error: unable to create new objects. $($_.Exception.Message)"
}

$search.filter = "(&(ObjectCategory=Computer)(ObjectClass=Computer)((cn=$($env:computername))))" 
$computer = $search.FindOne()
$dnc = $computer.GetDirectoryEntry()                           
$dnc.DeleteTree()
