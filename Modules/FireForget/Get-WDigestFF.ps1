# This module will check the registry key/path associated with the deprecated Wdigest authentication standard. This allowed windows
# to cache plaintext credentials for handling authentication/reauth for sites that did not support newer protocols like SAML/OAUTH.
# Malicious actors may use tools like mimikatz to re-enable this feature thus storing credentials in plaintext where they can be 
# stolen more easily. In Windows 8 and prior, the absence of this key indicated that hotfix was not installed and therefore the 
# system is vulnerable. Whereas in version 10, the default state (or absence of this key) is safe. Any time the key exists with a 
# data value of 1 (enabled) means that regardless of the OS version it is chaching plaintext creds and therefore vulnerable.
# https://support.microsoft.com/en-gb/help/2871997/microsoft-security-advisory-update-to-improve-credentials-protection-a
# https://docs.microsoft.com/en-us/windows/win32/sysinfo/operating-system-version

$WDigestValue = (Get-ItemProperty REGISTRY::HKEY_LOCAL_MACHINE\System\CurrentControlSet\Control\SecurityProviders\WDigest).UseLogonCredential
if(($WDigestValue -eq "") -or ($WDigestValue -eq $null)){$WDigestValue = -1}

$result = @{}
$vulnerable = $false
$result.add("WDigestValue",$WDigestValue)
$result.add("OSVersion",$OSversion)
$result.add("OSFriendlyName",$OSfriendly)
$result.add("OSServicePack",$OSsvcPack)
$result.add("OSbitness",$OSbitness)
if($WDigestValue -eq 1){ 
    $vulnerable = $true 
}elseif(($OSversion -notmatch "^10\.0") -and ($OSversion -notmatch "^6\.3")){
    if($WDigestValue -eq -1){ $vulnerable = $true }
}
$result.add("Vulnerable",$vulnerable)
Add-Result -hashtbl $result
