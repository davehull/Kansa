# This module is just designed to collect the powershell version information from all hosts in an enterprise
# This can be helpful when developing Kansa modules to know what powershell features will be available

$version = Get-Host | Select Name,Version,InstanceId,CurrentCulture,CurrentUICulture,IsRunspacePushed,Runspace
$result = @{}
$result.add('PSName', $version.Name)
$result.add('PSVersion', $version.Version.ToString())
$result.add('PSCulture', $version.CurrentCulture.DisplayName)
$result.add('PSUICulture',  $version.CurrentUICulture.DisplayName)
$result.add('PSisRunspacePushed', $version.IsRunspacePushed)
$result.add('PSRunspace', $version.Runspace.ToString())
Add-Result -hashtbl $result
