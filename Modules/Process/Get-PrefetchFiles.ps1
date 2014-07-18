<#
.SYNOPSIS
Acquires copies of prefetch files, if enabled, copying them
to a zip file. This is not the fastest, but in my testing, it
works.
.NOTES
Next line is Kansa.ps1's output directive
OUTPUT zip
#>

function add-zip
{
    param([string]$zipfilename)

    if (-not (Test-Path($zipfilename))) {
        Set-Content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (dir $zipfilename).IsReadOnly = $false
    }

    $shellApplication = New-Object -com shell.application
    $zipPackage = $shellApplication.NameSpace($zipfilename)

    foreach($file in $input) {
        $zipPackage.CopyHere($file.FullName)
        Start-Sleep -milliseconds 100
    }
}

$pfconf = (Get-ItemProperty "hklm:\system\currentcontrolset\control\session manager\memory management\prefetchparameters").EnablePrefetcher 
Switch -Regex ($pfconf) {
    "[1-3]" {
        $zipfile = (($env:TEMP) + "\" + ($env:COMPUTERNAME) + "-PrefetchFiles.zip")
        if (Test-Path $zipfile) { rm $zipfile -Force }
        ls $env:windir\Prefetch\*.pf | add-zip $zipfile
        Get-Content -Encoding Byte -Raw $zipfile
        $suppress = Remove-Item $zipfile
    }
    default {
    # No Prefetch files, nothing to do, nothing to return
    }
}