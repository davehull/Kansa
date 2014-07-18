<#
.SYNOPSIS
Get-BrowserCache pulls the cache and history for the browser and user spcified.
.PARAMETER BrowserFamily
Optional. One of FireFox, Chrome, IE, or Auto. By default, will check with WMI
for installed browsers and grab those automatically.
.PARAMETER UserName
Optional. Specific user for which you want to grab browser cache and history.
.NOTES
OUTPUT TSV

When passing specific modules with parameters via Kansa.ps1's -ModulePath 
parameter, be sure to quote the entire string, like shown here:
.\kansa.ps1 -ModulePath ".\Modules\Net\Get-BroswerCache.ps1 Auto,Administrator"
#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$False,Position=0)]
		[ValidateSet("FireFox","Chrome","InternetExplorer","Auto")]
		[string]$BrowserFamily="Auto",
	[Parameter(Mandatory=$False,Position=1)]
		[string]$UserName
)

