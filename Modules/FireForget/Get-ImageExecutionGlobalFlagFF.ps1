# Module to enumerate Registry persistence keys using Image File execution "global" flag
# or Silent process exit debugger attachments

$tmp = Gci 'REGISTRY::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$globalFlagFound = $false
$tmp | % {
    if (($_.Property -match "GlobalFlag") -or ($_.Property -match "Debugger")) { 
        $globalFlagFound = $true
        $Values = $_.GetValueNames()
        foreach ($val in $values) {
            $result = @{}
            $result.add("ImageFileSubKey",$_.Name)
            $result.add("ImageFileSubKeyValue",$val)
            $result.add("ImageFileSubKeyData",$($_.GetValue($val)))
            Add-Result -hashtbl $result
        }
    } 
}

$tmp = Gci 'REGISTRY::HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit'
$tmp | % {
    if (($_.Property -match "ReportingMode") -or ($_.Property -match "MonitorProcess")) {
        $globalFlagFound = $true
        $Values = $_.GetValueNames()
        foreach ($val in $values) {
            $result = @{}
            $result.add("ImageFileSubKey",$_.Name)
            $result.add("ImageFileSubKeyValue",$val)
            $result.add("ImageFileSubKeyData",$($_.GetValue($val)))
            Add-Result -hashtbl $result
        }
    } 
}
if (!$globalFlagFound){
    $result = @{}
    $result.add("ImageFileSubKey","No GlobalFlags Persistence Found")
    Add-Result -hashtbl $result
}
