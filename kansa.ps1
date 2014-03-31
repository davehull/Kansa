<#
.SYNOPSIS
Kansa is the codename for the modular rewrite of Mal-Seine.
.DESCRIPTION
In this modular version of Mal-Seine, Kansa enumerates the available 
modules, calls the main function of each user designated module, 
redirects error and output information from the modules to their
proper places.

This script was written with the intention of avoiding the need for
CredSSP, therefore the need for second-hops must be avoided.

The script requires Remote Server Administration Tools (RSAT). These
are available from Microsoft's Download Center for Windows 7 and 8.
You can search for RSAT at:

http://www.microsoft.com/en-us/download/default.aspx
.PARAMETER ModulePath
An optional parameter that specifies the path to the collector modules.
.PARAMETER OutputPath
An optional parameter that specifies the main output path. Each host's 
output will be written to subdirectories beneath the main output path.
.EXAMPLE
Kansa.ps1 -ModulePath .\Kansas -OutputPath .\AtlantaDataCenter\

.NOTE
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
        [String]$OutputPath="OutputPath\"
)

Write-Debug "`$ModulePath is ${ModulePath}."
Write-Debug "`$OutputPath is ${OutputPath}."

if (-not (Test-Path($ModulePath))) {
    Write-Error -Category InvalidArgument -Message "User supplied ModulePath, $ModulePath, was not found."
    Exit
}

if (-not (Test-Path($OutputPath))) {
    Write-Error -Category InvalidArgument -Message "User supplied OutputPath, $OutputPath, was not found."
    Exit
}

$ErrorLog = $OutputPath + "\Error.Log"

function Get-Modules {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$ModulePath
)
    Write-Verbose "Entering $($MyInvocation.MyCommand)"
    Try {
        ls -r $ModulePath\*.ps1 | select name
    } Catch [Exception] {
        $_.Exception.GetType().FullName | Add-Content -Encoding Ascii $ErrorLog
        $_.Exception.Message | Add-Content -Encoding Ascii $ErrorLog
    }
}

function Load-AD {
    Write-Verbose "Entering $($MyInvocation.MyCommand)"
    if (Get-Module -ListAvailable | ? { $_.Name -match "ActiveDirectory" }) {
        try {
            Import-Module ActiveDirectory -ErrorAction Stop | Out-Null
        } catch {
            Write-Error "Could not load the required Active Directory module. Please install the Remote Server Administration Tool for AD. Quitting."
            exit
        }
    } else {
        Write-Error "Could not load the required Active Directory module. Please install the Remote Server Administration Tool for AD. Quitting."
        exit
    }
}

Load-AD        

Get-Modules $ModulePath