<#
.SYNOPSIS
Get-SharePermissions.ps1 enumerates the SMB shares on the local host and lists
the share permissions and NTFS access-control lists for them.
.NOTES
OUTPUT TSV
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

        # If it's a SID, also get the associated username.
        if ((($key -eq "O:") -or ($key -eq "G:")) -and ($value.Length -gt 5))
        {
            $objSid = New-Object System.Security.Principal.SecurityIdentifier($value)
            $objUser = $objSid.Translate([System.Security.Principal.NTAccount])
            $o.Value = $objUser.Value + " ($value)"
        }

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

    #$o = "" | Select-Object Share, Path, Source, User, IsOwner, Read, Write, Modify
}