<#
.SYNOPSIS
Get-OfficeMRU.ps1 acquires Microsoft Office MRU from registry
#>


$Error.Clear()
$ErrorActionPreference = "SilentlyContinue"

# versions of Microsoft office
$office_versions = @("15.0", #2013
				"14.0", #2010
				"11.0", #2003
				"10.0", #2002
				"9.0" #2000
				)

# get a list of all users on the computer
$user_SIDs = gwmi win32_userprofile | select sid

# loop through each user in the registry to get records
Foreach ($user_SID in $user_SIDs.sid){

	# loop through the array for all versions of Microsoft Office
	Foreach ($version in $office_versions){

		# sets the base path in the registry based on the user SID
		$key_base = "\HKEY_USERS\" + $user_SID + "\software\microsoft\office\" + $version +"\" 

		# test the office version, if it exists, continue
		If (test-path -Path registry::$key_base) {

			# gets the MRU files for each office app installed
			$office_key_ring = Get-ChildItem -Path Registry::$key_base 

			# check each key for MRU entries
			ForEach ($office_key in $office_key_ring){
				$office_app_key = $office_key.name + "\user mru"

				# check to see if the app (Word, Excel, etc) has a MRU key
				if (test-path -Path Registry::$office_app_key) {

					# since the subkey has a random name, we need to cycle through each entry
					Get-ChildItem -Path Registry::$office_app_key -Recurse; 
				}
			}
		}
	}
}

if ($Error) {
	# Write the $Error to the $Errorlog
    Write-Error "Get-OfficeMRU Error on $env:COMPUTERNAME"
    Write-Error $Error
	$Error.Clear()
}
Write-Debug "Exiting $($MyInvocation.MyCommand)" 