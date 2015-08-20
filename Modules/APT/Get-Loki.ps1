<#
.SYNOPSIS
Get-Loki.ps1

Integration with Loki scanner - https://github.com/Neo23x0/Loki

This module will deploy loki scanner to scan endpoints with yara rules and other indicators.
Please be aware that scan take a very long time and it's resourse intensive. 
On my machine it takes about 10 Hours to scan Windows folder.

Requires loki.zip file in Modules\Bin\
Put loki.exe and signatures folder in loki.zip

.NOTES
Next two lines are required by kansa for proper handling of output and 
when used with -Pushbin, the BINDEP directive below tells Kansa where
to find the third-party code.
OUTPUT txt
BINDEP .\Modules\bin\loki.zip
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ScanPath="C:\Windows"
)

Function Expand-Zip ($zipfile, $destination) {
	[int32]$copyOption = 16 # Yes to all
    $shell = New-Object -ComObject shell.application
    $zip = $shell.Namespace($zipfile)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item, $copyOption)
    }
} 

$lokipath = ($env:SystemRoot + "\loki.zip")


if (Test-Path ($lokipath)) {
    $suppress = New-Item -Name loki -ItemType Directory -Path $env:Temp -Force
    $lokidest = ($env:Temp + "\loki\")
    Expand-Zip $lokipath $lokidest
    if (Test-Path($lokidest + "loki.exe")) {
        # Disk scan
        if (Test-Path($ScanPath)) { 
                    & $lokidest\loki.exe --noindicator --dontwait -p $ScanPath
                }
            }
        $suppress = Remove-Item $lokidest -Force -Recurse
    } else {
        "loki.zip found, but not unzipped."
    }
 else {
    "loki.zip not found on $env:COMPUTERNAME"
}