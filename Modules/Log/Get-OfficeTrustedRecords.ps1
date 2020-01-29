<# 
.SYNOPSIS
Get-TrustedRecords.ps1 retrieves the user's office-TrustedRecords files.

.PARAMETER AllowedSize
size of each file that would be transfered. default is 40 MB
When used with Kansa.ps1, parameters must be positional. Named params
are not supported.

.DESCRIPTION

Every trusted Document has an entry in registry, this script finds those entries and resolve the path the use Get-File function to retrive the data

.NOTES
1- Kansa is not supporting Named paramter just as -ArgumentList in invoke-Command, so if you used this script with kansa don't use -AllowedSize but set the value as positional paramter like shown

    Do this:
    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-TrustedRecords.ps1 10"
    Don't do this:
    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-TrustedRecords.ps1 -AllowedSize 10"

    but you can use both methods, if you are running the script localy
    When passing specific modules with parameters via Kansa.ps1's -ModulePath parameter, be sure to quote the entire string, like shown here:

    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-TrustedRecords.ps1 10"

2- The output of the script is an object which stores the content of the retrived file in the content property, to get teh actual file use Decompress-KansaFileOutput to decompress and generate the files for you
    decompression script works only with CSV files

.EXAMPLE
Get-TrustedRecords.ps1 -AllowedSize 10

.EXAMPLE
kansa.ps1 -Target COMPTROLLER -ModulePath ".\Modules\Disk\Get-TrustedRecords.ps1 -AllowedSize 10"
VERBOSE: Running module:
Get-TrustedRecords 10
VERBOSE: Waiting for Get-TrustedRecords -AllowedSize 10 to complete.

Id     Name            PSJobTypeName   State         HasMoreData     Location             Command
--     ----            -------------   -----         -----------     --------             -------
x      Jobx            RemoteJob       Completed     True            COMPTROLLER          <# ...



#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        $AllowedSize
)
function Get-OfficeTrustedRecords
{
    #Microsoft office applications
    $MicrosoftOfficeApps = @("PowerPoint","Excel","Word")

    # ordinary sitatuion for IR Data aquiesation using PSRemote, that you will login using domain admin, if you are logging using domain user that doesn't have full access to all users on the machine
    # then you have to just check users that you have access to, not all users
    $Users = @()
    $SIDs = @()
    $SIDs += (Get-ChildItem -Path Registry::HKEY_USERS 2>$null |where{$_.name -notmatch "Classes" -and $_.Name -notmatch "Default" -and $_.Name.Length -gt 20} | select -ExpandProperty Name) -replace "HKEY_USERS\\",""
    $Users += Get-WmiObject win32_useraccount |where{$_.sid -match ( $SIDS -join '|' )}|Select-Object -ExpandProperty NAME
    
    $Records = @()
    if(-not $AllowedSize)
    {
         $AllowedSize = 40 
    }

    for($i = 0; $i -lt $Users.Count; $i++)
    {
        foreach($App in $MicrosoftOfficeApps)
        {
            $User = $Users[$i]
            $SID  = $SIDs[$i]
            #Path in registry is depending on the version of office ex: 15.0 is office 2013, check list from here https://docs.microsoft.com/en-us/office/troubleshoot/word/reset-options-and-settings-in-word
            $version = (Get-ChildItem -Path "HKCU:\Software\Microsoft\Office" | select -ExpandProperty PSChildName)[0]

            if(Test-Path "Registry::HKEY_USERS\$SID\Software\Microsoft\Office\$version\$App\Security\Trusted Documents\TrustRecords")
            {
       
                $Properties = Get-Item -Path "Registry::HKEY_USERS\$SID\Software\Microsoft\Office\$version\$App\Security\Trusted Documents\TrustRecords" | select -ExpandProperty property
            
                foreach($property in $Properties)
                {
                    if($property -match "%USERPROFILE%")
                    {
                        $property = $property -replace "/","\"
                        
                        $property = $property -replace "%USERPROFILE%","C:\Users\$User"

                        # for very wired reason [System.Web.HttpUtility] is undefiend when its used with Kansa, but it's very good with PSRemote
                        # $property = [System.Web.HttpUtility]::UrlDecode($property)
                        $property = $property -replace "%20"," "

                        if($property -match "C:\\Windows\\system32\\config\\systemprofile")
                        {

                          $property = $property -replace "C:\\Windows\\system32\\config\\systemprofile\\","C:\Users\$User\"

                        }
                        # this Test-Path is redundant because Get-File already does this check, but I left it here just to be easy to the next contributor to understand the function
                        if(Test-Path $property)
                        {
                            $SizeMB = (Get-Item $property | select -ExpandProperty length) / 1048576

                            if($SizeMB -le $AllowedSize)
                            {
                                $temp = New-Object psobject
                                $temp | Add-Member -MemberType NoteProperty -Name Path -Value $property
                                $temp | Add-Member -MemberType NoteProperty -Name username -Value $User
                                $Records += $temp
                            }
                        }
            
                    }

                }
            }
            else
            {
                Write-Host  "No Trusted Documents in $App for $User,"
                Write-Error "No Trusted Documents in $App for $User," 
            }
       
        }
     }
     return $Records
}

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


$records = Get-OfficeTrustedRecords

foreach($record in $records){
   Get-File -File $record.Path -UserName $record.username
}