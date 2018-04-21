<#
.SYNOPSIS
Get-GPResult.ps1 returns GPResult data
.DESCRIPTION
Get-GPResult.ps1 wraps Get-GPResultantSetOfPolicy to acquire the GPO
settings from the target. 

This collector does write data to disk on the target, this could 
overwrite forensically interesting evidence in the unallocated space on
the target.

After writing the data to disk as XML, this script will read the XML
into memory, create a GZip stream of the data, then base64 encoded that
byte stream and assign it to an object property that will be sent back
to the collector host where Kansa.ps1 was run.
.NOTES
Original concept contributed by Mike Fanning
The method used in this script comes from:
http://blogs.technet.com/b/heyscriptingguy/archive/2013/02/08/use-powershell-to-find-group-policy-rsop-data.aspx
I wish there was a way to get this data without writing it to disk.
$data = GPResult.exe /v would work, but the output is not formated in
a way that lends itself to scalable analysis.
#>



function GetBase64GzippedStream {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [System.IO.FileInfo]$File
)
    # Read profile into memory stream
    $memFile = New-Object System.IO.MemoryStream (,[System.IO.File]::ReadAllBytes($File))
        
    # Create an empty memory stream to store our GZipped bytes in
    $memStrm = New-Object System.IO.MemoryStream

    # Create a GZipStream with $memStrm as its underlying storage
    $gzStrm  = New-Object System.IO.Compression.GZipStream $memStrm, ([System.IO.Compression.CompressionMode]::Compress)

    # Pass $memFile's bytes through the GZipstream into the $memStrm
    $gzStrm.Write($memFile.ToArray(), 0, $File.Length)
    $gzStrm.Close()
    $gzStrm.Dispose()

    # Return Base64 Encoded GZipped stream
    [System.Convert]::ToBase64String($memStrm.ToArray())
}

$Comp = $env:COMPUTERNAME
$Date = Get-Date -Format "yyyyMMddHHmmss"
$Path = ($env:temp) + "\" + $Comp + "_" + $Date + "GPResult.xml"

if (Get-Command Get-GPResultantSetOfPolicy -ErrorAction SilentlyContinue) {
    Get-GPResultantSetOfPolicy -Path $Path -ReportType XML
} else {
    GPResult.exe /X $Path
}

if ($File = ls $Path) {
    $obj = "" | Select-Object GPResultB64GZ
    $obj.GPResultB64GZ = GetBase64GzippedStream $File
} else {
    $obj.GPResultB64GZ = ("{0} could not find {1} on {2}." -f ($MyInvocation.InvocationName), $Path, $Comp)
}
$obj
