<#
.SYNOPSIS
Get-CertStore.ps1 uses Sysinternals' sigcheck.exe to acquire data about
hosts' certificate stores.

!! Get-CertStore.ps1 requires Sysinternals' sigcheck.exe to be in the 
ADMIN$ share of remote hosts !!

Sigcheck.exe is not packaged with Kansa. You must download it from 
Sysinternals and drop it in .\Modules\bin\, then if you run Kansa.ps1 
with the -Pushbin flag, it will attempt to copy sigcheck.exe to the 
ADMIN$ share of remote hosts (targets).

Running Kansa.ps1 with the -rmbin flag will cause Kansa to attempt to
remove binaries that were copied to remote hosts via -Pushbin.
Alternatively, you can leave the binaries on remote hosts and future
Kansa runs may not require the -Pushbin flag.

.NOTES
The following lines are required by Kansa.ps1. The first is an OUTPUT
directive that tells Kansa how to tread the output from this script.
The second tells Kansa where to find the sigcheck binary so it can copy
it to targets when run with the -Pushbin flag.
OUTPUT txt
BINDEP .\Modules\bin\sigcheck.exe
#>

if (Test-Path "$env:SystemRoot\sigcheck.exe") {
    & $env:SystemRoot\sigcheck.exe /accepteula -q -t '*'
} else {
    "sigcheck.exe not found on $env:COMPUTERNAME"
}    