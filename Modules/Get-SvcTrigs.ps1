# OUTPUT tsv
<#
Acquires service triggers
#>
$data = $($(foreach ($svc in (& $env:windir\system32\sc.exe query)) { 
    if ($svc -match "SERVICE_NAME:\s(.*)") {
        & $env:windir\system32\sc qtriggerinfo $($matches[1])
    }
})|?{$_.length -gt 1 -and $_ -notmatch "\[SC\] QueryServiceConfig2 SUCCESS|has not registered for any" })

function Get-LogProviderHash {
    Write-Verbose "Entering $($MyInvocation.MyCommand)"
    $LogProviders = @{}
    foreach ($provider in (& $env:windir\system32\logman.exe query providers)) {
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
$ServiceName = $Action = $Condition = $Value = $False
$CondPattern = '(?<Desc>[-_ A-Za-z0-9]+)\s:\s(?<Guid>[-0-9a-fA-F]+)\s(?<Trailer>[-\[A-Za-z0-9 ]+\]*)'
foreach($line in $data) {
    $line = $line.Trim()
    if ($line -match "SERVICE_NAME:\s(?<SvcName>[-_A-Za-z0-9]+)") {
        if ($ServiceName) {
            $o = "" | Select-Object ServiceName, Action, Condition, Value
            $o.ServiceName, $o.Action, $o.Condition, $o.Value = (($ServiceName,$Action,$Condition,$Value) -replace "False", $null)
            $o
        }
        $ServiceName = $matches['SvcName']
        $Action = $Condition = $Value = $False
    } elseif ($line -match "(START SERVICE|STOP SERVICE)") {
        if ($ServiceName -and $Action -and $Condition) {
            $o = "" | Select-Object ServiceName, Action, Condition, Value
            $o.ServiceName, $o.Action, $o.Condition, $o.Value = (($ServiceName,$Action,$Condition,$Value) -replace "False", $null)
            $o
        }
        $Action = ($matches[1])
        $Condition = $Value = $False
    } elseif ($line -match "DATA\s+") {
        $Value = $line -replace "\s+"
    } else {
        $Condition = $line -replace "\s+", " "
        if ($LogProviders) {
            $ProviderName = $False
            if ($Condition -match $CondPattern) {
                $Guid = $($matches['Guid']).ToUpper()
                $ProviderName = $LogProviders.$Guid
                if ($ProviderName) {
                    $Condition = ($matches['Desc'] + ": " + $LogProviders.$Guid) #+ " " + $matches['Trailer'])
                }
            }
        }
        $Value = $False
    }
}
$o = "" | Select-Object ServiceName, Action, Condition, Value
$o.ServiceName, $o.Action, $o.Condition, $o.Value = (($ServiceName,$Action,$Condition,$Value) -replace "False", $null)
$o