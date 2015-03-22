<#
.SYNOPSIS
Get-SvcTrigs.ps1 returns information about service triggers, which
could be used as a persistence mechanism.
.NOTES
The following line is needed by Kansa.ps1 to determine how to treat the
output of this script.
OUTPUT tsv
#>

$svctrigs = & $env:windir\system32\sc.exe query | ForEach-Object {
    $svc = $_ 
    if ($svc -match "SERVICE_NAME:\s(.*)") {
        & $env:windir\system32\sc qtriggerinfo $($matches[1])
    }
}|?{$_.length -gt 1 -and $_ -notmatch "\[SC\] QueryServiceConfig2 SUCCESS|has not registered for any" }

function Get-LogProviderHash {
    Write-Verbose "Entering $($MyInvocation.MyCommand)"
    $LogProviders = @{}
    & $env:windir\system32\logman.exe query providers | ForEach-Object {
        $provider = $_
        if ($provider -match "\{") {
            $LogName, $LogGuid = ($provider -split "{") -replace "}"
            $LogName = $LogName.Trim()
            $LogGuid = $LogGuid.Trim()
            if ($LogProviders.ContainsKey($LogGuid)) {} else {
                Write-Verbose "Adding ${LogGuid}:${LogName} to `$LogProviders hash."
                $LogProviders.Add($LogGuid, $LogName)
            }
        }
    }
    $LogProviders
    Write-Verbose "Exiting $($MyInvocation.MyCommand)"
}

$LogProviders = Get-LogProviderHash
$ServiceName = $Action = $Condition = $Data = $False
$CondPattern = '(?<Desc>[-_ A-Za-z0-9]+)\s:\s(?<Guid>[-0-9a-fA-F]+)\s(?<Trailer>[-\[A-Za-z0-9 ]+\]*)'

$svctrigs | ForEach-Object {
    $line = $_
    $line = $line.Trim()
    if ($line -match "SERVICE_NAME:\s(?<SvcName>[-_A-Za-z0-9]+)") {
        if ($ServiceName) {
            $o = "" | Select-Object ServiceName, Action, Type, Subtype, Data
            $o.ServiceName, $o.Action, $o.Type, $o.Subtype, $o.Data = (($ServiceName,$Action,$Type,$SubType,$Data) -replace "False", $null)
            $o
        }
        $ServiceName = $matches['SvcName']
        $Action = $Condition = $Data = $False
    } elseif ($line -match "(START SERVICE|STOP SERVICE)") {
        if ($ServiceName -and $Action -and $Condition) {
            $o = "" | Select-Object ServiceName, Action, Type, Subtype, Data
            $o.ServiceName, $o.Action, $o.Type, $o.Subtype, $o.Data = (($ServiceName,$Action,$Type,$Subtype,$Data) -replace "False", $null)
            $o
        }
        $Action = ($matches[1])
        $Condition = $Data = $False
    } elseif ($line -match "DATA\s+") {
        $Data = $line -replace "\s+" -replace "DATA:"
    } else {
        $Condition = $line -replace "\s+", " "
        if ($LogProviders) {
            $ProviderName = $False
            if ($Condition -match $CondPattern) {
                $Guid = $($matches['Guid']).ToUpper()
                $ProviderName = $LogProviders.$Guid
                if ($ProviderName) {
                    $Type = $matches['Desc']
                    $Subtype = $LogProviders.$Guid
                } else {
                    $Type, $Subtype = ($Condition -split ":")
                    $Subtype = $Subtype.Trim()
                }
            }
        }
        $Data = $False
    }
}
$o = "" | Select-Object ServiceName, Action, Type, Subtype, Data
$o.ServiceName, $o.Action, $o.Type, $o.Subtype, $o.Data = (($ServiceName,$Action,$Type,$Subtype,$Data) -replace "False", $null)
$o