<# 
.SYNOPSIS
Get-FileHashes.ps1 hashes all files in the provided path.
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
.\kansa.ps1 -ModulePath ".\Modules\Disk\Get-FileHashes.ps1 MD5,C:\,\.ps1$"

As with all modules that take command line parameters, you should not put
quotes around the entry in the Modules.conf file.

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
    [Parameter(Mandatory=$False,Position=0)]
        [ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
        [string]$HashType = "SHA256",
    [Parameter(Mandatory=$False,Position=1)]
        [String]$BasePaths,
    [Parameter(Mandatory=$False,Position=2)]
        [String]$extRegex="\.(exe|sys|dll|ps1|psd1|psm1|vbs|bat|cmd)$",
    [Parameter(Mandatory=$False,Position=3)]
        [int]$MinB=4096,
    [Parameter(Mandatory=$False,Position=4)]
        [int]$MaxB=10485760
) 

$ErrorActionPreference = "Continue"

function Get-LocalDrives
{
    # DriveType 3 is localdisk as opposed to removeable. Details: http://msdn.microsoft.com/en-us/library/aa394173%28v=vs.85%29.aspx
    Get-WmiObject win32_logicaldisk -Filter "DriveType=3" | Select-Object -ExpandProperty DeviceID | ForEach-Object {
        $disk = $_
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
			[ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
			[string]$HashType = "SHA256",
		[Parameter(Mandatory=$False,Position=2)]
			[int]$MinB=4096,
		[Parameter(Mandatory=$False,Position=3)]
			[int]$MaxB=10485760,
		[Parameter(Mandatory=$False,Position=4)]
			[string]$extRegex="\.(exe|sys|dll|ps1|psd1|psm1|vbs|bat|cmd|jpg|aspx|asp|class|java|war|tmp)$"
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
		} 
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
				Write-Debug -Message "Calculating hash of ${using:File.FullName}."
				if (Test-Path -LiteralPath $using:File.Fullname -PathType Leaf) {
					$FileData = [System.IO.File]::ReadAllBytes($using:File.FullName)
					$HashBytes = $hash.ComputeHash($FileData)
					$paddedHex = ""

                    $HashBytes | ForEach-Object {
                        $byte = $_
						$byteInHex = [String]::Format("{0:X}", $byte)
						$paddedHex += $byteInHex.PadLeft(2,"0")
					}
                
					Write-Debug -Message "Hash value was $paddedHex."
                    $($paddedHex + ":-:" + $using:File.FullName + ":-:" + $using:File.Length + ":-:" + $using:File.LastWriteTime)
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
			[ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
			[string]$HashType = "SHA256",
		[Parameter(Mandatory=$False,Position=2)]
			[int]$MinB=4096,
		[Parameter(Mandatory=$False,Position=3)]
			[int]$MaxB=10485760,
		[Parameter(Mandatory=$False,Position=4)]
			[string]$extRegex="\.(exe|sys|dll|ps1|psd1|psm1|vbs|bat|cmd)$"
	)

	# Single-threaded option since we ran into a few situations while testing 
	# where workflows aren't available.

	$hashList = @()
	
	$Files = (
		Get-ChildItem -Force -Path $basePath -Recurse -ErrorAction SilentlyContinue | 
		? -FilterScript { 
			($_.Length -ge $MinB -and $_.Length -le $_.Length) -and 
			($_.Extension -match $extRegex) 
		} 
	)
	
	switch -CaseSensitive ($HashType) {
		"MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
		"SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
		"SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
		"SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
		"SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
		"RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
	}
	
    foreach ($file in $Files) {
       
		Write-Debug -Message "Calculating hash of ${File.FullName}."
		if (Test-Path -LiteralPath $File.FullName -PathType Leaf) {
			$FileData = [System.IO.File]::ReadAllBytes($File.FullName)
			$HashBytes = $hash.ComputeHash($FileData)
			$paddedHex = ""

            foreach ($byte in $HashBytes) {
				$byteInHex = [String]::Format("{0:X}", $byte)
				$paddedHex += $byteInHex.PadLeft(2,"0")
			}
               
			Write-Debug -Message "Hash value was $paddedHex."

            $hashList += $($paddedHex + ":-:" + $file.FullName + ":-:" + $file.Length + ":-:" + $file.LastWriteTime)
		}
	}

	return ,$hashList
}

function Get-Hash {
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory=$True,Position=0)]
			[String]$BasePath,
		[Parameter(Mandatory=$True,Position=1)]
			[ValidateSet("MD5","SHA1","SHA256","SHA384","SHA512","RIPEMD160")]
			[string]$HashType = "SHA256",
		[Parameter(Mandatory=$False,Position=2)]
			[int]$MinB=4096,
		[Parameter(Mandatory=$False,Position=3)]
			[int]$MaxB=10485760,
		[Parameter(Mandatory=$False,Position=4)]
			[string]$extRegex="\.(exe|sys|dll|ps1|psd1|psm1|vbs|bat|cmd)$"
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

    if ($psversiontable.version.major -gt 2.0) {
    	try {
	    	$hashList = Get-HashesWorkflow -BasePath $BasePath -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
	    }
	    catch {
		    Write-Verbose -Message "Workflows not supported. Running in single-threaded mode."
		    $hashList = Get-Hashes -BasePath $BasePath -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
	    }
    } else {
        Write-Verbose -Message "Workflows not supported. Running in single-threaded mode."
		$hashList = Get-Hashes -BasePath $BasePath -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
    }

    $o = "" | Select-Object File, Hash, Length, LastWritetime
    if ($hashList) {
        $hashList | ForEach-Object {
            $hash,$file,$length,$lastWritetime = $_ -split ":-:"
            $o.File = $file
            $o.Hash = $hash
            $o.Length = $length
            $o.LastWriteTime = $lastWritetime
            $o
        }
    } else {
        $o.File = $null
        $o.Hash = $null
        $o.Length = $null
        $o.LastWriteTime = $null
        $o
    }
}

if ($BasePaths.Length -eq 0) {
    Write-Verbose "No path specified, enumerating local drives."
    $BasePaths = Get-LocalDrives
}


$BasePaths | ForEach-Object {
    $basePath = $_
    Write-Verbose "Getting file hashes for $basePath."
    Get-Hash -BasePath $BasePath -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
}
