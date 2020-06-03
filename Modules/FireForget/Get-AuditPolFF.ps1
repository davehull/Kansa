# This module is designed to enumerate/parse the current Windows Audit Policy Settings
# To validate that all audit policies match the domain-configured group policy
# settings.  Check to see if an adversary has changed local audit policy to evade 
# detection through logging or identify machines that have had their link to domain
# policy severed accidentally or maliciously

Function Get-StringHash([String] $String,$HashName = "MD5") 
{ 
    $StringBuilder = New-Object System.Text.StringBuilder 
    [System.Security.Cryptography.HashAlgorithm]::Create($HashName).ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))|%{ 
        [Void]$StringBuilder.Append($_.ToString("x2")) 
    } 
    $StringBuilder.ToString() 
}

$tmp = auditpol /get /category:*
$tmphash = Get-StringHash -String $tmp -HashName "MD5"
$result = @{}
$result.Add("AuditPolMD5", $tmphash)
$result.Add("AuditPolRaw", $tmp)
foreach ($t in $tmp) {
    $s = $t -replace "\s\s+",";"
    if($s.startswith(";")){
        $s2 = $s.Substring(1, $s.Length - 1) -split ";"
        $result.Add($s2[0],$s2[1])
    }
}
Add-Result -hashtbl $result
