<# 
.SYNOPSIS
Get-LogWinEvent
.PARAMETER LogName
A required parameter, that names the event log to acquire data from.
To see a list of common lognames run:
Get-WinEvent -ListLog | Select LogName

When used with Kansa.ps1, parameters must be positional. Named params
are not supported.
.EXAMPLE
Get-LogWinEvent.ps1 Security
.NOTES
When passing specific modules with parameters via Kansa.ps1's
-ModulePath parameter, be sure to quote the entire string, like shown
here:
.\kansa.ps1 -Target localhost -ModulePath ".\Modules\Log\Get-LogWinEvent.ps1 Security"

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$LogName
)

Get-WinEvent -LogName $LogName