<#
.SYNOPSIS
Get-OfficeMRU.ps1 acquires Microsoft Office MRU from registry
and reformats on the target as tsv output.

.NOTES
Next line needed by Kansa.ps1 for proper handling of this script's data
OUTPUT tsv
#>

# versions of Microsoft office
$office_versions = @("15.0", #2013
				"14.0", #2010
				"11.0", #2003
				"10.0", #2002
				"9.0" #2000
				)
				

# get a list of all users on the computer
Try {
	$user_SIDs = gwmi win32_userprofile | select sid
}
Catch{
	$user_SIDs = @()
	Write-Error -Message "Unable to obtain SID list"
}

# If anything goes wrong with checking the registry, exit without
# killing the rest of the program
Try {
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
						$office_app_mru_key = Get-ChildItem -Path Registry::$office_app_key; 

						# this subkey should contain the File and Place MRU entries we want
						# to extract the data from
						ForEach ($mru_key in (Get-ChildItem -Path Registry::$office_app_mru_key)){
							$item = Get-ItemProperty -Path Registry::$mru_key
							$item
						}
					}
				}
			}
		}
	 }

Catch{
	Write-Error -Message "Unable to retrieve data from registry"
}
