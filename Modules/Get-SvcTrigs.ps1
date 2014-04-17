# OUTPUT txt
<#
Acquires service triggers
#>
$($(foreach ($svc in (& $env:windir\system32\sc.exe query)) { 
    if ($svc -match "SERVICE_NAME:\s(.*)") {
        & $env:windir\system32\sc qtriggerinfo $($matches[1])
    }
})|?{$_.length -gt 1 -and $_ -notmatch "\[SC\] QueryServiceConfig2 SUCCESS|has not registered for any" })
