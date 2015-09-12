<#
.SYNOPSIS
Get-ProcsWMI.ps1
Acquires various details about running processes, including
commandline arguments, process start time, parent process id 
and md5 hash of the processes image as found on disk.
.NOTES
Kansa.ps1 output directive follows
OUTPUT tsv
#>

$hashtype = "MD5"

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

foreach($item in (Get-WmiObject -Query "Select * from win32_process")) {
    if ($item.ExecutablePath) {
        $hash = Compute-FileHash -FilePath $item.ExecutablePath -HashType $hashtype
    } else {
        $hash = "Get-WmiObject query returned no executable path."
    }
    Try {
        $domain = $item.GetOwner().domain
    } Catch {
        $domain = "Unobtainable"
    }
    Try {
        $username = $item.GetOwner().user
    } Catch {
        $username = "Unobtainable"
    }
    Try {
        $SId = $item.GetOwner().SId
    } Catch {
        $SId = "Unobtainable"
    }
    $username = ($domain + "\" + $username)
    $item | Add-Member -Type NoteProperty -Name "Hash" -Value $hash
    $item.CommandLine = $item.CommandLine -Replace "`n", " " -replace '\s\s*', ' '
	$item | Add-Member -Type NoteProperty -Name "Username" -Value $username
	$item | Add-Member -Type NoteProperty -Name "SID" -Value  $SId
    $item
}