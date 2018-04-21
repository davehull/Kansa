<# 
.SYNOPSIS
Get-File.ps1 retrieves the user specified file.
.PARAMETER File
A required parameter, a path to a file that you'd like to acquire.
If Kansa can read the file, it will be returned as a base64 encoded
GZip stream stored in the object's Contents property.
When used with Kansa.ps1, parameters must be positional. Named params
are not supported.
.EXAMPLE
Get-File.ps1 C:\Users\Administrator\NTUser.dat
.NOTES
When passing specific modules with parameters via Kansa.ps1's
-ModulePath parameter, be sure to quote the entire string, like shown
here:
.\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-File.ps1 C:\boot.log"
.EXAMPLE
kansa.ps1 -Target COMPTROLLER -ModulePath ".\Modules\Disk\Get-File.ps1 C:\Windows\System32\Sethc.exe"
VERBOSE: Running module:
Get-File C:\Windows\System32\Sethc.exe
VERBOSE: Waiting for Get-File C:\Windows\System32\Sethc.exe to complete.

Id     Name            PSJobTypeName   State         HasMoreData     Location             Command
--     ----            -------------   -----         -----------     --------             -------
2      Job2            RemoteJob       Completed     True            COMPTROLLER          <# ...
.EXAMPLE
Get-File.ps1 C:\Windows\System32\Sethc.exe | more


FullName          : C:\Windows\System32\Sethc.exe
Length            : 270336
CreationTimeUtc   : 7/26/2012 1:00:34 AM
LastAccessTimeUtc : 7/26/2012 1:00:34 AM
LastWriteTimeUtc  : 7/26/2012 3:08:42 AM
Content           : H4sIAAAAAAAEAOx9CXhTVdrwTdt0bxOgwRZQAqRaBbFSxNYC5pZEbiCFAmVRihRbCowstU2gyi...
#>


[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$File
)

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

$obj = "" | Select-Object FullName,Length,CreationTimeUtc,LastAccessTimeUtc,LastWriteTimeUtc,Hash,Content

if (Test-Path($File)) {
    $Target = ls $File
    $obj.FullName          = $Target.FullName
    $obj.Length            = $Target.Length
    $obj.CreationTimeUtc   = $Target.CreationTimeUtc
    $obj.LastAccessTimeUtc = $Target.LastAccessTimeUtc
    $obj.LastWriteTimeUtc  = $Target.LastWriteTimeUtc
    $EAP = $ErrorActionPreference
    $ErrorActionPreference = 'Stop'
    Try {
        $obj.Hash              = $(Get-FileHash $File -Algorithm SHA256).Hash
    } Catch {
        $obj.Hash = 'Error hashing file'
    }
    $ErrorActionPreference = $EAP
    $obj.Content           = GetBase64GzippedStream($Target)
}  
$obj
