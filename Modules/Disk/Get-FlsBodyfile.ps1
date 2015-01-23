<#
.SYNOPSIS
Get-FlsBodyfile.ps1

Requires and fls.zip file in Modules\Bin\
The files in fls.zip should be fls.exe and all dlls from the Sleuthkit
bin directory where fls.exe resides.

When used with -PushBin argument copies fls.zip from the Modules\bin\ 
path to each remote host and creates an fls bodyfile. You may want to 
tweak this to target specific disks. As it is currently, it creates a 
complete bodyfile of $env:SystemDrive (typically C:\). This can take a 
long time for large drives.

!! This takes time for an entire drive !!

.NOTES
Next two lines are required by kansa for proper handling of output and 
when used with -Pushbin, the BINDEP directive below tells Kansa where
to find the third-party code.
OUTPUT txt
BINDEP .\Modules\bin\fls.zip
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$Drive="$env:SystemDrive"
)

Function Expand-Zip ($zipfile, $destination) {
	[int32]$copyOption = 16 # Yes to all
    $shell = New-Object -ComObject shell.application
    $zip = $shell.Namespace($zipfile)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item, $copyOption)
    }
} 

$flspath = ($env:SystemRoot + "\fls.zip")

if (Test-Path ($flspath)) {
    $suppress = New-Item -Name fls -ItemType Directory -Path $env:Temp -Force
    $flsdest = ($env:Temp + "\fls\")
    Expand-Zip $flspath $flsdest
    if (Test-Path($flsdest + "\fls.exe")) {
        # $sd = $env:SystemDrive
        & $flsdest\fls.exe -r -m ($Drive) \\.\$Drive
        $suppress = Remove-Item $flsdest -Force -Recurse
    } else {
        "Fls.zip found, but not unzipped."
    }
} else {
    "Fls.zip not found on $env:COMPUTERNAME"
}