# A known persistence mechanism is to create a malicious DLL and add it as a print monitor on the endpoint
# Then every time the system boots it loads the print monitors to monitor the printer spool service. Since
# the printmonitor dll name is attacker controlled simply monitoring for specific filenames is pointless.
# Also print monitors are added to the registry any time a printer driver is installed. This module 
# enumerates all printmonitor dlls then tests all locations in the system path for the presence of a dll
# with that name. If found it collects all the metadata including cryoptographic hash values. Aggregating
# this data in ELK can identify outliers, and additional enrichment scripts can be used to compare all
# unique hash values using a file-reputation service/API like virustotal to identify malicious or unknown
# dlls posing as print monitors

$keys = Gci 'REGISTRY::HKLM\SYSTEM\CurrentControlSet\Control\Print\Monitors'
$globalFlagFound = $false
foreach($key in $keys) {
    if (($key.Property -match "Driver") -or ($key.Property -match "\.dll$")) { 
        $printMonitorFound = $true
        $Values = $key.GetValueNames()
        foreach ($val in $Values) {
            $data = [string]$key.GetValue($val)
            $result = @{}
            $result.add("PrintMonitorSubKey",$key.Name)
            $result.add("PrintMonitorValue","$val")
            $result.add("PrintMonitorData","$data")

            $suffix = $null
            if($data -match ':'){
                $paths = $data
            }else{
                $paths = $env:Path -split ';' | %{ $_ + '\'}
                $suffix = "$data"
            }
            $present = $false
            foreach($p in $paths){
                $f = $p+$suffix
                if(test-path -LiteralPath $f -PathType Leaf){
                    $present = $true
                    $file = gi -Force -LiteralPath $f
                    $result = get-fileDetails -hashtbl $result -computeHash -filepath $f -algorithm @("MD5","SHA256")
                } 
            }
            $result.add("FoundFile", $present)
            Add-Result -hashtbl $result
        }
    } 
}
if (!$printMonitorFound){
    $result = @{}
    $result.add("PrintMonitorSubKey","No Printmonitor Persistence Found")
    Add-Result -hashtbl $result
}
