<#
.SYNOPSIS
Author: Joseph Kjar
Date: 02/2017
This script acts as a front-end for Kansa with the primary purpose of invoking various
Kansa instances on a set of distributed systems. The parameters for this script match
those for Kansa itself to help users construct the proper command to be executed. The
few unique parameters are listed/explained below.

.PARAMETER KansaServers
This is a file that contains a list of systems (preferably servers in a datacenter
with high-speed backbone network connections to any target systems), one per line.
These systems must all have a copy of the Kansa repo located in the same folder.

.PARAMETER KansaRemotePath
This allows the user to specify the remote path where the kansa scripts/reppository
are located to assist with remote kansa invocation across a distributed set of 
servers.

.PARAMETER Overwrite
The overwrite switch/flag tells the kansa-launcher to overwrite existing modules when
they are uploaded to each of the Kansa servers.  This ensures that the latest version
of a module on an analyst's workstation is propagated to all of the distributed 
Kansa servers at runtime.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ModulePath="Modules\",
    [Parameter(Mandatory=$False,Position=1)]
        [String]$TargetList=$Null,
    [Parameter(Mandatory=$False,Position=2)]
        [String]$Target=$Null,
    [Parameter(Mandatory=$False,Position=3)]
        [String]$KansaServers="kansa_servers.txt",
    [Parameter(Mandatory=$False,Position=4)]
        [System.Management.Automation.PSCredential]$Credential=$Null,
    [Parameter(Mandatory=$False,Position=5)]
    [ValidateSet("CSV","JSON","TSV","XML", "HYBRID")]
        [String]$OutputFormat="JSON",
    [Parameter(Mandatory=$False,Position=6)]
        [Switch]$Pushbin,
    [Parameter(Mandatory=$False,Position=7)]
        [Switch]$Rmbin,
    [Parameter(Mandatory=$False,Position=8)]
        [Int]$ThrottleLimit=200,
    [Parameter(Mandatory=$False,Position=9)]
    [ValidateSet("Ascii","BigEndianUnicode","Byte","Default","Oem","String","Unicode","Unknown","UTF32","UTF7","UTF8")]
        [String]$Encoding="UTF8",
    [Parameter(Mandatory=$False,Position=10)]
        [Switch]$ListModules,
	[Parameter(Mandatory=$false,Position=11)]
		[Switch]$AutoParse=$true,
    [Parameter(Mandatory=$false,Position=12)]
        [String[]]$ElkAlert=@(),
    [Parameter(Mandatory=$false,Position=13)]
        [String]$KansaLocalPath="$($PSScriptRoot)",
    [Parameter(Mandatory=$false,Position=14)]
        [String]$KansaRemotePath="F:\Kansa",
    [Parameter(Mandatory=$False,Position=15)]
        [int]$JobTimeout=600,
    [Parameter(Mandatory=$false,Position=16)]
        [int[]]$ElkPort=@(13651),
    [Parameter(Mandatory=$false,Position=17)]
        [Switch]$FireForget,
    [Parameter(Mandatory=$false,Position=18)]
        [String]$FFwrapper="Modules\FireForget\FFwrapper.ps1",
    [Parameter(Mandatory=$false,Position=19)]
        [hashtable]$FFArgs=@{delayedStart = $true; maxDelay = 3600; killSwitch = $true; killDelay = 1800; VDIcheck = $false; CPUpriority = "Idle" },
    [Parameter(Mandatory=$false,Position=20)]
        [String]$FFStagePath="Modules\FFStaging\",
    [Parameter(Mandatory=$false,Position=21)]
        [Switch]$Overwrite,
    [Parameter(Mandatory=$false,Position=22)]
        [String]$SafeWord="safeword",
    [Parameter(Mandatory=$false,Position=23)]
        [Switch]$noPrompt
)

function Validate-Creds{
    param(
    [Parameter(Mandatory=$True,Position=0)]
        [System.Management.Automation.PSCredential]$cred
    )
    $username = $cred.username
    $password = $cred.GetNetworkCredential().password

    # Get current domain using logged-on user's credentials
    $CurrentDomain = "LDAP://" + ([ADSI]"").distinguishedName
    $domain = New-Object System.DirectoryServices.DirectoryEntry($CurrentDomain,$UserName,$Password)

    if ($domain.name -eq $null)
    {
     Write-Warning "Authentication failed - please verify your username and password."
     exit #terminate the script.
    }
}

function Get-Modules {
<#
.SYNOPSIS
Looks for modules.conf in the $Modulepath, default is Modules. If found,
returns an ordered hashtable of script files and their arguments, if any. 
If no modules.conf is found, returns an ordered hashtable of all modules
found in $Modulepath, but no arguments will be present so scripts will
run with default params. A module is a .ps1 script starting with Get-.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$ModulePath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # ToDo: There should probably be some error handling in this function.

    Write-Debug "`$ModulePath is ${ModulePath}."

    # User may have passed a full path to a specific module, possibly with an argument
    $ModuleScript = ($ModulePath -split " ")[0]
    $ModuleArgs   = @($ModulePath -split [regex]::escape($ModuleScript))[1].Trim()

    $Modules = $FoundModules = @()
    # Need to maintain the order for "order of volatility"
    $ModuleHash = New-Object System.Collections.Specialized.OrderedDictionary

    if (!(ls $ModuleScript | Select-Object -ExpandProperty PSIsContainer)) {
        # User may have provided full path to a .ps1 module, which is how you run a single module explicitly
        $ModuleHash.Add((ls $ModuleScript), $ModuleArgs)

        if (Test-Path($ModuleScript)) {
            $Module = ls $ModuleScript | Select-Object -ExpandProperty BaseName
            Write-Verbose "Running module: `n$Module $ModuleArgs"
            Return $ModuleHash
        }
    }
    $ModConf = $ModulePath + "\" + "Modules.conf"
    if (Test-Path($Modconf)) {
        Write-Verbose "Found ${ModulePath}\Modules.conf."
        # ignore blank and commented lines, trim misc. white space
        Get-Content $ModulePath\Modules.conf | Foreach-Object { $_.Trim() } | ? { $_ -gt 0 -and (!($_.StartsWith("#"))) } | Foreach-Object { $Module = $_
            # verify listed modules exist
            $ModuleScript = ($Module -split " ")[0]
            $ModuleArgs   = ($Module -split [regex]::escape($ModuleScript))[1].Trim()
            $Modpath = $ModulePath + "\" + $ModuleScript
            if (!(Test-Path($Modpath))) {
                "WARNING: Could not find module specified in ${ModulePath}\Modules.conf: $ModuleScript. Skipping."
            } else {
                # module found add it and its arguments to the $ModuleHash
                $ModuleHash.Add((ls $ModPath), $Moduleargs)
                # $FoundModules += ls $ModPath # deprecated code, remove after testing
            }
        }
        # $Modules = $FoundModules # deprecated, remove after testing
    } else {
        # we had no modules.conf
        ls -r "${ModulePath}\Get-*.ps1" | Foreach-Object { $Module = $_
            $ModuleHash.Add($Module, $null)
        }
    }
    Write-Verbose "Running modules:`n$(($ModuleHash.Keys | Select-Object -ExpandProperty BaseName) -join "`n")"
    $ModuleHash
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Send-File {
	<#
	.SYNOPSIS
		This function sends a file (or folder of files recursively) to a destination WinRm session. This function was originally
		built by Lee Holmes (http://poshcode.org/2216) but has been modified to recursively send folders of files as well
		as to support UNC paths.

	.PARAMETER Path
		The local or UNC folder path that you'd like to copy to the session. This also support multiple paths in a comma-delimited format.
		If this is a UNC path, it will be copied locally to accomodate copying.  If it's a folder, it will recursively copy
		all files and folders to the destination.

	.PARAMETER Destination
		The local path on the remote computer where you'd like to copy the folder or file.  If the folder does not exist on the remote
		computer it will be created.

	.PARAMETER Session
		The remote session. Create with New-PSSession.

	.EXAMPLE
		$session = New-PSSession -ComputerName MYSERVER
		Send-File -Path C:\test.txt -Destination C:\ -Session $session

		This example will copy the file C:\test.txt to be C:\test.txt on the computer MYSERVER

	.INPUTS
		None. This function does not accept pipeline input.

	.OUTPUTS
		System.IO.FileInfo
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Destination,
		
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session
	)
	process
	{
		foreach ($p in $Path)
		{
			try
			{
				if ($p.StartsWith('\\'))
				{
					Write-Verbose -Message "[$($p)] is a UNC path. Copying locally first"
					Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine'))
					$p = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$($p | Split-Path -Leaf)"
				}
				if (Test-Path -Path $p -PathType Container)
				{
					Write-Log -Source $MyInvocation.MyCommand -Message "[$($p)] is a folder. Sending all files"
					$files = Get-ChildItem -Force -Path $p -File -Recurse
					$sendFileParamColl = @()
					foreach ($file in $Files)
					{
						$sendParams = @{
							'Session' = $Session
							'Path' = $file.FullName
						}
						if ($file.DirectoryName -ne $p) ## It's a subdirectory
						{
							$subdirpath = $file.DirectoryName.Replace("$p\", '')
							$sendParams.Destination = "$Destination\$subDirPath"
						}
						else
						{
							$sendParams.Destination = $Destination
						}
						$sendFileParamColl += $sendParams
					}
					foreach ($paramBlock in $sendFileParamColl)
					{
						Send-File @paramBlock
					}
				}
				else
				{
					Write-Verbose -Message "Starting WinRM copy of [$($p)] to [$($Destination)] on [$($Session.ComputerName)]"
					# Get the source file, and then get its contents
					$sourceBytes = [System.IO.File]::ReadAllBytes($p);
					$streamChunks = @();
					
					# Now break it into chunks to stream.
					$streamSize = 1MB;
					for ($position = 0; $position -lt $sourceBytes.Length; $position += $streamSize){
						$remaining = $sourceBytes.Length - $position
						$remaining = [Math]::Min($remaining, $streamSize)
						
						$nextChunk = New-Object byte[] $remaining
						[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
						$streamChunks +=, $nextChunk
					}
					$remoteScript = {
						if (-not (Test-Path -Path $using:Destination -PathType Container)){
							$null = New-Item -Path $using:Destination -Type Directory -Force
						}
                        if ($Overwrite -and (Test-Path -Path "$using:Destination\$($using:p | Split-Path -Leaf)" -PathType Leaf)){
							$null = Remove-Item "$using:Destination\$($using:p | Split-Path -Leaf)"
						}
						$fileDest = "$using:Destination\$($using:p | Split-Path -Leaf)"
						## Create a new array to hold the file content
						$destBytes = New-Object byte[] $using:length
						$position = 0
						
						## Go through the input, and fill in the new array of file content
						foreach ($chunk in $input)
						{
							[GC]::Collect()
							[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
							$position += $chunk.Length
						}
						
						[IO.File]::WriteAllBytes($fileDest, $destBytes)
						
						Get-Item -Force $fileDest
						[GC]::Collect()
					}
					
					# Stream the chunks into the remote script.
					$Length = $sourceBytes.Length
					$streamChunks | Invoke-Command -Session $Session -ScriptBlock $remoteScript
					Write-Verbose -Message "WinRM copy of [$($p)] to [$($Destination)] on [$($Session.ComputerName)] complete"
				}
			}
			catch
			{
				Write-Error $_.Exception.Message
			}
		}
	}
	
}

function Check-Busy {
    param($KansaHostSessions)

    $availableSessions = New-Object System.Collections.ArrayList

    foreach ($s in $KansaHostSessions){
        $InUse = Invoke-Command -Session $s -ScriptBlock {
            if (Test-Path "$($args[0])\IN_USE_BY_*"){
                $BusyUser = Get-ChildItem "$($args[0])\IN_USE_BY_*" | select Name
                $BusyUser = $BusyUser.Name.Split("_")[-1]
                $BusyUser
            }
        } -ArgumentList $KansaRemotePath

        if ($InUse){
            Write-Warning "Kansa is in use by $InUse on $($s.ComputerName). This host will not be used for scanning"
        }
        else{
            [void]$availableSessions.add($s)
        }
    }
    if ($availableSessions.Count -ge 1){
        return $availableSessions
    }
    else{
        Write-Warning "No available kansa hosts found, exiting"
        Remove-PSSession -Name *
        exit
    }
}

function Launch-Kansa {
    param($KansaHostSessions)
    
    $ServerCount = $KansaHostSessions.Count

    if ($TargetList){
        $TargetNames = Get-Content $TargetList
        $TargetCount = $TargetNames.Count
    }
    else{
        $TargetNames = $Target
        $TargetCount = $TargetNames.Count
    }
    
    $TargetsPerHost = [math]::Ceiling($TargetCount/$ServerCount)

    $index = 0
    foreach ($i in 0..$($ServerCount-1)){

        if ($ModulePath -eq "Modules\"){
            $null = Send-File -Path $KansaLocalPath\Modules\Modules.conf -Destination $KansaRemotePath\Modules -Session $KansaHostSessions[$i]
        }
        else {
            $ModulePathNoParams = $modulepath.Split(" ")[0]
            $ModuleExists = Invoke-Command -Session $KansaHostSessions[$i] -ScriptBlock { Test-Path "$($args[0])\$($args[1])" } -ArgumentList $KansaRemotePath,$ModulePathNoParams
            if (($ModuleExists -eq $false) -or ($Overwrite)){
                if($ModuleExists){
                    Write-Warning "Module $ModulePath already exists on remote host. Module will be overwritten"
                }else {
                    Write-Warning "Module $ModulePath not found on remote host. Module will be auto-uploaded to Kansa server"
                }                
                $remoteModulePath = $ModulePath.Substring(0,$($ModulePath.LastIndexOf("\")))
                $null = Send-File -Path $KansaLocalPath\$ModulePath -Destination $KansaRemotePath\$remoteModulePath -Session $KansaHostSessions[$i]
                if($FireForget){
                    $FFwrapperPath = $FFwrapper.Substring(0,$($FFwrapper.LastIndexOf("\")))
                    $null = Send-File -Path $KansaLocalPath\$FFwrapper -Destination $KansaRemotePath\$FFwrapperPath -Session $KansaHostSessions[$i]
                }
            }
        }

        if ($TargetList){
            $targetGroup = $TargetNames[$index..$($index+$TargetsPerHost-1)]
            $targetGroup | Out-File $KansaLocalPath\temptargets_$i.txt
            $null = Send-File -Path $KansaLocalPath\temptargets_$i.txt -Destination $KansaRemotePath -Session $KansaHostSessions[$i]
            $RemoteTargetListPath = "$KansaRemotePath\temptargets_$i.txt"
            Remove-Item -Path $KansaLocalPath\temptargets_$i.txt
        }
        else{
            $RemoteTargetListPath = $null
        }

        Write-Host "invoking the following command:"
        write-host "cd $KansaRemotePath; .\kansa.ps1 $ModulePath $RemoteTargetListPath $Target $TargetCount $Credential $OutputFormat $Pushbin $Rmbin $ThrottleLimit $Encoding $false $ListModules $false $false $false $false $false 5985 kerberos 10 $autoparse $ElkAlert $JobTimeout $ElkPort $FireForget $FFwrapper $FFArgs $FFStagePath $SafeWord"
        Write-Host "------------------------`n"

        Invoke-Command -Session $KansaHostSessions[$i] -AsJob -JobName "RemoteKansaJob_$($KansaHostSessions[$i].ComputerName)" -ScriptBlock {
            cd $args[0]; .\kansa.ps1 $args[1] $args[2] $args[3] $args[4] $args[5] $args[6] $args[7] $args[8] $args[9] $args[10] $args[11] $args[12] $args[13] $args[14] $args[15] $args[16] $args[17] $args[18] $args[19] $args[20] $args[21] $args[22] $args[23] $args[24] $args[25] $args[26] $args[27] $args[28] $args[29] > "$($args[0])\currentRunlog.txt"
        } -ArgumentList $KansaRemotePath,$ModulePath,$RemoteTargetListPath,$Target,$TargetCount,$Credential,$OutputFormat,$Pushbin,$Rmbin,$ThrottleLimit,$Encoding,$false,$ListModules,$false,$false,$false,$false,$false,5985,"Kerberos",10,$AutoParse,$ElkAlert,$JobTimeout,$ElkPort,$FireForget,$FFwrapper,$FFArgs,$FFStagePath,$SafeWord

        $index += $TargetsPerHost
        if ($index -ge $TargetCount){break}
    }
}

if (($KansaServers -eq $Null) -or !$(Test-Path $KansaServers)){
    Write-Warning "A valid list of kansa servers could not be found, please supply a path to a valid list of servers."
    exit
}

if ($KansaRemotePath -eq $Null){
    Write-Warning "You must specify a path to kansa.ps1 on the kansa servers (e.g. F:/kansa)"
    exit
}

if ($Credential -eq $Null){
    Write-Host "A valid credential is required. Please enter the credentials for the Kansa account:"
    $Credential = Get-Credential -Message "Please enter the credentials for the Kansa account"
}

Validate-Creds $Credential

if (($TargetList.Length -eq 0) -and ($Target.Length -eq 0)){
    Write-Warning "No target(s) specified, you must specify targets"
    exit
}
elseif ($TargetList.Length -gt 0 -and $Target.Length -gt 0){
    Write-Error "Invalid target configuration, please try again" 
    exit
}

$Modules = Get-Modules $KansaLocalPath\$ModulePath

# Get the command name
$CommandName = $PSCmdlet.MyInvocation.InvocationName;
# Get the list of parameters for the command
$ParameterList = (Get-Command -Name $CommandName).Parameters;

Write-Host "Kansa will be invoked with the following options: "

# Grab each parameter value, using Get-Variable
foreach ($Parameter in $ParameterList) {
    Get-Variable -Name $Parameter.Values.Name -ErrorAction SilentlyContinue;
    Write-Host ""
}

Write-Host "Kansa Hosts:"
$hosts = Get-Content $KansaServers
$hosts
Write-Host ""

Write-Host "Modules to execute:"
$Modules | ft -AutoSize -HideTableHeaders

$continue = "no"
if($noPrompt){
    $continue = "yes"
}else{
    $continue = Read-Host "Are these options correct (y/n)? "
}

if ($continue -like "y*"){

    # First check to see if WinRM is enabled on all servers. If not, enable it.
    $remoteHosts = New-Object System.Collections.ArrayList
    foreach ($khost in $hosts){
        try{
            $WinRMService = Get-WmiObject -Class Win32_Service -ComputerName $khost -Credential $Credential -Filter "Name='winrm'"
            if ($WinRMService.Started -eq $false){
                Write-Warning "WinRM was not running on $khost, attempting to start service..."
                $startResult = $WinRMService.StartService()
                $WinRMService = Get-WmiObject -Class Win32_Service -ComputerName $khost -Credential $Credential -Filter "Name='winrm'"
                if ($WinRMService.Started){[void]$remoteHosts.Add($khost); Write-Host "Success!`n"}
                else{ Write-Warning "Service failed to start!" }
            }
            else{
                [void]$remoteHosts.Add($khost)
            }
        }
        catch{
            Write-Warning "An error occured while attempting to enable WinRM on $khost. Kansa will not use this server."
        }
    }

    # Connect and check to see if Kansa is in use on any of the specified servers
    Write-Host "Connecting to servers via WinRM. Please be patient..."
    $KansaHostSessions = New-PSSession -ComputerName $remoteHosts -Credential $Credential -SessionOption (New-PSSessionOption -NoMachineProfile -OpenTimeout 2000 -OperationTimeout 5000 -CancelTimeout 5000)
    
    Write-Host "Checking if servers are busy..."
    $KansaHostSessions = Check-Busy $KansaHostSessions
    Write-Host "Found $($KansaHostSessions.Count) available servers"

    $availableHosts = New-Object System.Collections.ArrayList
    foreach ($sess in $KansaHostSessions){
        [void]$availableHosts.Add($sess.ComputerName)
    }
    Write-Host "The following servers will be used for this scan:"
    foreach ($h in $availableHosts){Write-Host $h}
    Write-Host "------------------------"

    # The Launch-Kansa function invokes Kansa on the specified list of remote servers.
    Write-Host "Launching kansa..."
    Launch-Kansa $KansaHostSessions

    $kansaJobs = New-Object System.Collections.ArrayList
    foreach ($Session in $KansaHostSessions){
        $ServerJob = Get-Job -Name "RemoteKansaJob_$($Session.ComputerName)" -ErrorAction SilentlyContinue
        [void]$kansaJobs.Add($ServerJob)
    }

    # Every 60 seconds, check to see if the job progress has been updated and report it
    do{
        sleep 60
        Write-Host "`n############### $(Get-Date) ###############`n"
        foreach ($j in $kansaJobs.ChildJobs){
            Write-host "Progress on $($j.location): `n$($j.Verbose)`n------------------------`n"
        }
    } while($kansaJobs.State -eq "Running")

    # Measure all job times and report the longest-running job as the total scan time.
    $jobTimes = New-Object System.Collections.ArrayList
    foreach ($j in $kansaJobs){
        $jobTime = $j.PSEndTime - $j.PSBeginTime
        [void]$jobTimes.Add($jobTime)
    }
    $maxTime = $jobTimes | Measure-Object -Maximum
    $maxTime = $maxTime.Maximum

    [console]::WriteLine("Total run time: {0:g}", $maxTime)

    Write-Host "All remote jobs complete!"
    Write-Host "`n------------------------`n"

     # Clean up
    Remove-Job -Name * | Out-Null
    Remove-PSSession -Name *
}
else{
    Write-Host "Exiting..."
    exit
}
