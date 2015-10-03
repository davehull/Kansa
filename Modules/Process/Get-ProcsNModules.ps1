<#
.SYNOPSIS
Get-ProcsNModules.ps1
The aim of this collector is to enumerate all running processes and
their loaded modules. Post data collection, analysis can be run
against this data to find possible DLL Search Order Hijacking.

Some of the data collected here is available by parsing the output of
Get-Prox.ps1, but parsing XML collected from a large number of hosts
sucks... and it's slow. So, I'm inclined to keep this as a separate 
collector.

.NOTES
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
        Write-Error -Message "$FilePath is invalid or locked." -Category InvalidArgument
    }
}

$hashtable = @{}

Get-Process | % { 
    $MM = $_.MainModule | Select-Object -ExpandProperty FileName
    $Modules = $($_.Modules | Select-Object -ExpandProperty FileName)
    $currPID = $_.Id
 
    foreach($Module in $Modules) {
        $o = "" | Select-Object Name, ParentPath, Hash, ProcessName, ProcPID, CreateUTC, LastAccessUTC, LastWriteUTC
        $o.Name = $Module.Substring($Module.LastIndexOf("\") + 1)
        $o.ParentPath = $Module.Substring(0, $Module.LastIndexOf("\"))
        if ($hashtable.get_item($Module)) {
            $o.Hash = $hashtable.get_item($Module)
        } else {
            $o.Hash = Compute-FileHash -FilePath $Module
            $hashtable.Add($Module, $o.Hash)
        }
        # $o.ProcessName = $MM
        $o.ProcessName = ($MM.Split('\'))[-1]
        $o.ProcPID = $currPID
        $o.CreateUTC = (Get-Item -Force $Module).CreationTimeUtc
        $o.LastAccessUTC = (Get-Item -Force $Module).LastAccessTimeUtc
        $o.LastWriteUTC = (Get-Item -Force $Module).LastWriteTimeUtc
        $o
    }
}
