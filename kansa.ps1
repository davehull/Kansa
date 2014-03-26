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
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ModulePath="Modules\",
    [Parameter(Mandatory=$False,Position=1)]
        [String]$OutputPath="OutputPath\"
)

# $sharename = "\\CONFIGURE\THIS"
$sharename = ".\"
# make a \bin\ dir in the share for latest version of Sysinternals autorunsc.exe and handle.exe 
# available from http://technet.microsoft.com/en-us/sysinternals

if ($sharename -match "CONFIGURE") {
    Write-Host "`n[*] ERROR: You must edit the script and configure a share for the data to be written to, and for autorunsc.exe to be run from.`n"
    Exit
}

#put autorunsc.exe, handle.exe in the following path
$sharebin = $sharename + "\bin\"

$zipfile = $temp + "\" + $this_computer + "_kansa.zip"
$ErrorLog = $temp + "\" + $this_computer + "_error.log"

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

Get-Modules $ModulePath