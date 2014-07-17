<#
.SYNOPSIS
Get-SmbSession.ps1 returns smb sessions connected to this host.

.NOTES
Next line needed by Kansa.ps1 for handling this scripts output.
OUTPUT TSV
#>

if (Get-Command Get-SmbSession -ErrorAction SilentlyContinue) {
    Get-SmbSession
}