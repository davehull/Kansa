# OUTPUT bin
# BINDEP Procdump.exe
<#
Get-ProcDump
Acquires a Sysinternal procdump of the specified process

If you have procdump.exe in your Modules\bin\ path and run Kansa with the -Pushbin
flag, Kansa will attempt to copy the binary to the ADMIN$. Binaries are not removed, so
subsequent runs won't require -Pushbin.

Also, you should configure this to dump the process you're 
interested in. By default it dumps itself, which is probably
not what you want.
#>

# Replace $pid with the process id you wish to capture.
$ProcId = $pid

if (Test-Path "$env:SystemRoot\Procdump.exe") {
    $PDOutput = & $env:SystemRoot\Procdump.exe /accepteula $ProcId 2> $null
    foreach($line in $PDOutput) {
        if ($line -match 'Writing dump file (.*\.dmp) ...') {
            Get-Content -ReadCount 0 -Raw -Encoding Byte $($matches[1])
            Remove-Item $($matches[1])
        }
    }
}