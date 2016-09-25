<#
.SYNOPSIS
Get-Autorunsc.ps1 returns output from the Sysinternals' Autorunsc.exe
utility, which pulls information about many well-known Auto-Start
Extension Points from Windows systems. ASEPs are commonly used as
persistence mechanisms for adversaries.

This script does depend on Sysinternals' Autorunsc.exe, which is not
packaged with Kansa. You will have to download it from Sysinternals and
drop it in the .\Modules\bin\ directory. When you run Kansa.ps1, if you
add the -Pushbin switch at the command line, Kansa.ps1 will attempt to 
copy the Autorunsc.exe binary to each remote target's ADMIN$ share.

If you want to remove the binary from remote systems after it has run,
add the -rmbin switch to Kansa.ps1's command line.

If you run Kansa.ps1 without the -rmbin switch, binaries pushed to 
remote hosts will be left beind and will be available on subsequent
runs, obviating the need to run with -Pushbin in the future.

.NOTES
The following lines are required by Kansa.ps1. They are directives that
tell Kansa how to treat the output of this script and where to find the
binary that this script depends on.
OUTPUT tsv
BINDEP .\Modules\bin\Autorunsc.exe

!!THIS SCRIPT ASSUMES AUTORUNSC.EXE WILL BE IN $ENV:SYSTEMROOT!!

Autorunsc output is a mess. Some of it is quoted csv, some is just csv.
This script parses it pretty well, but there are still some things that
are incorrectly parsed. As I have time, I'll see about resolving the 
troublesome entries, one in particular is for items that don't have 
time stamps.
#>

if (Test-Path "$env:SystemRoot\Autorunsc.exe") {
    & $env:SystemRoot\Autorunsc.exe /accepteula -a * -c -h -s '*' -nobanner 2> $null | ConvertFrom-Csv | ForEach-Object {
        $_
    }
} else {
    Write-Error "Autorunsc.exe not found in $env:SystemRoot."
}
