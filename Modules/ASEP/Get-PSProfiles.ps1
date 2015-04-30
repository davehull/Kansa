<#
.SYNOPSIS
Get-PSProfiles.ps1 returns location, ownership and contents of local
PowerShell profiles.
.DESCRIPTION
Get-PSProfiles.ps1 returns custom objects with the following properties:
ProfilePath : Contains profile's path
SID         : Contains a SID for the profile or a description
Script      : Contains a base64 encoded string of a GZipped stream of
              the profile's contents
.INPUTS
None
.OUTPUTS
System.Management.Automation.PSCustomObject
.EXAMPLE
Get-PSProfiles.ps1
ProfilePath                                                                                SID                            Script
-----------                                                                                ---                            ------
C:\Users\MSSQLSERVER\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1          S-1-5-nn-nnnnnnnnnn-nnnnnnnnnn
C:\Users\foo\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1                  S-1-5-nn-nnnnnnnnnn-nnnnnnnnnn H4sIAAAAAAAEAMVabU/byBb+Xqn/YeRGwrnEXgJtt
C:\Users\Administrator\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1        S-1-5-nn-nnnnnnnnnn-nnnnnnnnnn
C:\Users\UpdatusUser\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1          S-1-5-nn-nnnnnnnnnn-nnnnnnnnnn
C:\Users\UpdatusUser\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1          S-1-5-nn-nnnnnnnnnn-nnnnnnnnnn
C:\Windows\ServiceProfiles\NetworkService\Documents\WindowsPowershell\Microsoft.Powersh... S-1-5-20
C:\Windows\ServiceProfiles\LocalService\Documents\WindowsPowershell\Microsoft.Powershel... S-1-5-19
C:\WINDOWS\system32\config\systemprofile\Documents\WindowsPowershell\Microsoft.Powershe... S-1-5-18                       H4sIAAAAAAAEAMVabU/byBb+Xqn/YeRGwrnEXgJtt
C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1                                     AllUsersAllHosts
C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_profile.ps1                AllUsersCurrentHost
C:\Users\dahull\Documents\WindowsPowerShell\profile.ps1                                    CurrentUserAllHosts
C:\Users\dahull\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1               CurrentUserCurrentHost         H4sIAAAAAAAEAMVabU/byBb+Xqn/YeRGwrnEXgJtt
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

$obj = "" | Select-Object ProfilePath,SID,Script

Get-WmiObject win32_userprofile | ForEach-Object {
    $obj.ProfilePath,$obj.SID,$obj.Script = $null

    $obj.ProfilePath = $_.LocalPath + "\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1"
    $obj.SID  = $_.SID
    
    if (Test-Path $obj.ProfilePath) {
        # Path is valid, get the content as a Base64 Encoded GZipped stream
        $obj.Script = GetBase64GzippedStream (Get-Item $obj.ProfilePath)
    }
    $obj
}

"AllUsersAllHosts", "AllUsersCurrentHost", "CurrentUserAllHosts", "CurrentUserCurrentHost" | ForEach-Object {
    $obj.ProfilePath,$obj.SID,$obj.Script = $null

    $obj.ProfilePath = ($profile.$_)
    $obj.SID = $_
    if (Test-Path $obj.ProfilePath) {
        $obj.Script = GetBase64GzippedStream (Get-Item $obj.ProfilePath)
    }
    $obj
}