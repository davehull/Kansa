# Many security tools load driver filters at a particular altitude to prioritize order-of-operations
# when handling disk read/writes and other activity. Since some filters allow the driver to alter
# the data represented to lower/higher layers (i.e. seamless encryption/decryption of data at rest)
# There is the potential that an adversary could install/load malware as a driver filter to 
# intercept/manipulate filesystem operations like a rootkit.  This module will enumerate all driver
# filters and their altitude to help identify anomalies in an enterprise environment.

$filters = fltmc.exe filters
$drivers = driverquery.exe /v /FO CSV | ConvertFrom-Csv

$filters[3..$filters.length] | %{ 
    $filterTable = @{}
    $tmp = $_ -replace "\s+",':' -split ':'
    $filterTable.Add("FilterName",$tmp[0])
    $filterTable.Add("FilterInstances",$($tmp[1] -as [int]))
    $filterTable.Add("FilterAltitude",$($tmp[2] -as [int]))
    $filterTable.Add("FilterFrame",$($tmp[3] -as [int]))
    $driver = $drivers | Where "Module Name" -EQ $tmp[0]
    if($driver){
        $filterTable.Add("DriverDisplayName",$driver.'Display Name')
        $filterTable.Add("DriverDescription",$driver.Description)
        $filterTable.Add("DriverType",$driver.'Driver Type')
        $filterTable.Add("DriverStartMode",$driver.'Start Mode')
        $filterTable.Add("DriverState",$driver.State)
        $filterTable.Add("DriverStatus",$driver.Status)
        $filterTable.Add("DriverAcceptStop",[System.Convert]::ToBoolean($driver.'Accept Stop'))
        $filterTable.Add("DriverAcceptPause",[System.Convert]::ToBoolean($driver.'Accept Pause'))
        $filterTable.Add("DriverPagedPoolBytes",$($driver.'Paged Pool(bytes}' -as [int]))
        $filterTable.Add("DriverCodeBytes",$($driver.'Code(bytes)' -as [int]))
        $filterTable.Add("DriverBSSBytes",$($driver.'BSS(bytes)' -as [int]))
        if($driver.'Link Date'){
            $theDate = $driver.'Link Date' -as [datetime]
            $filterTable.Add("DriverLinkDate",$([datetime]::parseexact($theDate.toString("MM/dd/yyyy HH:mm:ss"), 'M/dd/yyyy HH:mm:ss', $null).tostring("yyyy-MM-ddTHH:mm:ss")+"-06:00"))
        }
        $filterTable.Add("DriverPath",$driver.Path)
        $filterTable.Add("DriverInitBytes",$($driver.'Init(bytes)' -as [int]))
        $filterTable = Get-FileDetails -hashtbl $filterTable -filepath $driver.Path -computeHash -algorithm @("MD5","SHA256")
    }

    Add-Result -hashtbl $filterTable
}
