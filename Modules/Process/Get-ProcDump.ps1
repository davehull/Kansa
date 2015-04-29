<#
.SYNOPSIS
Get-ProcDump.ps1 acquires memory dump of the specified process
.DESCRIPTION
Uses Sysinternal's procdump.exe to write a dmp file to disk. That file
is read into a memory stream and compressed using GZipStream, then
Base64 encoded and stored in an object property and returned.
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

If you have procdump.exe in your Modules\bin\ path and run Kansa with 
the -Pushbin flag, Kansa will attempt to copy the binary to the ADMIN$.
Binaries aren't removed unless Kansa.ps1 is run with the -rmbin switch.

Also, you should configure this to dump the process you're interested
in. By default it dumps itself, which is probably not what you want.

.NOTES
Kansa.ps1 bindep directive follows:
BINDEP .\Modules\bin\Procdump.exe
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [Int]$ProcId=$pid
)

$datestr = (Get-Date -Format "yyyyMMddHHmmss")
$outfile = "${pwd}\" + ($env:COMPUTERNAME) + "_PId_" + ($pid) + "_${datestr}.dmp"

$obj = "" | Select-Object Path,PId,Base64EncodedGzippedBytes
$obj.PId = $ProcId
$obj.ProcessName = (Get-Process -Id $ProcId).Path

if (Test-Path "$env:SystemRoot\Procdump.exe") {
    # Dump specified process memory to file on disk named $outfile
    $Suppress = & $env:SystemRoot\Procdump.exe /accepteula $ProcId $outfile 2> $null
    $File = ls $outfile # Create a file object         
    Try {
        # Read file object's contents into memory stream
        $memFile = New-Object System.IO.MemoryStream (,[System.IO.File]::ReadAllBytes($File))

        # Create an empty memory stream to store our GZipped bytes in
        $memStrm = New-Object System.IO.MemoryStream

        # Create a GZipStream with $memStrm as its underlying storage
        $gzStrm  = New-Object System.IO.Compression.GZipStream $memStrm, ([System.IO.Compression.CompressionMode]::Compress)

        # Pass $memFile's bytes through the GZipstream into the $memStrm
        $gzStrm.Write($memFile.ToArray(), 0, $File.Length)
        $gzStrm.Close()
        $gzStrm.Dispose()

        # Base64 encode the compressed bytes, store them in our object
        $obj.Base64EncodedGzippedBytes = [System.Convert]::ToBase64String($memStrm.ToArray())
    } Catch {
        Write-Error ("Caught Exception: {0}." -f $_)
    } Finally {
        Remove-Item $File # Delete our dmp file from disk
    }
    # return our data
    $obj 
}