# OUTPUT txt
# BINDEP Autorunsc.exe
<#
.SYNOPSIS
Get-Autorunsc.ps1 depends on Sysinternals Autorunsc.exe, Kansa.ps1 should recognize this
based on line two of this script and will attempt to copy it from $ModulePath\bin\ to the 
remote system's ADMIN$ share. If the ADMIN$ share does not exist, the copy will fail and
the module will be skipped.

Users will have to download Autorunsc.exe or any other binaries separately, they are not
included with Kansa.

!!THIS SCRIPT ASSUMES AUTORUNSC.EXE WILL BE IN $ENV:SYSTEMROOT!!

If you have autorunsc.exe in your Modules\bin\ path and run the script with the -Pushbin
flag, Kansa will attempt to copy the binary to the ADMIN$. Binaries are not removed, so
subsequent runs won't require -Pushbin.
#>

if (Test-Path "$env:SystemRoot\Autorunsc.exe") {
    & $env:SystemRoot\Autorunsc.exe /accepteula -a -v -c -f '*' 2> $null
} else {
    Write-Error "Autorunsc.exe not found in $env:SystemRoot."
}