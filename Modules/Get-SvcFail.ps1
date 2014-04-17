# OUTPUT tsv
# get service failure
$data = $($(foreach ($svc in (& $env:windir\system32\sc query)) { 
    if ($svc -match "SERVICE_NAME:\s(.*)") { 
        & $env:windir\system32\sc qfailure $($matches[1])}}))

$ServiceName = $RstPeriod = $RebootMsg = $CmdLine = $FailAction1 = $FailAction2 = $FailAction3 = $False
# ("ServiceName","ResetPeriod","RebootMessage","CommandLine", "FailureAction1", "FailureAction2", "FailureAction3") -join $Delimiter
foreach($line in $data) {
    if ($line.StartsWith("[SC]")) {
        continue
    }
    $line = $line.Trim()
    if ($line -match "^S.*\:\s(?<SvcName>[-_A-Za-z0-9]+)") {
        if ($ServiceName) {
            $o = "" | Select-Object ServiceName, RstPeriod, RebootMsg, CmdLine, FailAction1, FailAction2, FailAction3
            $o.ServiceName, $o.RstPeriod, $o.RebootMsg, $o.CmdLine, $o.FailAction1, $o.FailAction2, $o.FailAction3 = `
                (($ServiceName,$RstPeriod,$RebootMsg,$CmdLine,$FailAction1,$FailAction2,$FailAction3) -replace "False", $null)
            $o
        }
        $ServiceName = $matches['SvcName']
    } elseif ($line -match "^RESE.*\:\s(?<RstP>[0-9]+|INFINITE)") {
        $RstPeriod = $matches['RstP']
    } elseif ($line -match "^REB.*\:\s(?<RbtMsg>.*)") {
        $RebootMsg = $matches['RbtMsg']
    } elseif ($line -match "^C.*\:\s(?<Cli>.*)") {
        $CmdLine = $matches['Cli']
    } elseif ($line -match "^F.*\:\s(?<Fail1>.*)") {
        $FailAction1 = $matches['Fail1']
        $FailAction2 = $FailAction3 = $False
    } elseif ($line -match "^(?<FailNext>REST.*)") {
        if ($FailAction2) {
            $FailAction3 = $matches['FailNext']
        } else {
            $FailAction2 = $matches['FailNext']
        }
    }
}
$o = "" | Select-Object ServiceName, RstPeriod, RebootMsg, CmdLine, FailAction1, FailAction2, FailAction3
$o.ServiceName, $o.RstPeriod, $o.RebootMsg, $o.CmdLine, $o.FailAction1, $o.FailAction2, $o.FailAction3 = `
    (($ServiceName,$RstPeriod,$RebootMsg,$CmdLine,$FailAction1,$FailAction2,$FailAction3) -replace "False", $null)
$o