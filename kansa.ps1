<#
.SYNOPSIS
Kansa is the ame for the modular rewrite of Mal-Seine.
.DESCRIPTION
In this modular version of Mal-Seine, Kansa looks for a modules.conf
file in the -Modules directory. If one is found, it will control which 
modules execute and in what order. If no modules.conf is found, all 
modules will be executed in the order that ls reads them.

After parsing modules.conf or the -Modules path, Kansa will execute
each module on each target (remote hosts) and write the output to a
folder named for each module in the -Output path. Each target will have
its data written to separate files.

For example, the Get-PrefetchListing.ps1 module data will be written
to Output\PrefetchListing\Hostname-PrefetchListing.txt.

If a module returns Powershell objects, its data can be written out in
one of several file formats, including bin, csv, tsv and xml. Modules that
return text should choose the txt output format. The first line of each 
module should contain a comment specifying the output format, following
this format:

# OUTPUT xml

This script was written to avoid the need for CredSSP, therefore 
"second-hops" must be avoided. For more details on this see:

http://trustedsignal.blogspot.com/2014/04/kansa-modular-live-response-tool-for.html

The script assumes you will have administrator level privileges on
target hosts, though such privileges may not be required by all modules.

If you run this script without the -TargetList argument, Remote Server
Administration Tools (RSAT), is required. These are available from Microsoft's 
Download Center for Windows 7 and 8. You can search for RSAT at:

http://www.microsoft.com/en-us/download/default.aspx

.PARAMETER ModulePath
An optional parameter that specifies the path to the collector modules.
.PARAMETER TargetList
An optional list of servers from the current forest to collect data from.
In the absence of this parameter, collection will be attempted against 
all hosts in the current forest.
.PARAMETER TargetCount
An optional parameter that specifies the maximum number of targets.
.PARAMETER Credential
An optional credential that the script will use for execution. Use the
$Credential = Get-Credential convention to populate a suitable variable.
.PARAMETER Pushbin
An optional flag that causes Kansa to push required binaries to the 
ADMIN$ shares of targets. Modules that need to work with Pushbin, must 
include the "# BINDEP <binary>" directive on the second line of their 
script and users of Kansa must copy the required <binary> to the 
Modules\bin\ folder.

For example, the Get-Autorunsc.ps1 collector has a binary dependency on
Sysinternals Autorunsc.exe. The second line of Get-Autorunsc.ps1 contains
the "# BINDEP autorunsc.exe" directive and a copy of autorunsc.exe is placed 
in the Modules\bin folder. If Kansa is run with the -Pushbin flag, it will 
attempt to copy autorunsc.exe from the Modules\bin path to the ADMIN$ share 
of each remote host. If your required binaries are already present on
each target and in the path where the modules expect them to be, you can 
omit the -Pushbin flag and save the step of copying binaries.
.PARAMETER Ascii
An optional switch that tells Kansa you want all text output (i.e. txt,
csv and tsv) and errors be written as Ascii. Unicode is the default.
.PARAMETER UpdatePath
An option switch that adds Analysis script paths to the user's path and
then exits. Kansa will automatically add Analysis script paths to the 
user's path when run normally, this switch is just for convenience when
coming back to the data for analysis.
.PARAMETER ListModules
An optional switch that lists the available modules. Useful for
constructing a modules.conf file. Script exits after listing.
You'll likely want to sort the according to the order of volatility.
.PARAMETER Transcribe
An optional flag that causes Start-Transcript to run at the start
of the script, writing to $OutputPath\yyyyMMddhhmmss.log
.INPUTS
None
You cannot pipe objects to this cmdlet
.OUTPUTS
Various and sundry.
.NOTES
In the absence of a configuration file, specifying which modules to run, 
this script will run each module across all hosts.

Each module should return objects, ideally, though text is supported. See
the discussion above about OUTPUT formats.

Because modules should only COLLECT data from remote hosts, their filenames
must begin with "Get-". Examples:
Get-PrefetchListing.ps1
Get-Netstat.ps1

Any module not beginning with "Get-" will be ignored.

Note this read-only aspect is unenforced, therefore Kansa can be used to
make changes to remote hosts. As a result, it can be used to facilitate
remediation.

The script can take a list of targets, read from a text file, via the -Target
argument. You may also supply the -TargetCount argument to limit how many hosts
from the file will be targeted. 

In the absence of the -Target argument containing a list of targets, the script
will query Acitve Directory for a complete list of hosts and will attempt to 
target all of them. As of this writing, failures are silently ignored.

.EXAMPLE
Kansa.ps1 -ModulePath .\Kansas 
In the above example the user has specified the module path and a path
for the tool's output. Note that error logging and transcriptions (if
specified using -transcribe) are written to the output path. Kansa will
query active directory for a list of targets in the current forest.
.EXAMPLE
Kansa.ps1 -ModulePath .\Modules -TargetList hosts.txt -Credential $Credential -Transcribe -Verbose
In this example the user has specified a module path, a list of hosts to
target, a user credential under which to execute. The -Transcribe and 
-Verbose flags are also supplied causing all script output to be written
to a transcript and for the script to be more verbose.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ModulePath="Modules\",
    [Parameter(Mandatory=$False,Position=1)]
        [String]$TargetList=$Null,
    [Parameter(Mandatory=$False,Position=2)]
        [int]$TargetCount=0,
    [Parameter(Mandatory=$False,Position=3)]
        [PSCredential]$Credential=$Null,
    [Parameter(Mandatory=$False,Position=4)]
        [Switch]$Pushbin,
    [Parameter(Mandatory=$False,Position=5)]
        [Switch]$Ascii,
    [Parameter(Mandatory=$False,Position=6)]
        [Switch]$UpdatePath,
    [Parameter(Mandatory=$False,Position=7)]
        [Switch]$ListModules,
    [Parameter(Mandatory=$False,Position=8)]
        [Switch]$Transcribe
)

function FuncTemplate {
<#
.SYNOPSIS
Default function template, copy when making new function
#>
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ParamTemplate=$Null
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    Try {
        <# code goes here #>
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding $Encoding $ErrorLog
        $_.Exception.Message | Add-Content -Encoding $Encoding $ErrorLog
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}
<# End FuncTemplate #>

function Exit-Script {
<#
.SYNOPSIS
Exit the script somewhat gracefully, closing any open transcript.
#>
    if ($Transcribe) {
        $Suppress = Stop-Transcript
    }
    if (Test-Path($ErrorLog)) {
        Write-Output "Script completed with errors. See ${ErrorLog} for details."
    }
    Exit
}

function Get-Modules {
<#
.SYNOPSIS
Returns a listing of availble modules from $ModulePath
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$ModulePath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    Write-Debug "`$ModulePath is ${ModulePath}."
    $Modules = $FoundModules = @()
    Try {
        $ModConf = $ModulePath + "\" + "Modules.conf"
        if (Test-Path($Modconf)) {
            Write-Verbose "Found ${ModulePath}Modules.conf."
            $Modules = Get-Content $ModulePath\Modules.conf -ErrorAction Stop | % { $_.Trim() } | ? { $_ -gt 0 -and (!($_.StartsWith("#"))) }
            foreach ($Module in $Modules) {
                $Modpath = $ModulePath + "\" + $Module
                if (!(Test-Path($Modpath))) {
                    Write-Error "Could not find module specified in ${ModulePath}\Modules.conf: $Module. Quitting."
                    Exit-Script
                }
                $FoundModules += ls $ModPath   
            }
            $Modules = $FoundModules
        } else {
            $Modules = ls -r $ModulePath\Get-*.ps1 -ErrorAction Stop
        }
        Write-Verbose "Running modules: $($Modules | Select-Object -ExpandProperty BaseName)"
        $Modules
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding $Encoding $ErrorLog
        $_.Exception.Message | Add-Content -Encoding $Encoding $ErrorLog
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Load-AD {
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    if (Get-Module -ListAvailable | ? { $_.Name -match "ActiveDirectory" }){
        try {
            Import-Module ActiveDirectory -ErrorAction Stop #| Out-Null
        } catch {
            Write-Error "Could not load the required Active Directory module. Please install the Remote Server Administration Tool for AD. Quitting."
            Exit-Script
        }
    } else {
        Write-Error "Could not load the required Active Directory module. Please install the Remote Server Administration Tool for AD. Quitting."
        Exit-Script
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Get-Forest {
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    try {
        $Forest = (Get-ADForest -ErrorAction Stop).Name
        Write-Verbose "Forest is ${forest}."
        $Forest
    } catch {
        Write-Error "Get-Forest could not find current forest."
        Exit-Script
    }
}

function Get-Targets {
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$TargetList=$Null,
    [Parameter(Mandatory=$False,Position=1)]
        [int]$TargetCount=0
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    if ($TargetList) {
        if ($TargetCount -eq 0) {
            $Targets = Get-Content $TargetList | % { $_.Trim() } | Where-Object { $_.Length -gt 0 }
        } else {
            $Targets = Get-Content $TargetList | % { $_.Trim() } | Where-Object { $_.Length -gt 0 } | Select-Object -First $TargetCount
        }
        Write-Verbose "`$Targets are ${Targets}."
        return $Targets
    } 
        
    Try {
        Write-Verbose "`$TargetCount is ${TargetCount}."
        if ($TargetCount -eq 0 -or $TargetCount -eq $Null) {
            $Targets = Get-ADComputer -Filter * -ErrorAction Stop | `
                Select-Object -ExpandProperty Name 
        } else {
            $Targets = Get-ADComputer -Filter * -ResultSetSize $TargetCount -ErrorAction Stop | `
                Select-Object -ExpandProperty Name
        }
        Write-Verbose "`$Targets are ${Targets}."
        return $Targets
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding $Encoding $ErrorLog
        $_.Exception.Message | Add-Content -Encoding $Encoding $ErrorLog
        Write-Error "Get-Targets failed. See $Errorlog for details. Quitting."
        Exit-Script
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Get-TargetData {
<#
.SYNOPSIS
Runs each specified module against each specified target.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$Targets,
    [Parameter(Mandatory=$True,Position=1)]
        [Array]$Modules,
    [Parameter(Mandatory=$False,Position=2)]
        [PSCredential]$Credential=$False
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"

    Try {
        if ($Credential) {
            $PSSessions = New-PSSession -ComputerName $Targets -SessionOption (New-PSSessionOption -NoMachineProfile) `
                -Credential $Credential -ErrorAction Continue
        } else {
            $PSSessions = New-PSSession -ComputerName $Targets -SessionOption (New-PSSessionOption -NoMachineProfile) `
                -ErrorAction SilentlyContinue
        }

        foreach($Module in $Modules) {
            $ModuleName = $Module | Select-Object -ExpandProperty BaseName
            $GetlessMod = $($ModuleName -replace "Get-")
            $Suppress = New-Item -Path $OutputPath -name $GetlessMod -ItemType Directory -ErrorAction SilentlyContinue
            $OutputMethod = Get-Content $Module -TotalCount 1
            $Job = Invoke-Command -Session $PSSessions -FilePath $Module -ErrorAction SilentlyContinue -AsJob
            Write-Verbose "Waiting for $ModuleName to complete."
            Wait-Job $Job -ErrorAction SilentlyContinue
            foreach($ChildJob in $Job.ChildJobs) { 
                $Recpt = Receive-Job $ChildJob -ErrorAction SilentlyContinue
                $Outfile = $OutputPath + $GetlessMod + "\" + $ChildJob.Location + "-" + $GetlessMod
                switch -Wildcard ($OutputMethod) {
                    "*csv" {
                        $Outfile = $Outfile + ".csv"
                        $Recpt | ConvertTo-Csv -NoTypeInformation | % { $_ -replace "`"" } | Set-Content -Encoding $Encoding $Outfile
                    }
                    "*tsv" {
                        $Outfile = $Outfile + ".tsv"
                        $Recpt | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`"" } | Set-Content -Encoding $Encoding $Outfile
                    }
                    "*xml" {
                        $Outfile = $Outfile + ".xml"
                        $Recpt | Export-Clixml $Outfile -Encoding $Encoding
                    }
                    "*bin" {
                        $Outfile = $Outfile + ".bin"
                        $Recpt | Set-Content -Encoding Byte $Outfile
                    }
                    "*zip" {
                        $Outfile = $Outfile + ".zip"
                        $Recpt | Set-Content -Encoding Byte $Outfile
                    }
                    default {
                        $Outfile = $Outfile + ".txt"
                        $Recpt | Set-Content -Encoding $Encoding $Outfile
                    }
                }
            }
        }
        Remove-PSSession $PSSessions -ErrorAction SilentlyContinue
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding $Encoding $ErrorLog
        $_.Exception.Message | Add-Content -Encoding $Encoding $ErrorLog
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function Push-Bindep {
<#
.SYNOPSIS
Attempts to copy required binaries to targets.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$Targets,
    [Parameter(Mandatory=$True,Position=1)]
        [Array]$Modules
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    Try {
        foreach($Module in $Modules) {
            $ModuleName = $Module | Select-Object -ExpandProperty BaseName
            $bindepline = Get-Content $Module -TotalCount 2 | Select-Object -Skip 1
            if ($bindepline -match '#\sBINDEP\s(.*)') {
                $Bindep = $($Matches[1])
                Write-Verbose "${ModuleName} has dependency on ${Bindep}."
                if (-not (Test-Path("$ModulePath\bin\$Bindep"))) {
                    Write-Verbose "${Bindep} not found in ${ModulePath}\bin, skipping."
                    "${Bindep} not found in ${ModulePath}\bin, skipping." | Add-Content -Encoding $Encoding $ErrorLog
                    Continue
                }
                Write-Verbose "Attempting to copy ${Bindep} to targets..."
                foreach($Target in $Targets) {
                    Copy-Item "$ModulePath\bin\$Bindep" "\\$Target\ADMIN$\$Bindep" -ErrorAction Continue
                }
            }
        }
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding $Encoding $ErrorLog
        $_.Exception.Message | Add-Content -Encoding $Encoding $ErrorLog
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function Set-KansaPath {
    # Update the path to inlcude Kansa analysis script paths, if they aren't already
    $found = $False
    foreach($path in ($env:path -split ";")) {
        if ([regex]::escape($pwd) -match [regex]::escape($path)) {
            $found = $True
        }
    }
    if (-not($found)) {
        $env:path = $env:path + ";$pwd\Analysis\asep;$pwd\Analysis\meta;$pwd\Analysis\network;`
        $pwd\Analysis\process;"
    }
}


###########################
# Sanity check parameters #
###########################
Write-Debug "Sanity checking parameters"
$Exit = $False
if (-not (Test-Path($ModulePath))) {
    Write-Error -Category InvalidArgument -Message "User supplied ModulePath, $ModulePath, was not found."
    $Exit = $True
}
if ($TargetList -and -not (Test-Path($TargetList))) {
    Write-Error -Category InvalidArgument -Message "User supplied TargetList, $TargetList, was not found."
    $Exit = $True
}
if ($TargetCount -lt 0) {
    Write-Error -Category InvalidArgument -Message "User supplied TargetCount, $TargetCount, was negative."
    $Exit = $True
}
#TKTK Add test for $Credential
if ($Exit) {
    Write-Output "One or more errors were encountered with user supplied arguments. Exiting."
    Exit-Script
}
Write-Debug "Parameter sanity check complete."
##############################
# End paramter sanity checks #
##############################


###########################
# Set the output encoding #
###########################
if ($Ascii) {
    Set-Variable -Name Encoding -Value "Ascii" -Scope Script
} else {
    Set-Variable -Name Encoding -Value "Unicode" -Scope Script
}
###########################
# End set output encoding #
###########################


##################################
# Create timestamped output path #
# Write transcript and error log #
# to output path.                #
##################################
$Runtime = ([String] (Get-Date -Format yyyyMMddHHmm))
$OutputPath = ".\Output_$Runtime\"
$Suppress = New-Item -Name $OutputPath -ItemType Directory -Force -ErrorAction Stop

If ($Transcribe) {
    $TransFile = $OutputPath + ([string] (Get-Date -Format yyyyMMddHHmmss)) + ".log"
    $Suppress = Start-Transcript -Path $TransFile
}
$ErrorLog = $OutputPath + "Error.Log"

if (Test-Path($ErrorLog)) {
    Remove-Item -Path $ErrorLog
}
###########################
# Done setting up output. #
###########################


#####################################################
# Update the user's path with Kansa Analysis paths. #
# Exit if that's all they wanted us to do.          #
#####################################################
Set-KansaPath
if ($UpdatePath) {
    # User provided UpdatePath switch so
    # exit after updating the path
    Exit-Script
}
###########################
# Done updating the path. #
###########################


########################################
# If we're -Debug, show some settings. #
########################################
Write-Debug "`$ModulePath is ${ModulePath}."
Write-Debug "`$OutputPath is ${OutputPath}."
Write-Debug "`$ServerList is ${TargetList}."


###################
# Get our modules #
###################
if ($ListModules) {
    # User provided ListModules switch so exit
    # after returning the full list of modules
    ls $ModulePath\Get-*.ps1 | Select-Object Name
    Exit-Script
}
# Get-Modules reads the modules.conf file, if
# it exists, otherwise will have same data as
# ls command above.
$Modules = Get-Modules -ModulePath $ModulePath
########################
# Done getting modules #
########################


####################
# Get our targets. #
####################
if (!$TargetList) {
    Write-Verbose "No TargetList specified. Building one requires RAST and will take some time."
    $suppress = Load-AD
    $Targets  = Get-Targets -TargetCount $TargetCount
} else {
    $Targets = Get-Targets -TargetList $TargetList -TargetCount $TargetCount
}
########################
# Done getting targets #
########################


#########################################
# Copy binaries to targets if requested #
#########################################
if ($PushBin) {
    Push-Bindep -Targets $Targets -Modules $Modules
}
#####################
# Done pushing bins #
#####################


####################################
# Finally, let's gather some data. #
####################################
Get-TargetData -Targets $Targets -Modules $Modules -Credential $Credential
########################
# Done gathering data. #
########################


############
# Clean up #
Exit-Script
###############
# We're done. #
###############