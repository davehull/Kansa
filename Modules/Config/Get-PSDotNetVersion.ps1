<#
.SYNOPSIS
Used for collecting some machine config info for PowerShell and .Net versioning
.NOTES
OUTPUT TXT
#>

"PSVersionTable:"
$PSVersionTable | Out-String

"`n.Net Version Info:"
Get-ChildItem "$($env:windir)\Microsoft.Net\Framework" -i mscorlib.dll -r | % { $_.VersionInfo.ProductVersion }
"Finished`n"