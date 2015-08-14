<#
.SYNOPSIS
Get-ClrVersion.ps1 returns 

.NOTES
This script does depend on clrver.exe, which is not packaged with Kansa. It is,
however, installed automatically with Visual Studio. When you run Kansa.ps1, if
you add the -Pushbin switch at the command line, Kansa.ps1 will attempt to copy
the clrver.exe binary to each remote target's ADMIN$ share.

If you want to remove the binary from remote systems after it has run,
add the -rmbin switch to Kansa.ps1's command line.

If you run Kansa.ps1 without the -rmbin switch, binaries pushed to 
remote hosts will be left beind and will be available on subsequent
runs, obviating the need to run with -Pushbin in the future.

The following lines are required by Kansa.ps1. They are directives that
tell Kansa how to treat the output of this script and where to find the
binary that this script depends on.
OUTPUT tsv
BINDEP .\Modules\bin\clrver.exe

!!THIS SCRIPT ASSUMES CLRVER.EXE WILL BE IN $ENV:SYSTEMROOT!!
#>

if (Test-Path "$env:SystemRoot\clrver.exe") {
    $counter = 0
    & $env:SystemRoot\clrver.exe -all 2> $null | `
        ConvertFrom-Csv -Delimiter `t -Header "PID","ProcessName","CLR Version" | `
        ForEach-Object {
            if ($counter -gt 1) { # Skip the first two rows of output.
                $_
            }
            $counter += 1
        }
} else {
    Write-Error "Clrver.exe not found in $env:SystemRoot."
}