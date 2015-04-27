<#
.SYNOPSIS
BINDEP .\Modules\bin\Procdump.exe
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [Int]$ProcId=$pid
)

$datestr = (Get-Date -Format "yyyyMMddHHmmss")
$outfile = "${pwd}\" + ($env:COMPUTERNAME) + "_PId_" + ($pid) + "_${datestr}.dmp"

$obj = "" | Select-Object PId,Base64EncodedGzippedBytes
$obj.PId = $ProcId

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
        $InputFile.Close()
        Remove-Item $File # Delete our dmp file from disk
    }
    # return our data
    $obj 
}
