<#
.SYNOPSIS
Get-SvcAll.ps1 returns information about all Windows services.
#>

#Powershell introduced the official Get-FileHash in Powershell version 4
#If you have older versions, this function will compute md5 hashes
function Get-MyFileHash {
	param
	(
		[Parameter(Mandatory = $true)]
		[String]$Path,
		[String]$Algorithm
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
			Hash  = "NoHashComputed"
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

$Win32SvcObj = Get-WmiObject win32_service | Select-Object Name, DisplayName, Description, StartMode, Started, StartName, State, PathName, ProcessId, ServiceType

$Services = @()
$Win32SvcObj | % {
	try {
		
		#Set to "NULLSTRING" to reset the values, prevent previous loop values from bleeding over, but also to give LogParser something to parse if indeed they are blank.
		$Name = $_.Name
		#ToLower() to eliminate case-sensitive mis-matches later
		$PathName = $_.PathName.toLower()
		$ServiceDLL = "NULLSTRING"
		$Path = "NULLSTRING"
		$Service = "NULLSTRING"
		$ServiceHash = "NULLSTRING"
		$PathHash = "NULLSTRING"
		if ($PathName -like "*\svchost.exe -k *") {
			#Additional lookup for svchost processes to get the actual service DLL file path and hashes      
			($path, $service) = $_.PathName.replace(' -k ', ',').split(',')
			if (test-path "hklm:SYSTEM\CurrentControlSet\services\$Name\Parameters\") {
				$ObjRegistryService = Get-Item -path "hklm:SYSTEM\CurrentControlSet\services\$Name\Parameters\"
				$ServiceDLL = $ObjRegistryService.GetValue("ServiceDll")
				#ToLower() to eliminate case-sensitive mis-matches later
				$ServiceDLL = [Environment]::ExpandEnvironmentVariables($ServiceDLL).ToLower()
				if (test-path $ServiceDLL) {
					$ServiceHash = (Get-MyFileHash -Algorithm MD5 -Path $ServiceDLL).Hash
				}
			}
			else {
				#If the normal "Parameters" doesn't exist, sometimes the DLL is instead in the Descriptions field
				#These values need a bit of parsing, so my preference is to use the Parameters above
				if (Test-Path "hklm:SYSTEM\CurrentControlSet\services\$Name\") {
					$ObjRegistryService = Get-Item -path "hklm:SYSTEM\CurrentControlSet\services\$Name"
					$ServiceDLL = $ObjRegistryService.GetValue("Description")
					#The data here needs cleaned up a bit
					#ToLower() to eliminate case-sensitive mis-matches later
					$ServiceDLL = $ServiceDLL -replace ",.*", "" -replace "@", ""
					$ServiceDLL = [Environment]::ExpandEnvironmentVariables($ServiceDLL).ToLower()
					if (test-path $ServiceDLL) {
						$ServiceHash = (Get-MyFileHash -Algorithm MD5 -Path $ServiceDLL).Hash
					}
				}
			}
		}
		$PathNameRegex = [regex]'(\".*?\")|([Cc]:\\.*?)(?:\s|$)'
		#ToLower() to eliminate case-sensitive mis-matches later
		$FilePath = ($PathNameRegex.match($pathname)).Captures[0].value.trim('"').ToLower()
		if (test-path $FilePath) {
			$PathHash = (Get-MyFileHash -Algorithm MD5 $FilePath).Hash
		}

		$Services += New-Object -TypeName PSObject -Property @{
			Name  = $_.Name
			DescriptiveName = $_.DisplayName
			Description = $_.Description
			Mode  = $_.StartMode
			Started = $_.Started
			StartedAs = $_.StartName
			Status = $_.State
			Path  = $PathName
			ServiceDLL = $ServiceDLL
			PID   = $_.ProcessID
			Type  = $_.ServiceType
			PathMD5Sum = $PathHash
			ServiceDLLMD5Sum = $ServiceHash
		}
	}
	catch {
		Write-Error "Error gathering information for Name:$Name Path:$PathName\n"
		Write-Error $_.Exception.Message
	}
}
#pipe select is necessary to ensure output in consistent column order across all files / computers
#not sure why powershell doesn't do thus but apparently hash arrays like listed above don't necessarily all spit info out the
#same order as specified in the source code.
$Services | select Name, DescriptiveName, Description, Mode, Started, StartedAs, Status, Path, ServiceDLL, PID, Type, PathMD5Sum, ServiceDLLMd5Sum
