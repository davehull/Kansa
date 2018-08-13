<#
.SYNOPSIS
Get-RegKey.ps1 retrieves the user specified registry key.
.PARAMETER KeyPath
A required parameter, the key path to the registry key.

.PARAMETER KeyValue
A required parameter, the key path value, * for all values

.Example:
Kansa.ps1 ".\Modules\Config\Get-RegKey.ps1 HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Run,*" -Target localhost

.Example:
Kansa.ps1 ".\Modules\Config\Get-RegKey.ps1 HKEY_LOCAL_MACHINE\Software\Microsoft\Windows NT\CurrentVersion\AeDebug,Debugger" -Target localhost

OUTPUT csv
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$KeyPath,
    [Parameter(Mandatory=$True,Position=1)]
        [String]$KeyValue
)
	
$KeyPath = $KeyPath -replace "HKEY_LOCAL_MACHINE","HKLM:"
$KeyPath = $KeyPath -replace "HKEY_CURRENT_USER" ,"HKCU:"
$KeyPath = $KeyPath -replace "HKEY_USERS" , "HKU:"
$KeyPath = $KeyPath -replace "HKEY_CURRENT_CONFIG" , "HKCC:"
$KeyPath = $KeyPath -replace "HKEY_CLASSES_ROOT" , "HKCR:"
	
#Read all key values
if ($KeyValue -eq '*'){

    # Loop over the key values
	Get-Item -Path $KeyPath -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Property | ForEach-Object {
		$entry = New-Object -TypeName PSObject
		
		#Add the key to the PS Object
		$entry | Add-Member NoteProperty -Name KeyPath -Value $KeyPath		
		
		#Add the value to the PS Object
		$name =$_;
		$entry | Add-Member NoteProperty -Name KeyValue -Value $name
		
		#Retrieve the value data, then add it to PS Object
		$data=(Get-Item -Path $KeyPath -ErrorAction SilentlyContinue |  Get-ItemProperty -name $name -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $name);
		$entry | Add-Member NoteProperty -Name Data -Value $data
		
		#Return Result
		$entry
	}
}
else{

	$entry = New-Object -TypeName PSObject
	
	#Add the key to the PS Object
	$entry | Add-Member NoteProperty -Name Key -Value $KeyPath
	
	#Add the value to the PS Object
	$entry | Add-Member NoteProperty -Name Name -Value $KeyValue
	
	#Retrieve the value data, then add it to PS Object
	$data=(Get-Item -Path $KeyPath -ErrorAction SilentlyContinue |  Get-ItemProperty -name $KeyValue -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $KeyValue)	
	$entry | Add-Member NoteProperty -Name Data -Value $data	

	#Return Result
	$entry
}