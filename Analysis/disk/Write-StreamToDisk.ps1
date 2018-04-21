<# 
.SYNOPSIS
Write-StreamToDisk.ps1 will bas64 decode and GZip decompress the byte 
stream returned by Modules\Disk\Get-File.ps1; it is meant as a companion 
to Get-File.ps1

.PARAMETER memstream
A required parameter; this is the byte stream found in the results from 
Get-File.ps1

.PARAMETER outputloc
A required parameter; this is the output location where you want the file
written to disk

.EXAMPLE
This example will read
.\Write-StreamToDisk.ps1 -memstream $(Import-CSV -Path C:\Powershell\Kansa\Output_20180108143506\FileCUsersappeuserAppDataLocalTemp1e.exe\TestComputer-FileCUsersappuserAppDataLocalTemp1e.exe.csv).content -outputloc C:\Temp\test.exe

.NOTE
Credit goes to Marcus Gelderman for the Get-DecompressedByteArray funtion.
Original can be found here: https://gist.github.com/marcgeld/bfacfd8d70b34fdf1db0022508b02aca

#>

[CmdletBinding()] 
    
Param ([Parameter(Mandatory)] [string[]] $memstream = $(Throw("-memstream is required")),
       [Parameter(Mandatory)] [string[]] $outputloc = $(Throw("-outputloc is required"))
)

function Get-DecompressedByteArray {

	[CmdletBinding()] Param ([Parameter(ValueFromPipeline,ValueFromPipelineByPropertyName)]
        [byte[]] $byteArray)

	Process {
	    Write-Verbose "Get-DecompressedByteArray"
        $input = New-Object System.IO.MemoryStream( , $byteArray )
	    $output = New-Object System.IO.MemoryStream
        $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
	    $gzipStream.CopyTo( $output )
        $gzipStream.Close()
		$input.Close()
		[byte[]] $byteOutArray = $output.ToArray()
        Write-Output $byteOutArray
    }
}


function Write-StreamToDisk {
    
    [io.file]::WriteAllBytes("$outputloc",$(Get-DecompressedByteArray -byteArray $([System.Convert]::FromBase64String($memstream))))

}

Write-StreamToDisk -memstream $memstream -outputloc $outputloc
