# OUTPUT tsv
# BINDEP .\Modules\bin\Autorunsc.exe
<#
.SYNOPSIS
Get-Autorunsc.ps1 depends on Sysinternals Autorunsc.exe, Kansa.ps1 should recognize this
based on line two of this script and will attempt to copy it from $ModulePath\bin\ to the 
remote system's ADMIN$ share. If the ADMIN$ share does not exist, the copy will fail and
the module will be skipped.

Users will have to download Autorunsc.exe or any other binaries separately, they are not
included with Kansa.

!!THIS SCRIPT ASSUMES AUTORUNSC.EXE WILL BE IN $ENV:SYSTEMROOT!!

If you have autorunsc.exe in your Modules\bin\ path and run the script with the -Pushbin
flag, Kansa will attempt to copy the binary to the ADMIN$. Binaries are not removed, so
subsequent runs won't require -Pushbin.

Autorunsc output is a mess. Some of it is quoted csv, some is just csv. This script
parses it pretty well, but there are still some things that are incorrectly parsed. As I
have time, I'll see about resolving the troublesome entries, one in particular is for
items that don't have time stamps.
#>

if (Test-Path "$env:SystemRoot\Autorunsc.exe") {
    & $env:SystemRoot\Autorunsc.exe /accepteula -a -v -c -f '*' 2> $null | Select-Object -Skip 1 | % {
        $row = $_ -replace '(,)(?=(?:[^"]|"[^"]*")*$)', "`t" -replace "`""
        $o = "" | Select-Object Time, EntryLocation, Entry, Enabled, Category, Description, Publisher, ImagePath, Version, LaunchString, MD5, SHA1, PESHA1, PESHA256, SHA256
        $o.Time,
        $o.EntryLocation, 
        $o.Entry, 
        $o.Enabled, 
        $o.Category, 
        $o.Description, 
        $o.Publisher, 
        $o.ImagePath, 
        $o.Version, 
        $o.LaunchString, 
        $o.MD5, 
        $o.SHA1, 
        $o.PESHA1, 
        $o.PESHA256, 
        $o.SHA256 = ($row -split "`t")
        $o
    }
} else {
    Write-Error "Autorunsc.exe not found in $env:SystemRoot."
}