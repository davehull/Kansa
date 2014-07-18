<#
.SYNOPSIS
Get-ProcDump.ps1 acquires a Sysinternal procdump of the specified 
process
.PARAMETER ProcId
A required parameter, the process id of the process you want to dump.
.NOTES
When used with Kansa.ps1, parameters must be positional. Named params
are not supported.
.EXAMPLE
Get-ProcDump.ps1 104

When passing specific modules with parameters via Kansa.ps1's
-ModulePath parameter, be sure to quote the entire string, like 
shown here:
.\kansa.ps1 -Target localhost -ModulePath ".\Modules\Process\Get-ProcDumpe.ps1 104"

Arguments passed via Modules\Modules.conf should not be quoted.

Multiple arguments may be passed with comma separators.

If you have procdump.exe in your Modules\bin\ path and run Kansa with 
the -Pushbin flag, Kansa will attempt to copy the binary to the ADMIN$.
Binaries aren't removed unless Kansa.ps1 is run with the -rmbin switch.

Also, you should configure this to dump the process you're interested
in. By default it dumps itself, which is probably not what you want.

.NOTES
Kansa.ps1 output and bindep directives follow:
OUTPUT bin
BINDEP .\Modules\bin\Procdump.exe
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [Int]$ProcId=$pid
)

if (Test-Path "$env:SystemRoot\Procdump.exe") {
    $PDOutput = & $env:SystemRoot\Procdump.exe /accepteula $ProcId 2> $null
    foreach($line in $PDOutput) {
        if ($line -match 'Writing dump file (.*\.dmp) ...') {
            Get-Content -ReadCount 0 -Raw -Encoding Byte $($matches[1])
            Remove-Item $($matches[1])
        }
    }
}