<#
.SYNOPSIS
Get-PSProfiles.ps1 returns location, ownership and contents of local
PowerShell profiles.
.DESCRIPTION
Get-PSProfiles.ps1 returns custom objects with the following properties:
ProfilePath : Contains profile's path
SID         : Contains a SID for the profile where applicable
Name        : Contains the name for the profile derived from the path
              or the NoteProperty on $profile
Script      : Contains a base64 encoded string of a GZipped stream of
              the profile's contents
.INPUTS
None
.OUTPUTS
System.Management.Automation.PSCustomObject
.EXAMPLE
Get-PSProfiles.ps1
ProfilePath                                                          SID           Name                   Script
-----------                                                          ---           ----                   ------
C:\Users\MSSQLSERVER\Documents\WindowsPowershell\Microsoft.Powers... S-1-5-80-3... MSSQLSERVER
C:\Users\foo\Documents\WindowsPowershell\Microsoft.Powershell_...    S-1-5-21-2... foo                    H4sIAAAAAAAEAMVabU/byBb+Xqn/YeRGwrnEXgJtt5cKqRBgiRZKRKBdLaDKsSfJ...
C:\Users\Administrator\Documents\WindowsPowershell\Microsoft.Powe... S-1-5-21-1... Administrator         
C:\Users\UpdatusUser\Documents\WindowsPowershell\Microsoft.Powers... S-1-5-21-1... UpdatusUser
C:\Users\UpdatusUser\Documents\WindowsPowershell\Microsoft.Powers... S-1-5-21-1... UpdatusUser
C:\Windows\ServiceProfiles\NetworkService\Documents\WindowsPowers... S-1-5-20      NetworkService
C:\Windows\ServiceProfiles\LocalService\Documents\WindowsPowershe... S-1-5-19      LocalService
C:\WINDOWS\system32\config\systemprofile\Documents\WindowsPowersh... S-1-5-18      systemprofile          H4sIAAAAAAAEAMVabU/byBb+Xqn/YeRGwrnEXgJtt5cKqRBgiRZKRKBdLaDKsSfJ...
C:\Windows\System32\WindowsPowerShell\v1.0\profile.ps1                             AllUsersAllHosts
C:\Windows\System32\WindowsPowerShell\v1.0\Microsoft.PowerShell_p...               AllUsersCurrentHost
C:\Users\foo\Documents\WindowsPowerShell\profile.ps1                               CurrentUserAllHosts   
C:\Users\foo\Documents\WindowsPowerShell\Microsoft.PowerShell_...                  CurrentUserCurrentHost H4sIAAAAAAAEAMVabU/byBb+Xqn/YeRGwrnEXgJtt5cKqRBgiRZKRKBdLaDKsSfJ...
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

function GetName {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$LocalPath
)
    $Start = $LocalPath.LastIndexOf("\") + 1
    $End   = $LocalPath.Length - $Start
    $LocalPath.Substring($Start, $End)    
}

$obj = "" | Select-Object ProfilePath,SID,Name,Script

Get-WmiObject win32_userprofile | ForEach-Object {
    $obj.ProfilePath,$obj.SID,$obj.Script,$obj.Name = $null

    $obj.ProfilePath = $_.LocalPath + "\Documents\WindowsPowershell\Microsoft.Powershell_profile.ps1"
    $obj.SID  = $_.SID
    $obj.Name = GetName $_.LocalPath
    
    if (Test-Path $obj.ProfilePath) {
        # Path is valid, get the content as a Base64 Encoded GZipped stream
        $obj.Script = GetBase64GzippedStream (Get-Item $obj.ProfilePath)
    }
    $obj
}

"AllUsersAllHosts", "AllUsersCurrentHost", "CurrentUserAllHosts", "CurrentUserCurrentHost" | ForEach-Object {
    $obj.ProfilePath,$obj.SID,$obj.Script,$obj.Name = $null

    $obj.ProfilePath = ($profile.$_)
    $obj.SID  = $null
    $obj.Name = $_
    if (Test-Path $obj.ProfilePath) {
        $obj.Script = GetBase64GzippedStream (Get-Item $obj.ProfilePath)
    }
    $obj
}