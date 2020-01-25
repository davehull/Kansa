<#
.SYNOPSIS
Get-PersistenceFilesAndRegistryKeys.ps1 gathers information about various files and registry keys
derived from MITRE's Att&ck matrix data on Persistence mechanisms.  They are broken down in to
sections which are included in the data returned so they can be broken up and analyzed
seperatly.

#>

<#
	.SYNOPSIS
		Hash a file.
	
	.DESCRIPTION
		Powershell introduced the official Get-FileHash in Powershell version 4
		If you have older versions, this function will compute md5 hashes
	
	.PARAMETER Path
		The full path including drive letter to the file you want to hash.
		
		Example: "C:\windows\system32\lsass.exe"
	
	.PARAMETER Algorithm
		A description of the Algorithm parameter.
	
	.EXAMPLE
				PS C:\> Get-MyFileHash -Path 'Value1'
	
	.NOTES
		Additional information about the function.
#>
function Get-MyFileHash {
	param
	(
		[Parameter(Mandatory = $true)]
		[ValidateNotNullOrEmpty()]
		[String]$Path,
		[String]$Algorithm = 'md5'
	)
	
	if ($PSVersionTable.PSVersion.Major -ge 4) {
		return get-filehash -Path $Path -Algorithm $Algorithm
	}
	try {
		$file = [System.IO.File]::Open($Path, [System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)
	}
	catch {
		#Failed to open file for reading, nothing to do, just return
		$return = New-Object -typename PSObject -Property @{
			Hash	 = "NoHashComputed"
		}
		return $return
	}
	try {
		$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
		$hash = ([System.BitConverter]::ToString($md5.ComputeHash($file))) -replace "-", ""
		$return = New-Object -TypeName PSObject -Property @{
			Hash   = $hash
		}
	}
	finally {
		$file.Dispose()
	}
	$return
}

#data object to hold information until we're ready to return the results
$Objects = @()




#Accessibility Features
#https://attack.mitre.org/wiki/Technique/T1015
$Files = @()
$Files += "c:\Windows\System32\osk.exe"
$Files += "c:\Windows\System32\magnify.exe"
$Files += "c:\Windows\System32\narrator.exe"
$Files += "c:\Windows\System32\displayswitch.exe"
$Files += "c:\Windows\System32\atbroker.exe"
$Files += "c:\Windows\System32\sethc.exe"
$Files += "c:\Windows\System32\utilman.exe"

$Files | % {
	$file = $_
	$hash = (Get-MyFileHash -Path $file -Algorithm md5).hash
	$Objects += New-Object -TypeName PSObject -Property @{
		Type	   = "File"
		Set	       = "AccessibilityFeatures"
		Path	   = $File
		Value	   = $Hash
	}
}
	
#AppCert DLLs
#https://attack.mitre.org/wiki/Technique/T1182
#AppCertDLLs value in the Registry key
$Path = "hklm:System\CurrentControlSet\Control\Session Manager\AppCertDLLs\"
if (Test-Path $Path) {
	$RegItems = Get-Item $Path
	$RegItems.Property | %{
		$Key = $_
		Try {
			$Value = (Get-ItemProperty $Path $Key -ErrorAction Stop).$Key
		}
		Catch [System.Management.Automation.PSArgumentException] {
			$Value = "Registry Key Property missing"
		}
		Catch [System.Management.Automation.ItemNotFoundException] 				{
			$Value = "Registry Key itself is missing"
		}
		$SearchPath = "$Path\$Key"
		$Objects += New-Object -TypeName PSObject -Property @{
			Type	   = "RegKey"
			Set	       = "AppCertDlls"
			Path	   = $SearchPath
			Value	   = $Value
		}
		
	}
}
	
	
#AppInitDLLs
#https://attack.mitre.org/wiki/Technique/T1103
#Manager value in the Registry keys
$Paths = @("hklm:Software\Microsoft\Windows NT\CurrentVersion\Windows",
	"hklm:Software\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows")
$Key = "AppInit_DLLs"
$Paths | %{
	$Path = $_
	$SearchPath = "$Path\$Key"
	Try {
		$Value = (Get-ItemProperty $Path $Key -ErrorAction Stop).$Key
	}
	Catch [System.Management.Automation.PSArgumentException] {
		$Value = "Registry Key Property missing"
	}
	Catch [System.Management.Automation.ItemNotFoundException] 				{
		$Value = "Registry Key itself is missing"
	}
	$Objects += New-Object -TypeName PSObject -Property @{
		Type	    = "RegKey"
		Set		    = "AppInitDLLs"
		Path	    = $SearchPath
		Value	    = $Value
	}	
}


#Authentication Package
#Adversaries can use the autostart mechanism provided by LSA Authentication Packages 
#for persistence by placing a reference to a binary in the Windows Registry location 
#HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ with the key value of "Authentication Packages"=<target binary>. 
#The binary will then be executed by the system when the authentication packages are loaded.
#https://attack.mitre.org/wiki/Technique/T1131
#HKLM\SYSTEM\CurrentControlSet\Control\Lsa\ with the key value of "Authentication Packages"=<target binary>
$Path = 'HKLM:SYSTEM\CurrentControlSet\Control\Lsa\'
$Keys = @('Authentication Packages',
	'Notification Packages',
	'Security Packages')
$Keys | %{
	$Key = $_
	$SearchPath = "$Path\$Key"
	Try {
		$Values = (Get-ItemProperty $Path $Key -ErrorAction Stop).$Key
	}
	Catch [System.Management.Automation.PSArgumentException] {
		$Values = "Registry Key Property missing"
	}
	Catch [System.Management.Automation.ItemNotFoundException] 				{
		$Values = "Registry Key itself is missing"
	}
	#Potential future enhancement, split values to compare each individual value.
	#For now we'll join via | to get a single string value.
	#$Values -split '[, ]' | %{}
	$Objects += New-Object -TypeName PSObject -Property @{
		Type	   = "RegKey"
		Set	       = "AuthenticationPackage"
		Path	   = $SearchPath
		Value	   = $Values -join "|"
	}
}

#Security Support Provider
#Moved here because it's similar / overlapping keys
#https://attack.mitre.org/wiki/Technique/T1101
#HKLM\SYSTEM\CurrentControlSet\Control\Lsa\Security Packages and 
#The first is checked above so we'll check this one here.
#HKLM\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig\Security Packages
$Path = 'HKLM:SYSTEM\CurrentControlSet\Control\Lsa\OSConfig\'
if(Test-Path $Path) {
	$Keys = @('Security Packages')
	$Keys | %{
		$Key = $_
		$SearchPath = "$Path\$Key"
		Try {
			$Values = (Get-ItemProperty $Path $Key -ErrorAction Stop).$Key
		}
		Catch [System.Management.Automation.PSArgumentException] {
			$Values = "Registry Key Property missing"
		}
		Catch [System.Management.Automation.ItemNotFoundException] 				{
			$Values = "Registry Key itself is missing"
		}
		
		#Potential future enhancement, split values to compare each individual value.
		#For now we'll join via | to get a single string value.
		#$Values -split '[, ]' | %{}
		$Objects += New-Object -TypeName PSObject -Property @{
			Type	    = "RegKey"
			Set		    = "LsaSSP"
			Path	    = $SearchPath
			Value	    = $Values -join "|"
		}
	}
}

#Image File Execution Options Injection
#https://attack.mitre.org/wiki/Technique/T1183
#Debugger Values in the Registry under 
#HKLM\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options/<executable>
#and HKLM\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\<executable> where <executable>
$Key = "Debugger"
#$Paths = @('HKLM:Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\',
#	'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\')
$Paths = @('HKLM:Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\')
#	'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\')

$Paths | %{
	$Path = $_
	$RegItems = Get-ChildItem $Path
	$SearchItems = $RegItems | ?{ $_.property -eq $key }
	$SearchItems | %{
		$Name = $_.Name
		$SearchPath = "$Path\$($Name -replace '.*\\', '')"
		Try {
			$Value = (Get-ItemProperty $Path $Key -ErrorAction Stop).$Key
		}
		Catch [System.Management.Automation.PSArgumentException] {
			$Value = "Registry Key Property missing"
		}
		Catch [System.Management.Automation.ItemNotFoundException] 				{
			$Value = "Registry Key itself is missing"
		}
		catch {
			#For some reason PS v2.0 doesn't seem to process the above catch statements
			#and instead skips to this one??? I dunno.
			$Value = "Unable to get registry information"
		}
		$Objects += New-Object -TypeName PSObject -Property @{
			Type	   = "RegKey"
			Set	       = "IFEO"
			Path	   = $SearchPath
			Value	   = $Value
		}
	}
}

#Port Monitors
#https://attack.mitre.org/wiki/Technique/T1013
#HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors.

$Key = "Driver"
$Paths = @('HKLM:SYSTEM\CurrentControlSet\Control\Print\Monitors\')
$Paths | %{
	$Path = $_
	$RegItems = Get-ChildItem $Path
	$SearchItems = $RegItems | ?{ $_.property -eq $key }
	$SearchItems | %{
		$Name = $_.Name
		$SearchPath = "$Path\$($Name -replace '.*\\', '')"
		Try {
			$Value = (Get-ItemProperty $Path $Key -ErrorAction Stop).$Key
			#the files must be located in the system32 dir
			$hash = (Get-MyFileHash "$env:SystemRoot\System32\$Value").hash
			$Objects += New-Object -TypeName PSObject -Property @{
				Type	   = "File"
				Set	       = "PortMonitors"
				Path	   = "$env:SystemRoot\System32\$Value"
				Value	   = $hash
			}
		}
		Catch [System.Management.Automation.PSArgumentException]{
			$Value = "Registry Key Property missing"
		}
		Catch [System.Management.Automation.ItemNotFoundException]{
			$Value = "Registry Key itself is missing"
		}
		catch {
			#For some reason PS v2.0 doesn't seem to process the above catch statements
			#and instead skips to this one??? I dunno.
			$Value = "Unable to get registry information"
		}
		$Objects += New-Object -TypeName PSObject -Property @{
			Type	   = "RegKey"
			Set	       = "PortMonitors"
			Path	   = $SearchPath
			Value	   = $Value
		}
		
	}
}

#Make the output consistent (select) and pretty (sort).
$Objects | select 'Type','Set','Path','Value' | sort 'Type','Set','Path'