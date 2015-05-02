<#
.SYNOPSIS
Get-AutorunscDeep.ps1 returns output from the Sysinternals' Autorunsc.exe
utility, which pulls information about many well-known Auto-Start
Extension Points from Windows systems. ASEPs are commonly used as
persistence mechanisms for adversaries.

But wait, there's more! 

1. Get-AutorunscDeep.ps1 also calculates file entropy, recall that 
malware commonly uses packers to obfuscate their internals and bypass
AV signatures and those packers lead to higher byte entropy.

2. Get-AutorunscDeep.ps1 also calculates MD5 hashes for scripts that 
are called by common interpreters -- cmd.exe, PowerShell.exe and
WScript.exe, whereas Autorunsc.exe only provices the hashes for the
binaries themselves.

3. Get-AutorunscDeep.ps1 also provides the LastWriteTime for the 
scripts called by the interpreters above.

All three of these additional pieces of information give the analyst
deeper insight into the autoruns in their environments.

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
        $File = Get-ChildItem $FilePath
        $fileData = [System.IO.File]::ReadAllBytes($File.FullName)
        $HashBytes = $hash.ComputeHash($fileData)
        $PaddedHex = ""

        foreach($Byte in $HashBytes) {
            $ByteInHex = [String]::Format("{0:X}", $Byte)
            $PaddedHex += $ByteInHex.PadLeft(2,"0")
        }
        $PaddedHex
        $File.LastWriteTimeUtc
        $File.Length
        
    } else {
        "${FilePath} is locked or could not be found."
        "${FilePath} is locked or could not be not found."
        Write-Error -Category InvalidArgument -Message ("{0} is locked or could not be found." -f $FilePath)
    }
}

function GetShannonEntropy {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [string]$FilePath
)
    $fileEntropy = 0.0
    $FrequencyTable = @{}
    $ByteArrayLength = 0
            
    if(Test-Path $FilePath) {
        $file = (ls $FilePath)
        Try {
            $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        } Catch {
            Write-Error -Message ("Caught {0}." -f $_)
        }

        foreach($fileByte in $fileBytes) {
            $FrequencyTable[$fileByte]++
            $ByteArrayLength++
        }

        $byteMax = 255
        for($byte = 0; $byte -le $byteMax; $byte++) {
            $byteProb = ([double]$FrequencyTable[[byte]$byte])/$ByteArrayLength
            if ($byteProb -gt 0) {
                $fileEntropy += -$byteProb * [Math]::Log($byteProb, 2.0)
            }
        }
        $fileEntropy
        
    } else {
        "${FilePath} is locked or could not be found. Could not calculate entropy."
        Write-Error -Category InvalidArgument -Message ("{0} is locked or could not be found." -f $FilePath)
    }
}

if (Test-Path "$env:SystemRoot\Autorunsc.exe") {
    # This regex matches all of the path types I've encountered, but there may be some it misses, if you find some, please send a sample to kansa@trustedsignal.com
    $fileRegex = New-Object System.Text.RegularExpressions.Regex "(([a-zA-Z]:|\\\\\w[ \w\.]*)(\\\w[- \w\.\\\{\}]*|\\%[ \w\.]+%+)+|%[ \w\.]+%(\\\w[ \w\.]*|\\%[ \w\.]+%+)*)"
    & $env:SystemRoot\Autorunsc.exe /accepteula -a * -c -h -s '*' 2> $null | ConvertFrom-Csv | ForEach-Object {
        $_ | Add-Member NoteProperty ScriptMD5 $null
        $_ | Add-Member NoteProperty ScriptModTimeUTC $null
        $_ | Add-Member NoteProperty ShannonEntropy $null
        $_ | Add-Member NoteProperty ScriptLength $null

        if ($_."Image Path") {
            $_.ShannonEntropy = GetShannonEntropy $_."Image Path"
        }

        $fileMatches = $False
        if (($_."Image Path").ToLower() -match "\.bat|\.ps1|\.vbs") {
            $fileMatches = $fileRegex.Matches($_."Image Path")
        } elseif (($_."Launch String").ToLower() -match "\.bat|\.ps1|\.vbs") {
            $fileMatches = $fileRegex.Matches($_."Launch String")
        }

        if ($fileMatches) {
            for($i = 0; $i -lt $fileMatches.count; $i++) {
                $file = $fileMatches[$i].value
                if ($file -match "\.bat|\.ps1|\.vbs") {
                    if ($file -match "%userdnsdomain%") {
                        $scriptPath = "\\" + [System.Environment]::ExpandEnvironmentVariables($file)
                    } elseif ($file -match "%") {
                        $scriptPath = [System.Environment]::ExpandEnvironmentVariables($file)
                    } else {
                        $scriptPath = $file
                    }
                }
                $scriptPath = $scriptPath.Trim()
                $_.ScriptMD5,$_.ScriptModTimeUTC,$_.ScriptLength = Compute-FileHash $scriptPath
                $scriptPath = $null
            }
        }
        $_
    }
} else {
    Write-Error "Autorunsc.exe not found in $env:SystemRoot."
}