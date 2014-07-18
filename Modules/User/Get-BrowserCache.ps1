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
		[ValidateSet("Auto","Chrome","InternetExplorer","FireFox")]
		[string]$BrowserFamily="Auto",
	[Parameter(Mandatory=$False,Position=1)]
		[string]$UserName
)

# Hashtable of browsers we know how to parse and the name of their parse function
$supportedBrowsers = @{
	0x01 = "Get-IeCache";
	0x02 = "Get-FirefoxCache";
	0x04 = "Get-ChromeCache"
}

function Get-InstalledBrowsers {
	Write-Verbose "Automatically determining installed browsers."
	[int]$browsers = 0
	$app_path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths"
	foreach ($entry in (Get-ChildItem $app_path | Select-Object -ExpandProperty Name -ErrorAction SilentlyContinue))
	{
		$entry = $entry -replace "HKEY_LOCAL_MACHINE", "HKLM:"
		$supress = (Get-ItemProperty $entry | Select-Object -ExpandProperty PSChildName -ErrorAction SilentlyContinue)
		if ($supress -match "IEXPLORE.EXE") 
		{
			Write-Verbose "Found Internet Explorer."
			$browsers += 1 
		}
		elseif ($supress -match "firefox.exe") 
		{ 
			Write-Verbose  "Found Firefox."
			$browsers += 2 
		}
		elseif ($supress -match "chrome.exe") 
		{ 
			Write-Verbose "Found Chrome."
			$browsers += 4 
		}
	}

	return $browsers
}

function Get-IeCache {

}

function Get-FirefoxCache {

}

function Get-ChromeCache {

}

if ($BrowserFamily -eq "Auto")
{
	$browsers = Get-InstalledBrowsers 
	$browsers

	$supportedBrowsers.Keys | ? { $_-band $browsers } | % { $supportedBrowsers.Get_Item($_) }
}

