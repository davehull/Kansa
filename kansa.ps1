<#
.SYNOPSIS
Kansa is the codename for the modular rewrite of Mal-Seine.
.DESCRIPTION
In this modular version of Mal-Seine, Kansa enumerates the available 
modules, calls the main function of each module and redirects error and 
output information from the modules to their proper places.

This script was written with the intention of avoiding the need for
CredSSP, therefore "second-hops" must be avoided.

The script requires Remote Server Administration Tools (RSAT). These
are available from Microsoft's Download Center for Windows 7 and 8.
You can search for RSAT at:

http://www.microsoft.com/en-us/download/default.aspx
.PARAMETER ModulePath
An optional parameter that specifies the path to the collector modules.
.PARAMETER OutputPath
An optional parameter that specifies the main output path. Each host's 
output will be written to subdirectories beneath the main output path.
.PARAMETER ServerList
An optional list of servers from the current forest to collect data from.
In the absence of this parameter, collection will be attempted against 
all hosts in the current forest.
.PARAMETER Transcribe
An optional parameter that causes Start-Transcript to run at the start
of the script, writing to $OutputPath\yyyyMMddhhmmss.log
.EXAMPLE
Kansa.ps1 -ModulePath .\Kansas -OutputPath .\AtlantaDataCenter\

.NOTES
In the absence of a configuration file, specifying which modules to run, 
this script will use Invoke-Command to run each module across all hosts.
The script queries Acitve Directory for a complete list of hosts, pings
each of those hosts and if it receives a response, invokes each module
on those hosts.

Each module should write its output using Write-Output, this script
will be responsible for writing that output to an appropriately named
output file.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ModulePath="Modules\",
    [Parameter(Mandatory=$False,Position=1)]
        [String]$OutputPath="Output\",
    [Parameter(Mandatory=$False,Position=2)]
        [String]$HostList=$Null,
    [Parameter(Mandatory=$False,Position=3)]
        [Switch]$Transcribe
)

function Check-Params {
<#
.SYNOPSIS
Sanity check command line parameters. Throw an error and exit if problems are found.
#>
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Exit = $False
    if (-not (Test-Path($ModulePath))) {
        Write-Error -Category InvalidArgument -Message "User supplied ModulePath, $ModulePath, was not found."
        $Exit = $True
    }
    if (-not (Test-Path($OutputPath))) {
        Write-Error -Category InvalidArgument -Message "User supplied OutputPath, $OutputPath, was not found."
        $Exit = $True
    }
    if ($HostList -and -not (Test-Path($ServerList))) {
        Write-Error -Category InvalidArgument -Message "User supplied HostList, $HostList, was not found."
        $Exit = $True
    }

    if ($Exit) {
        Write-Output "One or more errors were encountered with user supplied arguments. Exiting."
        Exit-Script
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Exit-Script {
<#
.SYNOPSIS
Exit the script somewhat gracefully, closing any open transcript.
#>
    if ($Transcribe) {
        $Suppress = Stop-Transcript
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
    Try {
        Write-Output "Available modules:"
        ls -r $ModulePath\*.ps1 | % { $_.Name } 
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
            Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
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
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    Try {
        $Targets = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name
        Write-Verbose "`$Targets are ${Targets}."
        $Targets
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
        Write-Error "Get-Targets failed. See $Errorlog for details. Quitting."
        Exit-Script
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

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

If ($Transcribe) {
    $TransFile = $OutputPath + ([string] (Get-Date -Format yyyyMMddHHmmss)) + ".log"
    $Suppress = Start-Transcript -Path $TransFile
}
$ErrorLog = $OutputPath + "\Error.Log"
Write-Debug "`$ModulePath is ${ModulePath}."
Write-Debug "`$OutputPath is ${OutputPath}."
Write-Debug "`$ServerList is ${ServerList}."

Check-Params
Load-AD        
Get-Modules $ModulePath
if (-not $ServerList) {
    Write-Verbose "No HostList provided. Building one, this may take some time."
    $Forest = Get-Forest
    $Targets = Get-Targets
} else {
    $Targets = gc $HostList
    Write-Verbose "Targets are: ${Targets}"
}


Exit-Script