<#
.SYNOPSIS
Get-WMIRecentApps.ps1
Queries the CCM_RecentlyUsedApps class in the SoftwareMeteringAgent namespace
and lists all the recorded information about application executions. It also
calculates the hash of the referenced files on disk.

Inspired by this Tweet from Jon Glass:
 - https://twitter.com/GlassSec/status/689854156761387008
.NOTES
Kansa.ps1 output directive follows
OUTPUT tsv
#>

function Compute-FileHash {
Param(
    [Parameter(Mandatory = $true, Position=1)]
    [string]$FilePath,
    [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
    [string]$HashType = "MD5"
)
    
    switch ( $HashType.ToUpper() )
    {
        "MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
        "SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
        "SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
        "SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
        "SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
        "RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
        default     { "Invalid hash type selected." }
    }

    if (Test-Path $FilePath) {
        $FileName = Get-ChildItem -Force $FilePath | Select-Object -ExpandProperty Fullname
        $fileData = [System.IO.File]::ReadAllBytes($FileName)
        $HashBytes = $hash.ComputeHash($fileData)
        $PaddedHex = ""

        foreach($Byte in $HashBytes) {
            $ByteInHex = [String]::Format("{0:X}", $Byte)
            $PaddedHex += $ByteInHex.PadLeft(2,"0")
        }
        $PaddedHex
        
    } else {
        "$FilePath is invalid or locked."
        Write-Error -Message "Invalid input file or path specified. $FilePath" -Category InvalidArgument
    }
}

try {
    $RecentApps = Get-WmiObject -Namespace "root\CCM\SoftwareMeteringAgent" `
                    -Query "Select * from CCM_RecentlyUsedApps" -ErrorAction Stop
}
catch [System.Management.ManagementException] {
    throw 'WMI Namespace root\CCM\SoftwareMeteringAgent does not exist.'
}

# Set up the time format template.
$time_format = "yyyyMMddHHmmss.ffffffzzz"

foreach($RecentApp in $RecentApps) {
    if ($RecentApp.FolderPath) {
        $BinaryPath = Join-Path $($RecentApp.FolderPath) $($RecentApp.ExplorerFileName)
        $Sha1Hash = Compute-FileHash -FilePath $BinaryPath -HashType "SHA1"
        $Md5Hash = Compute-FileHash -FilePath $BinaryPath -HashType "MD5"
    } else {
        $Sha1Hash = "Get-WmiObject query returned no executable path."
        $Md5Hash = "Get-WmiObject query returned no executable path."
    }

    # Fix the timezone marker to match a parsable format and reformat the
    # timestamp to comply with ISO 8601.
    $LastUsedTime = ($RecentApp.LastUsedTime -replace "\+(\d)(\d{2})$", '+$1:$2')

    try {
        $IsoLastUsedTime = [DateTime]::ParseExact($LastUsedTime, $time_format, [CultureInfo]::InvariantCulture).ToUniversalTime().ToString("O")
    }
    catch {
        $IsoLastUsedTime = "Unable to parse time string"
    }

    $RecentApp | Add-Member -Type NoteProperty -Name IsoLastUsedTime -Value $IsoLastUsedTime
    $RecentApp | Add-Member -Type NoteProperty -Name Sha1Hash -Value $Sha1Hash
    $RecentApp | Add-Member -Type NoteProperty -Name Md5Hash -Value $Md5Hash
    
    $RecentApp
}