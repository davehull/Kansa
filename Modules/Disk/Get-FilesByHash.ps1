<# 
.SYNOPSIS
Get-FilesByHash.ps1 scans the provided paths for files matching the provided hash.
.PARAMETER FileHash
Required. The file hash you are searching for.  For example cmd.exe's hash (on 
Windows 8.1) is 0B9BC863E2807B6886760480083E51BA8A66118659F4FF274E7B73944D2219F5
.PARAMETER HashType
Optional. Defaults to SHA-256.
.PARAMETER BasePaths
Optional. Limit your search to specific parent directories. When running stand-
alone, this can be an array. Kansa currenlty accepts only a sinlge path. Defaults
to all local disks.
.PARAMETER extRegex
Optional but highly recommended. Files must match the regex to be hashed.
.PARAMETER MinB
Optional. Minimum size of files to check in bytes. Defaults to 4096.
.PARAMETER MaxB
Optional. Maximum size of files to check in bytes. Defaults to 10485760.
.NOTES
OUTPUT TSV
When passing specific modules with parameters via Kansa.ps1's -ModulePath 
parameter, be sure to quote the entire string, like shown here:
.\kansa.ps1 -ModulePath ".\Modules\Disk\Get-FilesByHash.ps1 9E2639ECE5631BAB3A41E3495C1DC119,MD5,C:\,\.ps1$"

As a note of warning, when reading files from %windir%\System32, if you are 
running in a 32-bit PowerShell instance on a 64-bit system the Windows 
filesystem API will transparently redirect your calls to %windir%\SysWOW64
instead, as documented in https://github.com/davehull/Kansa/issues/41. Using 
the path %windir%\Sysnative will direct these calls to the 64-bit versions of 
the applications (thanks @lanatmwan for the pointer to 
http://msdn.microsoft.com/en-us/library/windows/desktop/aa384187(v=vs.85).aspx).
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
        [String]$FileHash,
    [Parameter(Mandatory=$False,Position=2)]
        [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [string]$HashType = "SHA256",
    [Parameter(Mandatory=$False,Position=3)]
        [String]$BasePaths,
    [Parameter(Mandatory=$False,Position=4)]
        [String]$extRegex="\.(exe|sys|dll|ps1)$",
    [Parameter(Mandatory=$False,Position=5)]
        [int]$MinB=4096,
    [Parameter(Mandatory=$False,Position=6)]
        [int]$MaxB=10485760
) 

$ErrorActionPreference = "Continue"

function Get-LocalDrives
{
    # DriveType 3 is localdisk as opposed to removeable. Details: http://msdn.microsoft.com/en-us/library/aa394173%28v=vs.85%29.aspx
    foreach ($disk in (Get-WmiObject win32_logicaldisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID)) {
        [string[]]$drives += "$disk\"
    }
    
    $driveCount = $drives.Count.ToString()
    Write-Verbose "Found $driveCount local drives."
    return $drives
}

workflow Get-HashesWorkflow {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
			[String]$BasePath,
		[Parameter(Mandatory=$True,Position=1)]
			[string]$SearchHash,
		[Parameter(Mandatory=$True,Position=2)]
			[ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
			[string]$HashType = "SHA256",
		[Parameter(Mandatory=$False,Position=3)]
			[int]$MinB=4096,
		[Parameter(Mandatory=$False,Position=4)]
			[int]$MaxB=10485760,
		[Parameter(Mandatory=$False,Position=5)]
			[string]$extRegex="\.(exe|sys|dll|ps1)$"
	)

	# Workflows are how PowerShell does multi-threading. The parent process 
	# spawns multiple child processes, which each receive the code contained 
	# within the parallel block. Once fed to a child, each command will run in 
	# non-deterministic order unless they are placed inside a sequence block. 
	# 
	# One problem we encountered when testing is that if the target host uses 
	# an SSD, this can max out that machine's CPU. I may expose the parameter 
	# to force single-threaded execution in the future.
	#
	# References:
	#   http://blogs.technet.com/b/heyscriptingguy/archive/2012/11/20/use-powershell-workflow-to-ping-computers-in-parallel.aspx
	#   http://blogs.technet.com/b/heyscriptingguy/archive/2012/12/26/powershell-workflows-the-basics.aspx
	#   http://blogs.technet.com/b/heyscriptingguy/archive/2013/01/02/powershell-workflows-restrictions.aspx
	#   http://blogs.technet.com/b/heyscriptingguy/archive/2013/01/09/powershell-workflows-nesting.aspx
	
	$hashList = @()
	
	$Files = (
		Get-ChildItem -Force -Path $basePath -Recurse -ErrorAction SilentlyContinue | 
		? -FilterScript { 
			($_.Length -ge $MinB -and $_.Length -le $_.Length) -and 
			($_.Extension -match $extRegex) 
		} | 
		Select-Object -ExpandProperty FullName
	)

	foreach -parallel ($File in $Files) {
        
		sequence {
			$entry = inlinescript {
				switch -CaseSensitive ($using:HashType) {
					"MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
					"SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
					"SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
					"SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
					"SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
					"RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
				}

				# -Message variable name required because workflows do not support possitional parameters.
				Write-Debug -Message "Calculating hash of $using:File."
				if (Test-Path -LiteralPath $using:File -PathType Leaf) {
					$FileData = [System.IO.File]::ReadAllBytes($using:File)
					$HashBytes = $hash.ComputeHash($FileData)
					$paddedHex = ""

					foreach( $byte in $HashBytes ) {
						$byteInHex = [String]::Format("{0:X}", $byte)
						$paddedHex += $byteInHex.PadLeft(2,"0")
					}
                
					Write-Debug -Message "Hash value was $paddedHex."
					if ($paddedHex -ieq $using:searchHash) {
						$using:File
					}
				}
			}
            if ($entry) {
			    $workflow:hashList += ,$entry
            }
		}
    }

	return ,$hashList
}

function Get-Hashes {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
			[String]$BasePath,
		[Parameter(Mandatory=$True,Position=1)]
			[string]$SearchHash,
		[Parameter(Mandatory=$True,Position=2)]
			[ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
			[string]$HashType = "SHA256",
		[Parameter(Mandatory=$False,Position=3)]
			[int]$MinB=4096,
		[Parameter(Mandatory=$False,Position=4)]
			[int]$MaxB=10485760,
		[Parameter(Mandatory=$False,Position=5)]
			[string]$extRegex="\.(exe|sys|dll|ps1)$"
	)

	# Single-threaded option since we ran into a few situations while testing 
	# where workflows aren't available.

	$hashList = @()
	
	$Files = (
		Get-ChildItem -Force -Path $basePath -Recurse -ErrorAction SilentlyContinue | 
		? -FilterScript { 
			($_.Length -ge $MinB -and $_.Length -le $_.Length) -and 
			($_.Extension -match $extRegex) 
		} | 
		Select-Object -ExpandProperty FullName
	)
	
	switch -CaseSensitive ($HashType) {
		"MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
		"SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
		"SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
		"SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
		"SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
		"RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
	}
	
	foreach ($File in $Files) {
       
		Write-Debug -Message "Calculating hash of $File."
		if (Test-Path -LiteralPath $File -PathType Leaf) {
			$FileData = [System.IO.File]::ReadAllBytes($File)
			$HashBytes = $hash.ComputeHash($FileData)
			$paddedHex = ""

			foreach( $byte in $HashBytes ) {
				$byteInHex = [String]::Format("{0:X}", $byte)
				$paddedHex += $byteInHex.PadLeft(2,"0")
			}
               
			Write-Debug -Message "Hash value was $paddedHex."
			if ($paddedHex -ieq $searchHash) {
				$hashList += ,$file
			}
		}
	}

	return ,$hashList
}

function Get-Matches {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
			[String]$BasePath,
		[Parameter(Mandatory=$True,Position=1)]
			[string]$SearchHash,
		[Parameter(Mandatory=$True,Position=2)]
			[ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
			[string]$HashType = "SHA256",
		[Parameter(Mandatory=$False,Position=3)]
			[int]$MinB=4096,
		[Parameter(Mandatory=$False,Position=4)]
			[int]$MaxB=10485760,
		[Parameter(Mandatory=$False,Position=5)]
			[string]$extRegex="\.(exe|sys|dll|ps1)$"
	)
	
	# Check if we're in a WOW64 situation. Thanks to MagicAndi on StackOverflow for this check.
	# WOW64 doesn't support workflows (as far as I can tell) and has path redirection for the
	# System32 directory (see module .SYNOPSIS).
	if ((Test-Path env:\PROCESSOR_ARCHITEW6432) -and ([Intptr]::Size -eq 4)) {
		$sysRegex = $env:SystemDrive.ToString() + "\\($|windows($|\\($|system32($|\\))))"
		if ($BasePath -match $sysRegex) {
			Write-Verbose  "Searching %windir%\System32 with a 32-bit process on a 64-bit host can return false negatives. See comments in Get-FilesByHash.ps1 module for details."
		}
	}

	$HashType = $HashType.ToUpper()

	try {
		$hashList = Get-HashesWorkflow -BasePath $BasePath -SearchHash $FileHash -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
	}
	catch {
		Write-Verbose -Message "Workflows not supported. Running in single-threaded mode."
		$hashList = Get-Hashes -BasePath $BasePath -SearchHash $FileHash -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
	}
    
    if ($hashList) {
		Write-Verbose "Found files matching hash $FileHash."    
		foreach($entry in $hashList) {
            $o = "" | Select-Object File, Hash
            $o.File = $entry
            $o.Hash = $FileHash
            $o
        }
    }
	else {
		Write-Verbose "Found no matching files."
	}
}

if ($BasePaths.Length -eq 0) {
    Write-Verbose "No path specified, enumerating local drives."
    $BasePaths = Get-LocalDrives
}

foreach ($basePath in $BasePaths) {
    Write-Verbose "Getting file hashes for $basePath."
    Get-Matches -BasePath $BasePath -SearchHash $FileHash -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
}