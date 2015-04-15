<#
.SYNOPSIS
Get-Sigcheck.ps1 returns output from the SysInternals' sicheck.exe utility

.NOTES
OUTPUT tsv
BINDEP .\Modules\bin\sigcheck.exe

!! THIS SCRIPT ASUMES SIGCHECK.EXE WILL BE IN $ENV:SYSTEMROOT !!
#>

if (Test-Path "$env:SystemRoot\sigcheck.exe") {
    & $env:SystemRoot\sigcheck.exe /accepteula -a -e -c -h -q -s -r $("$env:SystemDrive\") 2> $null | 
        ConvertFrom-Csv |
            ForEach-Object { $_ }
}
else {
    Write-Error "Sigcheck.exe not found in $env:SystemRoot."
}