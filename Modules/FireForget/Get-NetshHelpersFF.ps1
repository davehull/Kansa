# A bad actor might try to establish persistence using the "netsh add helper" command to specify a malicious dll that will be
# loaded any time netsh is invoked. This module enumerates all of the NetSh helper DLLs in the registry.  It will collect the
# registry info and then find the DLLs on disk checking every folder in the path and collecting metadata on the files 
# including hash values.  You can then use aggregation and least-frequency-of-occurrence or file-reputation services on the
# hash values to identify anomalies/outliers.

$values = Get-ItemProperty "REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NetSh"
$NetshHelpersFound = 0
foreach($val in $($values.psobject.properties | Where Name -NotMatch "PSProvider|PSChildName|PSParentPath|PSPath")) {
    $NetshHelpersFound += 1
    if (($val.Value -match "\.dll")) { 
        $data = [string]$val.Value
        $suffix = $null
        if($data -match ':'){
            #"matched colon $data" | out-file "C:\temp\print.txt" -Append
            $paths = $data.Substring(0,$data.LastIndexOf('\')+1)
            $suffix = $data.Substring($data.LastIndexOf('\')+1, $($data.Length - ($data.LastIndexOf('\')+1))) 
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
                $result = @{}
                $result.add("NetshHelperValue","$($val.Name)")
                $result.add("NetshHelperData","$data")
                $result = get-fileDetails -hashtbl $result -computeHash -filepath $f -algorithm @("MD5","SHA256")
                $result.add("FoundFile", $present)
                Add-Result -hashtbl $result
            }
        }
        if(!$present){
            $result = @{}
            $result.add("NetshHelperKey", "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NetSh")
            $result.add("NetshHelperValue","$($val.Name)")
            $result.add("NetshHelperData","$data")
            $result.add("FoundFile", $present)
            Add-Result -hashtbl $result
        }     
    }
}

$result = @{}
$result.add("NetshHelpersFound",$NetshHelpersFound)
Add-Result -hashtbl $result
