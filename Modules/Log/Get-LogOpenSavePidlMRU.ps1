function Get-RegKeyValueNData {
# Returns values and data for Registry keys
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/05/11/use-powershell-to-enumerate-registry-property-values.aspx
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Path
)
    Push-Location
    Set-Location -Path "Registry::$Path"
    Get-Item -Force . | Select-Object -ExpandProperty Property | 
    Foreach-Object {
        New-Object psobject -Property @{"property" = $_;
            "value" = (Get-ItemProperty -Path . -Name $_).$_
        }
    }
    Pop-Location
}

Get-RegKeyValueNData 'HKU\S-1-5-21-2127521184-1604012920-1887927527-8646616\Software\Microsoft\Windows\CurrentVersion\Explorer\ComDlg32\OpenSavePidlMRU\`*'