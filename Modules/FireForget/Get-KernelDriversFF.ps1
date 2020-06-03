# This module will enumerate kernel Drivers via the registry and then gather metadata about the associated files
# including cryptographic hashes for outlier analysis and file-reputation enrichments

$keys = gci REGISTRY::HKLM\SYSTEM\ControlSet001\Services | Select-Object -ExpandProperty Name
foreach($key in $keys){
    if(((Get-Item "REGISTRY::$key" | where Property -Match "Type")  -and  (Get-ItemProperty "REGISTRY::$key" -Name Type).Type -eq 1)){ 
        $result = @{}
        [string]$keyName = $key.split('\')[-1].Replace("'", "")
        $result.add("Key",$keyName)
        $result.add("KeyPath","$key")
        $ImagePath = Get-ItemProperty -LiteralPath "REGISTRY::$key" | Select-Object -ExpandProperty "ImagePath" -ErrorAction SilentlyContinue
        $RealSystemPath = $ImagePath -replace "\\SystemRoot","$env:SystemRoot"
        if(!$Realsystempath -or !(Test-Path $RealSystemPath)){
            $RealSystemPath = $ImagePath -replace "[Ss]ystem32","$env:SystemRoot\System32"
        }
        
        $result.add("SystemPath", $ImagePath)
        $result.add("RealSystemPath", $RealSystemPath)
        if($RealSystemPath -and (Test-Path $RealSystemPath)){
            $result = Get-FileDetails -hashtbl $result -filepath $RealSystemPath -computeHash -algorithm @("MD5", "SHA256") -getContent
        }
        Add-Result -hashtbl $result
    }
}
