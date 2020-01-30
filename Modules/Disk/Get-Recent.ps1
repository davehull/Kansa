<# 
.SYNOPSIS
Get-Recent.ps1 retrieves the user Recent files.

.PARAMETER AllowedSize
size of each file that would be transfered. default is 40 MB

.EXAMPLE
Get-Recent.ps1

.NOTES
1- Kansa is not supporting Named paramter just as -ArgumentList in invoke-Command, so if you used this script with kansa don't use -AllowedSize but set the value as positional paramter like shown

    Do this:
    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-Recent.ps1 10"
    Don't do this:
    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-Recent.ps1 -AllowedSize 10"

    but you can use both methods, if you are running the script localy
    When passing specific modules with parameters via Kansa.ps1's -ModulePath parameter, be sure to quote the entire string, like shown here:

    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-Recent.ps1 10"

2- The output of the script is an object which stores the content of the retrived file in the content property, to get teh actual file use Decompress-KansaFileOutput to decompress and generate the files for you
    decompression script works only with CSV files

.EXAMPLE
kansa.ps1 -Target COMPTROLLER -ModulePath ".\Modules\Disk\Get-Recent.ps1  10"

VERBOSE: Running module:
Get-Recent 10
VERBOSE: Waiting for Get-Recent 10 to complete.

Id     Name            PSJobTypeName   State         HasMoreData     Location             Command
--     ----            -------------   -----         -----------     --------             -------
x      Jobx            RemoteJob       Completed     True            COMPTROLLER          <# ...

#>


[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [int]$AllowedSize
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



function Get-File{
    param($File,[string]$UserName)
   
    $obj = "" | Select-Object FullName,BaseName,Length,CreationTimeUtc,LastAccessTimeUtc,LastWriteTimeUtc,Hash,Content,UserName
    if (Test-Path($File)) {
        $Target = ls $File
        $obj.FullName          = $Target.FullName
        $obj.BaseName          = $Target.BaseName + $Target.extension
        $obj.Length            = $Target.Length
        $obj.CreationTimeUtc   = $Target.CreationTimeUtc
        $obj.LastAccessTimeUtc = $Target.LastAccessTimeUtc
        $obj.LastWriteTimeUtc  = $Target.LastWriteTimeUtc
        $obj.UserName          = $UserName
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

}



function Get-Recent
{
   if(-not $AllowedSize)
   {
        $AllowedSize = 40
   }

    # ordinary sitatuion for IR Data aquiesation using PSRemote, that you will login using domain admin, if you are logging using any user that doesn't have full access to all users on the machine
    # then you have to just check users that you have access to, not all users s-1-5-18, s-1-5-19 and so on
    $Users = @()
    $SIDs = @()
    #-gt 20 part to avoid Well-known SIDs as 
    $SIDs += (Get-ChildItem -Path Registry::HKEY_USERS 2>$null |where{$_.name -notmatch "Classes" -and $_.Name -notmatch "Default" -and $_.Name.Length -gt 20} | select -ExpandProperty Name) -replace "HKEY_USERS\\",""
    $Users += Get-WmiObject win32_useraccount |where{$_.sid -match ( $SIDS -join '|' )}|Select-Object -ExpandProperty NAME
    
    $Targets =@()

    $sh = New-Object -ComObject WScript.Shell

    for($i =0 ; $i -lt $Users.Count ; $i++)
    {
         $User = $Users[$i]
         $PathToFile = "C:\Users\$User\AppData\Roaming\Microsoft\Windows\Recent"
         $Files = Get-ChildItem -Path  $PathToFile  -File
        foreach($file in $Files)
        {
            
            $target = $sh.CreateShortcut($file.fullname).TargetPath

            #for Not understandable reason, kansa replaces all userprofile paths with this "C:\Windows\system32\config\systemprofile", so I made the replacment again
            #it works fine with PSRemote and no need for the next replacment, but Kansa keeps doing the replacment for User profile path
            if($target -match "C:\\Windows\\system32\\config\\systemprofile")
            {
                $target = $target -replace "C:\\Windows\\system32\\config\\systemprofile\\","C:\Users\$User\"
            }
            if($target -ne "")
            {
                $Attr = Get-Item $target | select -ExpandProperty Attributes 
            }
            else
            {
                continue
            }

            if($Attr -notmatch "system" -and $Attr -notmatch "Directory")
            {

                $sizeMB = (Get-Item $target | select -ExpandProperty Length) / 1048576
                if($sizeMB -lt $AllowedSize)
                {
                    $temp = New-Object psobject
                    $temp | Add-Member  -MemberType NoteProperty -Name Path -Value $target 
                    $temp | Add-Member  -MemberType NoteProperty -Name UserName -Value $User 
                    $Targets += $temp
           
                }  

            }
   
        }
    }
    return $Targets

}


$Paths = Get-Recent
foreach($path in $Paths){
    Get-File -File $path.path -UserName $path.username
}

