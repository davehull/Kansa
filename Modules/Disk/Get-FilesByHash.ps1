# OUTPUT TSV
# Get-FilesByHash.ps1 scans the local disks for files matching the provided
# hash. Defaults to SHA-256. For example cmd.exe's hash (on Windows 8.1)
# is 0B9BC863E2807B6886760480083E51BA8A66118659F4FF274E7B73944D2219F5

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

<#
($FileHash, $HashType, $BasePaths, $extRegex, $MinB, $MaxB) -join "|"
exit
#>

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

	$hashList = @()
	
	$Files = (
		Get-ChildItem -Path $basePath -Recurse -ErrorAction SilentlyContinue | 
		? -FilterScript { 
			($_.Length -ge $MinB -and $_.Length -le $_.Length) -and 
			($_.Extension -match $extRegex) 
		} | 
		Select-Object -ExpandProperty FullName
	)

	foreach -parallel ($File in $Files) {
        
		sequence {
			$workflow:hashList += inlinescript {
				switch -CaseSensitive ($using:HashType) {
					"MD5"       { $hash = [System.Security.Cryptography.MD5]::Create() }
					"SHA1"      { $hash = [System.Security.Cryptography.SHA1]::Create() }
					"SHA256"    { $hash = [System.Security.Cryptography.SHA256]::Create() }
					"SHA384"    { $hash = [System.Security.Cryptography.SHA384]::Create() }
					"SHA512"    { $hash = [System.Security.Cryptography.SHA512]::Create() }
					"RIPEMD160" { $hash = [System.Security.Cryptography.RIPEMD160]::Create() }
					#default     { Write-Error -Message "Invalid hash type selected." -Category InvalidArgument }
				}

				# -Message variable name required because workflows do not support possitional parameters.
				Write-Verbose -Message "Calculating hash of $using:File."
				if (Test-Path -LiteralPath $using:File -PathType Leaf) {
					$FileData = [System.IO.File]::ReadAllBytes($using:File)
					$HashBytes = $hash.ComputeHash($FileData)
					$paddedHex = ""

					foreach( $byte in $HashBytes ) {
						$byteInHex = [String]::Format("{0:X}", $byte)
						$paddedHex += $byteInHex.PadLeft(2,"0")
					}
                
					Write-Verbose -Message "Hash value was $paddedHex."
					if ($paddedHex -ieq $using:searchHash) {
						($file, $paddedHex)
					}
				}
			}
		}
    }

	if ($hashList.Count -gt 0) {
		return $hashList
	}
	else {
		return $false
	}
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

	$HashType = $HashType.ToUpper()
    $hashList = Get-HashesWorkflow -BasePath $BasePath -SearchHash $FileHash -HashType $HashType -extRegex $extRegex -MinB $MinB -MaxB $MaxB
    
    if ($hashList) {
		$hashCount = $hashList.Count.ToString()
		Write-Verbose "Found $hashCount matching files."    
		#foreach($key in $hashList.Keys) {
  #          $o = "" | Select-Object File, Hash
  #          $o.File = $key
  #          $o.Hash = $($hashList.$key)
  #          $o
  #      }
		$hashList | gm -view all # Hmm, no output at all...
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