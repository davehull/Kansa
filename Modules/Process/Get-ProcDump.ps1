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
OUTPUT csv
BINDEP .\Modules\bin\Procdump.exe
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [Int]$ProcId=$pid
)

$datestr = (Get-Date -Format "yyyyMMddHHmmss")
$outfile = "${pwd}\" + ($env:COMPUTERNAME) + "_PId_" + ($pid) + "_${datestr}.dmp"
$outgz   = $outfile + ".gz"

$obj = "" | Select-Object PId,Base64EncodedGzippedBytes
$obj.PId = $ProcId

if (Test-Path "$env:SystemRoot\Procdump.exe") {
    $Suppress = & $env:SystemRoot\Procdump.exe /accepteula $ProcId $outfile 2> $null
    $File = ls $outfile           
    Try {
        $InputFile  = New-Object System.IO.FileStream $File, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
        $buffer     = New-Object byte[]($InputFile.Length)

        $suppress   = $InputFile.Read($buffer, 0, $InputFile.Length)

        $DmpGZipped = New-Object System.IO.FileStream $outgz, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
        # $DmpGZipped = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.GzipStream $DmpGZipped, ([IO.Compression.CompressionMode]::Compress)
        $gzipStream.Write($buffer, 0, $buffer.Length)
        $gzipStream.Close()

        $GZFile = ls $outgz

        $buffer = [System.IO.File]::ReadAllBytes($GZFile)        
        $obj.Base64EncodedGzippedBytes = [System.Convert]::ToBase64String($buffer)

        # $obj.Bytes = [System.Convert]::ToBase64String($buffer)
        # Get-Content -ReadCount 0 -Raw -Encoding Byte $File.FullName
    } Catch {
        Write-Error ("Caught Exception: {0}." -f $_)
    } Finally {
        $InputFile.Close()
        Remove-Item $File
        Remove-Item $GZFile
    }
    $obj
}