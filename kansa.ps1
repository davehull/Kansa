<#
.SYNOPSIS
Kansa is the codename for the modular rewrite of Mal-Seine.
.DESCRIPTION
In this modular version of Mal-Seine, Kansa enumerates the available 
modules, calls the main function of each module and redirects error and 
output information from the modules to their proper places.

This script was written with the intention of avoiding the need for
CredSSP, therefore "second-hops" must be avoided.

The script assumes you will have administrator level privileges on
target hosts, though such privileges may not be required by all modules.

The script requires Remote Server Administration Tools (RSAT). These
are available from Microsoft's Download Center for Windows 7 and 8.
You can search for RSAT at:

http://www.microsoft.com/en-us/download/default.aspx
.PARAMETER ModulePath
An optional parameter that specifies the path to the collector modules.
.PARAMETER OutputPath
An optional parameter that specifies the main output path. Each host's 
output will be written to subdirectories beneath the main output path.
.PARAMETER TargetList
An optional list of servers from the current forest to collect data from.
In the absence of this parameter, collection will be attempted against 
all hosts in the current forest.
.PARAMETER TargetCount
An optional parameter that specifies the maximum number of targets.
.PARAMETER Credential
An optional credential that the script will use for execution. Use the
$Credential = Get-Credential convention to populate a suitable variable.
.PARAMETER Transcribe
An optional parameter that causes Start-Transcript to run at the start
of the script, writing to $OutputPath\yyyyMMddhhmmss.log
.INPUTS
None
You cannot pipe objects to this cmdlet
.OUTPUTS
Various and sundry.
.NOTES
In the absence of a configuration file, specifying which modules to run, 
this script will run each module across all hosts.

Each module should write its output using Write-Output, this script
will write that output to an appropriately named output file that will
include the hostname-modulename.extension.

Modules can specify their output file extensions on their first line using
the following syntax:

$Ext = ".tsv"

The default file extension, if one is not provided, is ".txt".

Because modules should only collect data from remote hosts, their filenames
must begin with "Get-". Examples:
Get-PrefetchListing.ps1
Get-Netstat.ps1

Any module not beginning with "Get-" will be ignored. When data is output,
the "Get-" is removed in the output filename.


The script queries Acitve Directory for a complete list of hosts, pings
each of those hosts and if it receives a response, invokes each module
on those hosts.

.EXAMPLE
Kansa.ps1 -ModulePath .\Kansas -OutputPath .\AtlantaDataCenter\
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
        [String]$OutputPath="Output\",
    [Parameter(Mandatory=$False,Position=2)]
        [String]$TargetList=$Null,
    [Parameter(Mandatory=$False,Position=3)]
        [int]$TargetCount=0,
    [Parameter(Mandatory=$False,Position=4)]
        [PSCredential]$Credential=$Null,
    [Parameter(Mandatory=$False,Position=5)]
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
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
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
            Write-Verbose "Found ${ModulePath}\Modules.conf."
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
        Write-Verbose "Available modules: $($Modules | Select-Object -ExpandProperty BaseName)"
        $Modules
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
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
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
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
        $PSSessions = New-PSSession -ComputerName $Targets -SessionOption (New-PSSessionOption -NoMachineProfile) `
            -ErrorAction SilentlyContinue

        foreach($Module in $Modules) {
            $ModuleName = $Module | Select-Object -ExpandProperty BaseName
            $OutputMethod = Get-Content $Module -TotalCount 1
            $Job = Invoke-Command -Session $PSSessions -FilePath $Module -ErrorAction SilentlyContinue -AsJob
            Write-Verbose "Waiting for $ModuleName to complete."
            Wait-Job $Job -ErrorAction SilentlyContinue
            foreach($ChildJob in $Job.ChildJobs) { 
                $Recpt = Receive-Job $ChildJob -ErrorAction SilentlyContinue
                $Outfile = $OutputPath + $ChildJob.Location + "-" + $($ModuleName -Replace "Get-")
                switch -Wildcard ($OutputMethod) {
                    "*csv" {
                        $Outfile = $Outfile + ".csv"
                        $Recpt | ConvertTo-Csv -NoTypeInformation | % { $_ -replace "`"" } | Set-Content -Encoding Ascii $Outfile
                    }
                    "*tsv" {
                        $Outfile = $Outfile + ".tsv"
                        $Recpt | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`"" } | Set-Content -Encoding Ascii $Outfile
                    }
                    "*xml" {
                        $Outfile = $Outfile + ".xml"
                        $Recpt | Export-Clixml $Outfile
                    }
                    default {
                        $Outfile = $Outfile + ".txt"
                        $Recpt | Set-Content -Encoding Ascii $Outfile
                    }
                }
            }
        }
        Remove-PSSession $PSSessions -ErrorAction SilentlyContinue
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function Push-Bindep {
<#
.SYNOPSIS
Attempts to copy required binary, $bindep to $Target.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Bindep,
    [Parameter(Mandatory=$True,Position=1)]
        [System.Management.Automation.Runspace.PSSession]$PSSession,
    [Parameter(Mandatory=$True,Position=2)]
        [String]$Target
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    Write-Verbose "Attempting push to ${$Target}..."
    Try {
        $BindepShare = $False
        $RemoteShares = Invoke-Command { net share } -Session $PSSession -ErrorAction Stop
        if ($RemoteShares -match "ADMIN\$") {
            Write-Verbose "Found ADMIN`$ share on ${Target}."
            $BindepShare = Invoke-Command { $env:SystemRoot } -session $PSSession -ErrorAction Stop
            Copy-Item "$ModulePath\bin\$bindep" "\\$Target\ADMIN$\$bindep" -ErrorAction Stop
        } else {
            Write-Verbose "No ADMIN`$ share on ${Target}. Can't push ${Bindep} to ${Target}."
            # Todo: add support for alternate, default shares.
            $BindepShare = $False
        }            
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
    }
    $BindepShare
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

# Sanity check parameters
Write-Debug "Sanity checking parameters"
$Exit = $False
if (-not (Test-Path($ModulePath))) {
    Write-Error -Category InvalidArgument -Message "User supplied ModulePath, $ModulePath, was not found."
    $Exit = $True
}
if (-not (Test-Path($OutputPath))) {
    Write-Error -Category InvalidArgument -Message "User supplied OutputPath, $OutputPath, was not found."
    $Exit = $True
} else {
    if (-not $OutputPath.EndsWith("\")) {
        $OutputPath = $OutputPath + "\"
        $OutputPath
    }
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
# End paramter sanity check

If ($Transcribe) {
    $TransFile = $OutputPath + ([string] (Get-Date -Format yyyyMMddHHmmss)) + ".log"
    $Suppress = Start-Transcript -Path $TransFile
}
$ErrorLog = $OutputPath + "Error.Log"

if (Test-Path($ErrorLog)) {
    Remove-Item -Path $ErrorLog
}

Write-Debug "`$ModulePath is ${ModulePath}."
Write-Debug "`$OutputPath is ${OutputPath}."
Write-Debug "`$ServerList is ${TargetList}."


if (!$TargetList) {
    Write-Verbose "No TargetList specified. Building one requires RAST and will take some time."
    Load-AD
    Get-Targets -TargetCount $TargetCount
} else {
    $Targets = Get-Targets -TargetList $TargetList -TargetCount $TargetCount
}

$Modules = Get-Modules -ModulePath $ModulePath

Get-TargetData -Targets $Targets -Modules $Modules -Credential $Credential

Exit-Script