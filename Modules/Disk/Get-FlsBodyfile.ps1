# OUTPUT txt
# BINDEP .\Modules\bin\fls.zip
<#
.SYNOPSIS
Get-FlsBodyfile.ps1

Requires and fls.zip file in Modules\Bin\
The files in fls.zip should be fls.exe and all dlls from the Sleuthkit bin
directory where fls.exe resides.

When used with -PushBin argument copies fls.zip from the Modules\bin\ path to 
each remote host and creates an fls bodyfile. You may want to tweak this to 
target specific disks. As it is currently, it creates a complete bodyfile of 
$env:SystemDrive (typically C:\). This can take a long time for large drives.

!! This takes time for an entire drive !!
#>

Function Expand-Zip ($zipfile, $destination) {
    $shell = New-Object -ComObject shell.application
    $zip = $shell.Namespace($zipfile)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item)
    }
}    

$flspath = ($env:SystemRoot + "\fls.zip")

if (Test-Path ($flspath)) {
    $suppress = New-Item -Name fls -ItemType Directory -Path $env:Temp -Force
    $flsdest = ($env:Temp + "\fls\")
    Expand-Zip $flspath $flsdest
    if (Test-Path($flsdest + "\fls.exe")) {
        $sd = $env:SystemDrive
        & $flsdest\fls.exe -r -m ($sd) \\.\$sd
        $suppress = Remove-Item $flsdest -Force -Recurse
    } else {
        "Fls.zip found, but not unzipped."
    }
} else {
    "Fls.zip not found on $env:COMPUTERNAME"
}