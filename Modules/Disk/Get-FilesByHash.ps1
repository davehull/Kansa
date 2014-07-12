# OUTPUT TSV
# Get-FilesByHash.ps1 scans the local disks for files matching the provided
# hash. Defaults to SHA-256. For example cmd.exe's hash (on Windows 8.1)
# is 0B9BC863E2807B6886760480083E51BA8A66118659F4FF274E7B73944D2219F5

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$FileHash,
    [Parameter(Mandatory=$False,Position=1)]
        [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [string]$HashType = "SHA256",
    [Parameter(Mandatory=$False,Position=2)]
        [string[]]$BasePaths = @()
) 

function Get-AllDrives
{
    foreach ($disk in (Get-WmiObject win32_logicaldisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID))
    {
        [string[]]$drives += "$disk\"
    }
    
    $driveCount = $drives.Count.ToString()
    Write-Verbose "Found $driveCount local drives."
    return $drives
}

$sb = {
        [CmdletBinding()]
        Param (
            [Parameter(Mandatory=$True,Position=0)]
                [string]$BasePath,
            [Parameter(Mandatory=$True,Position=1)]
                [string]$SearchHash,
            [Parameter(Mandatory=$True,Position=2)]
                [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
                [string]$HashType = "SHA256"
        )

        switch ( $HashType.ToUpper() )
        {
            "MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
            "SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
            "SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
            "SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
            "SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
            "RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
            #default     { Write-Error -Message "Invalid hash type selected." -Category InvalidArgument }
        }

        $hashList = @{}
        $match = $False

        foreach ($file in (Get-ChildItem -Path $basePath -Recurse | Select-Object -ExpandProperty FullName)) 
        {
            if (Test-Path -LiteralPath $file -PathType Leaf)
            {
                $fileData = New-Object IO.StreamReader $file
                $hashBytes = $hash.ComputeHash($fileData.BaseStream)
                $fileData.Close()
                $paddedHex = ""

                foreach( $byte in $hashBytes )
                {
                    $byteInHex = [String]::Format("{0:X}", $byte)
                    $paddedHex += $byteInHex.PadLeft(2,"0")
                }

                if ($paddedHex -ieq $searchHash)
                {
                    $hashList.Add($file, $paddedHex)
                    $match = $True
                }
            }
        }

        $hashCount = $hashList.Count.ToString()
        Write-Verbose "Found $hashCount matching files."
        if ($match)
        {
            return $hashList
        }
        else
        {
            return $False
        }
}

if ($BasePaths.Length -eq 0)
{
    Write-Verbose "No path specified, enumerating local drives."
    $BasePaths = Get-AllDrives
}

foreach ($basePath in $BasePaths)
{
    Write-Verbose "Getting file hashes for $basePath."
    $Job = Start-Job -ScriptBlock $sb -ArgumentList $basePath, $FileHash, $HashType
    $supress = Wait-Job $Job
    $Recpt = Receive-Job $Job -ErrorAction SilentlyContinue
    if ($Recpt)
    {
        $Recpt
    }
}
