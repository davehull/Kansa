<#

#>

function Get-SddlParts {
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [string]$Sddl
    )
    
    $splitStr = '(O:|G:|D:|S:)'
    $splitSddl = $Sddl -split $splitStr

    # Pop the first element off, as it's an empty string
    $null, $splitSddl = $splitSddl

    # Build and return an object with the different parts.
    while ($splitSddl) {
        $o = "" | Select-Object Part, Value
        $key, $value, $splitSddl = $splitSddl
        $o.Part = $key
        $o.Value = $value
        $o
    }
}


foreach ($share in (Get-SmbShare))
{
    $smbPerms = Get-SmbShareAccess -Name $share.Name
    try {
        $aclPerms = Get-SddlParts (Get-Acl -Path $share.Path).Sddl -ErrorAction SilentlyContinue
    }
    catch {
        $aclPerms = "Error getting ACL Permissions."
    }

    $share | fl *
    $smbPerms | fl *
    $aclPerms | fl *
}