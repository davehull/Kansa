$Ext = ".txt"
<#
.SYNOPSIS
Get listing of prefetch files
#>

$pfconf = (Get-ItemProperty "hklm:\system\currentcontrolset\control\session manager\memory management\prefetchparameters").EnablePrefetcher 
Switch -Regex ($pfconf) {
    "[1-3]" {
        ls $env:windir\Prefetch\*.pf
    }
    default {
        Write-Output "Prefetch not enabled on ${env:COMPUTERNAME}."
    }
}