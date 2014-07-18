<#
.SYNOPSIS
Get listing of prefetch files
.NOTES
Next line is Kansa.ps1's output directive
OUTPUT tsv
#>

$pfconf = (Get-ItemProperty "hklm:\system\currentcontrolset\control\session manager\memory management\prefetchparameters").EnablePrefetcher 
Switch -Regex ($pfconf) {
    "[1-3]" {
        $o = "" | Select-Object FullName, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
        ls $env:windir\Prefetch\*.pf | % {
            $o.FullName = $_.FullName;
            $o.CreationTimeUtc = Get-Date($_.CreationTimeUtc) -format o;
            $o.LastAccesstimeUtc = Get-Date($_.LastAccessTimeUtc) -format o;
            $o.LastWriteTimeUtc = Get-Date($_.LastWriteTimeUtc) -format o;
            $o
        }
    }
    default {
        Write-Output "Prefetch not enabled on ${env:COMPUTERNAME}."
    }
}