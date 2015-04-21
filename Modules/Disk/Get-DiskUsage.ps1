<#
.SYNOPSIS
Get-DiskUsage.ps1 returns output of Sysinternals' du.exe, which shows disk usage on a per directory basis.

OUTPUT tsv
BINDEP .\Modules\bin\du.exe

!!THIS SCRIPT ASSUMES DU.EXE WILL BE IN $ENV:SYSTEMROOT!!
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=1)]
        [String]$BasePath="C:\"
)


if (Test-Path "$env:SystemRoot\du.exe") {
    & $env:SystemRoot\du.exe -q -c -l 3 $BasePath 2> $null | ConvertFrom-Csv
} else {
    Write-Error "du.exe not found in $env:SystemRoot."
}