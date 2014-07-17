<#
.SYNOPSIS
Get-SmbShare.ps1 returns information about SMB Shares, which could be
created by adversaries for data collection points.
.NOTES
The next line is required by Kansa.ps1, it tells Kansa how to handle 
the output returned.
OUTPUT TSV
#>

if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
    Get-SmbShare
}