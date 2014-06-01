# OUTPUT txt
# BINDEP sigcheck.exe
<#
.SYNOPSIS
Get-CertStore.ps1
Uses Sysinternals sigcheck.exe to dump the contents of remote system's certificate
stores.

Requires sigcheck.exe from Sysinternals. If you copy it to to the Modules\bin\ directory
and run Kansa with the -Pushbin option the sigcheck binary will be copied to remote
host's ADMIN$ shares. Alternatively, you can pre-install sigcheck.exe in the ADMIN$
share of targets and run without the -Pushbin argument.
#>

if (Test-Path "$env:SystemRoot\sigcheck.exe") {
    & $env:SystemRoot\sigcheck.exe /accepteula -q -t '*'
} else {
    "sigcheck.exe not found on $env:COMPUTERNAME"
}    