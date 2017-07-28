<#
.SYNOPSIS
Get-ShimCache.ps1
When run via Kansa.ps1 with -Pushbin flag, this module will copy 
ShimCacheParser.exe to the remote system, then run 
ShimCacheParser.exe -l -o $ShimCacheParserOutputPath on the remote system, 
and return the output data as a powershell object.

.NOTE
ShimCacheParser.exe can be created via pyinstaller on windows.
1. Download ShimCacheParser from https://github.com/mandiant/ShimCacheParser
2. Install pyinstaller 'pip install pyinstaller' 
3. Run 'pyinstaller -F ShimCacheParser.py'
4. Copy ./dist/ShimCacheParser.exe to \Modules\bin\


.NOTES
Kansa.ps1 directives
OUTPUT CSV
BINDEP .\Modules\bin\ShimCacheParser.exe
#>


#Setup Variables
$ShimCacheParserPath = ($env:SystemRoot + "\ShimCacheParser.exe")
$Runtime = ([String] (Get-Date -Format yyyyMMddHHmmss))
$ShimCacheParserOutputPath = $($env:Temp + "\ShimCacheParserOutput-$Runtime.csv")

if (Test-Path ($ShimCacheParserPath)) {
    $suppress = & $ShimCacheParserPath -l -o $ShimCacheParserOutputPath

    #Output the data.
    Import-csv $ShimCacheParserOutputPath 
    
    #Delete the temporary csv file.
    $suppress = Remove-Item $ShimCacheParserOutputPath -Force
        
} else {
    Write-Error "ShimCacheParser.exe not found on $env:COMPUTERNAME"
}