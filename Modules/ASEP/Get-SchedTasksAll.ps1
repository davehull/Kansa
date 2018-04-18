<#
.SYNOPSIS
Get-SchedTasksAll.ps1 returns information about all Windows Scheduled Tasks and the associated binaries

.NOTES
schtasks.exe output is not that good.  It needs to be parsed to remove redundant headers.

#>

function Get-MyFileHash {
	param
	(
		[Parameter(Mandatory = $true)]
		[String]$Path,
		[String]$Algorithm
	)
	if ($PSVersionTable.PSVersion.Major -ge 4) {
		try {
			return get-filehash -Path $Path -Algorithm $Algorithm -ErrorAction Stop
		}
		catch {
			$return = New-Object -typename PSObject -Property @{
				Hash	 = "PermissionDenied"
			}
			return $return
		}
	}
	try {
		$file = [System.IO.File]::Open($Path, [System.IO.Filemode]::Open, [System.IO.FileAccess]::Read)
	}
	catch {
		#Failed to open file for reading, nothing to do, just return
		$return = New-Object -typename PSObject -Property @{
			Hash    = "NoHashComputed"
		}
		return $return
	}
	try {
		$md5 = new-object -TypeName System.Security.Cryptography.MD5CryptoServiceProvider
		$hash = ([System.BitConverter]::ToString($md5.ComputeHash($file))) -replace "-", ""
		$return = New-Object -TypeName PSObject -Property @{
			Hash	 = $hash
		}
	}
	finally {
		$file.Dispose()
	}
	$return
}
# Run schtasks and convert csv to object
#schtasks returns duplicate header rows, so we'll ignore those
$tasks = (schtasks /query /FO CSV /v | ConvertFrom-Csv) | ? { $_.HostName -ne 'HostName' }

#Parse tasks, find binaries, calculate hashes
#Ignore the "COM handler" as we can't extract useful information from those tasks
#foreach ($task in $tasks | ?{$_.'Task to Run' -ne 'COM handler') {
foreach ($task in $tasks) {
	$BinaryHash = ""
	try {
		if ($task.'Task To Run' -match '(\w\:|%\w+%)\\([\w ]+\\)+[\w ]+(.exe|.com|.bat)') {
			$BinaryPath = [System.Environment]::ExpandEnvironmentVariables($Matches[0]).ToLower()
			if (Test-Path $BinaryPath -ErrorAction Stop) {
				$BinaryHash = Get-MyFileHash -Path $BinaryPath -Algorithm md5
				$task | Add-Member -MemberType NoteProperty -Name BinaryHash -Value $BinaryHash.Hash
				$task | Add-Member -MemberType NoteProperty -Name BinaryPath -Value $BinaryPath
			}
			else {
				$task | Add-Member -MemberType NoteProperty -Name BinaryHash -Value "TestPath Failed"
			}
			#If path is rundll, extract dll name and hash
			if ($task.'task to run' -match '\\rundll32.exe') {
				$task.'task to run' -match '\w+\.dll' | Out-Null
				$dllPath = "c:\Windows\System32\$($Matches[0])"
				if (Test-Path $dllPath -ErrorAction Stop) {
					$dllHash = Get-MyFileHash -Path $dllPath -Algorithm md5
					$task | Add-Member -MemberType NoteProperty -Name dllHash -Value $dllHash.Hash
					$task | Add-Member -MemberType NoteProperty -Name dllPath -Value $dllPath
				}
			}
		}
	}
	catch {
		#Write-Error "Failed to access binary path.  Likely permissions issue, or scheduled task references a binary that no longer exists"
		#Write-Error $_.Exception.Message
	}
}
#Specify the field order to ensure that individual computers all print out
#the fields in the exact same way so we can do analytics on them.
$fields = 'Next Run Time', 'Status', 'Logon Mode', 'Last Run Time', 'Last Result', 'Author'
$fields += 'Task To Run', 'Start In', 'Comment','Scheduled Task State', 'Run As User'
$fields += 'Schedule Type', 'Start Time', 'Start Date', 'End date', 'Days', 'Months'
$fields += 'Repeat: Every', 'Repeat: Until: Time', 'Repeat: Until: Duration', 'Repeat: Stop If Still Running'
$fields += 'BinaryPath', 'BinaryHash', 'dllPath', 'dllHash'

$tasks | Select-Object $fields
#$tasks | select 'Author' -First 5
#$tasks
