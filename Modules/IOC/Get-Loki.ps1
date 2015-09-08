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
BINDEP .\Modules\bin\loki.zip
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ScanPath="C:\Windows\System32"
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
    $null = New-Item -Name loki -ItemType Directory -Path $env:Temp -Force
    $lokidest = ($env:Temp + "\loki\")
    Expand-Zip $lokipath $lokidest
    if (Test-Path($lokidest + "loki.exe")) {
        # Disk scan
        if (Test-Path($ScanPath)) { 
            ( & ${lokidest}\loki.exe --csv --noindicator --dontwait -p $ScanPath 2>&1 ) | ConvertFrom-Csv -Header Timestamp,hostname,message_type,message | Select-Object Timestamp,message_type,message

            <# 
            # return data
            $o = "" | Select-Object LokiOutput
            $o.LokiOutput = $lokioutput
            $o
            #>

            # cleanup
            Start-Sleep -Seconds 10
            $null = Remove-Item $lokidest -Force -Recurse

        } else {
            Write-Error ("{0}: scanpath of {1} not found." -f $env:COMPUTERNAME, $ScanPath)
        }
    } else {
        Write-Error ("{0}: loki.zip found, but not unzipped." -f $env:COMPUTERNAME)
    }
} else {
    Write-Error ("{0}: loki.zip not found" -f $env:COMPUTERNAME)
}