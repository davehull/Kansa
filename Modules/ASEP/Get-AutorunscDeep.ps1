<#
.SYNOPSIS
Get-Autorunsc.ps1 returns output from the Sysinternals' Autorunsc.exe
utility, which pulls information about many well-known Auto-Start
Extension Points from Windows systems. ASEPs are commonly used as
persistence mechanisms for adversaries.

This script does depend on Sysinternals' Autorunsc.exe, which is not
packaged with Kansa. You will have to download it from Sysinternals and
drop it in the .\Modules\bin\ directory. When you run Kansa.ps1, if you
add the -Pushbin switch at the command line, Kansa.ps1 will attempt to 
copy the Autorunsc.exe binary to each remote target's ADMIN$ share.

If you want to remove the binary from remote systems after it has run,
add the -rmbin switch to Kansa.ps1's command line.

If you run Kansa.ps1 without the -rmbin switch, binaries pushed to 
remote hosts will be left beind and will be available on subsequent
runs, obviating the need to run with -Pushbin in the future.

.NOTES
The following lines are required by Kansa.ps1. They are directives that
tell Kansa how to treat the output of this script and where to find the
binary that this script depends on.
OUTPUT tsv
BINDEP .\Modules\bin\Autorunsc.exe

!!THIS SCRIPT ASSUMES AUTORUNSC.EXE WILL BE IN $ENV:SYSTEMROOT!!

Autorunsc output is a mess. Some of it is quoted csv, some is just csv.
This script parses it pretty well, but there are still some things that
are incorrectly parsed. As I have time, I'll see about resolving the 
troublesome entries, one in particular is for items that don't have 
time stamps.
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
        $FileName = Get-ChildItem $FilePath | Select-Object -ExpandProperty Fullname
        $fileData = [System.IO.File]::ReadAllBytes($FileName)
        $HashBytes = $hash.ComputeHash($fileData)
        $PaddedHex = ""

        $HashBytes | ForEach-Object { $Byte = $_
            $ByteInHex = [String]::Format("{0:X}", $Byte)
            $PaddedHex += $ByteInHex.PadLeft(2,"0")
        }
        $PaddedHex
        
    } else {
        "$FilePath is invalid or locked."
        Write-Error -Message "Invalid input file or path specified. $FilePath" -Category InvalidArgument
    }
}

if (Test-Path "$env:SystemRoot\Autorunsc.exe") {
    $extPattern = ".*\s+(?<scriptName>([A-Z]+\:\\|\\\\).*\.(bat|ps1|vbs))\s*"
    & $env:SystemRoot\Autorunsc.exe /accepteula -a * -c -h -s '*' 2> $null | Select-Object -Skip 1 | % {
        $row = $_ -replace '(,)(?=(?:[^"]|"[^"]*")*$)', "`t" -replace "`""
        $o = "" | Select-Object Time, EntryLocation, Entry, Enabled, Category, Profile, Description, Publisher, ImagePath, Version, LaunchString, MD5, SHA1, PESHA1, PESHA256, SHA256, ScriptMD5
        $o.Time,
        $o.EntryLocation, 
        $o.Entry, 
        $o.Enabled, 
        $o.Category, 
        $o.Profile,
        $o.Description, 
        $o.Publisher, 
        $o.ImagePath, 
        $o.Version, 
        $o.LaunchString, 
        $o.MD5, 
        $o.SHA1, 
        $o.PESHA1, 
        $o.PESHA256, 
        $o.SHA256 = ($row -split "`t")
        
        <# 
        Before we return data to Kansa, let's do a deeper dive on 
        LaunchString and see if it contains .bat, .ps1 or .vbs files.
        If it does, resolve those paths and generate hashes of those
        files.
        #>
        
        if ($o.LaunchString -match $extPattern) {
            $o.ScriptMD5 = Compute-FileHash $($matches['scriptName'])
            # $o.LaunchString
        } else {
            $o.ScriptMD5 = $null
        }

        $o
    }
} else {
    Write-Error "Autorunsc.exe not found in $env:SystemRoot."
}