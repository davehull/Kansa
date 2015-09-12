<#
.SYNOPSIS
Get-AMHealthStatusStack.ps1

Returns the following fields:
AntispywareEnabled, AntispywareSignatureAge, 
AntispywareSignatureVersion, AntivirusEnabled, AntivirusSignatureAge, 
AntivirusSignatureVersion, BehaviorMonitorEnabled, Enabled,
EngineVersion, IoavProtectionenabled, Name, NisEnabled, 
NisEngineVersion, NisSignatureVersion, OnAccessProtectionEnabled,
ProductStatus, RealTimeScanDirection, RtpEnabled, SchemaVersion,
Version

Requires:
Process data matching *AMHealthStatus.tsv in pwd logparser.exe in path
.NOTES
DATADIR AMHealthStatus
#>

if (Get-Command logparser.exe) {
    $lpquery = @"
    SELECT count (
        AntispywareEnabled, 
        AntispywareSignatureAge, 
        AntispywareSignatureVersion,
        AntivirusEnabled, 
        AntivirusSignatureAge, 
        AntivirusSignatureVersion, 
        BehaviorMonitorEnabled, 
        Enabled,
        EngineVersion, 
        IoavProtectionenabled, 
        Name, 
        NisEnabled,
        NisEngineVersion, 
        NisSignatureVersion, 
        OnAccessProtectionEnabled,
        ProductStatus, 
        RealTimeScanDirection, 
        RtpEnabled, 
        SchemaVersion,
        Version) AS CNT,
        AntispywareEnabled, 
        AntispywareSignatureAge, 
        AntispywareSignatureVersion,
        AntivirusEnabled, 
        AntivirusSignatureAge, 
        AntivirusSignatureVersion, 
        BehaviorMonitorEnabled, 
        Enabled,
        EngineVersion, 
        IoavProtectionenabled, 
        Name, 
        NisEnabled,
        NisEngineVersion, 
        NisSignatureVersion, 
        OnAccessProtectionEnabled,
        ProductStatus, 
        RealTimeScanDirection, 
        RtpEnabled, 
        SchemaVersion,
        Version
    FROM
        *AMHealthStatus.tsv
    GROUP BY
        AntispywareEnabled, 
        AntispywareSignatureAge, 
        AntispywareSignatureVersion,
        AntivirusEnabled, 
        AntivirusSignatureAge, 
        AntivirusSignatureVersion, 
        BehaviorMonitorEnabled, 
        Enabled,
        EngineVersion, 
        IoavProtectionenabled, 
        Name, 
        NisEnabled,
        NisEngineVersion, 
        NisSignatureVersion, 
        OnAccessProtectionEnabled,
        ProductStatus, 
        RealTimeScanDirection, 
        RtpEnabled, 
        SchemaVersion,
        Version
    ORDER BY
        CNT ASC
"@

    & logparser -stats:off -i:csv -dtlines:0 -fixedsep:on -rtp:-1 "$lpquery"

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}
