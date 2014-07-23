<#
.SYNOPSIS
Get-SharePermissions.ps1 enumerates the SMB shares on the local host and lists
the share permissions and NTFS access-control lists for them.
.NOTES
OUTPUT TSV
#>

function Get-UserFromSid {
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [string]$Sid
    )
    try {
        $objSid = New-Object System.Security.Principal.SecurityIdentifier($Sid)
        $objUser = $objSid.Translate([System.Security.Principal.NTAccount])
    }
    catch {
        $objUser = $false
    }

    return $objUser.Value
}

# Not currently in use.
function Get-DescriptorControlFlags {
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [string]$DCFlags
    )

    # DACL and SACL use the same control flags, so we don't care which is passed.
    #
    # Reference:
    # - http://msdn.microsoft.com/en-us/library/windows/desktop/aa379570(v=vs.85).aspx

    $flags = "" | Select-Object Protected, AutoInheritRequired, AutoInherited, Null

    $flags.Protected = $DCFlags -match "P"
    $flags.AutoInheritRequired = $DCFlags -match "AR"
    $flags.AutoInherited = $DCFlags -match "AI"
    $flags.Null = $DCFlags -match "NO_ACCESS_CONTROL"

    return $flags
}

function Get-SddlParts {
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [string]$Sddl
    )

    # References:
    # - http://networkadminkb.com/KB/a152/how-to-read-a-sddl-string.aspx
    # - http://networkadminkb.com/KB/a6/understanding-the-sddl-permissions-in-the-ace-string.aspx
    # - http://msdn.microsoft.com/en-us/library/windows/desktop/aa374928(v=vs.85).aspx
    # - http://msdn.microsoft.com/en-us/library/windows/desktop/aa379570(v=vs.85).aspx
    
    $sidRegEx = 'S-\d-\d-\d+-\d{10}-\d{10}-\d{10}-\d{3,}'
    $splitStr = '(O|G|D|S):'
    $splitSddl = $Sddl -split $splitStr

    # Pop the first element off, as it's an empty string
    $null, $splitSddl = $splitSddl

    # Build and return an object with the different parts.
    while ($splitSddl) {
        $o = "" | Select-Object Part, Value
        $key, $value, $splitSddl = $splitSddl
        $o.Part = $key
        $o.Value = $value

        # If owner or group is a SID, get the associated user or group name.
        if ((($key -eq "O") -or ($key -eq "G")) -and ($value -match $sidRegEx))
        {
            if ($user = Get-UserFromSid -Sid $value) {
                $o.Value = "$user ($value)"
            }            
        }

        $o
    }
}

foreach ($share in (Get-SmbShare -name "test"))
{
    $shareOwner = (Get-Acl -Path $share.Path).Owner
    
    $o = "" | Select-Object Share, Path, Source, User, Type, IsOwner, Full, Write, Read, Other
    $o.Share = $share.Name
    $o.Path = $share.Path

    foreach ($smbPerm in (Get-SmbShareAccess -Name $share.Name))
    {
        $o.Source = "SMB"
        $o.User = $smbPerm.AccountName
        $o.Type = $smbPerm.AccessControlType
        $o.IsOwner = $shareOwner -match ($smbPerm.AccountName -replace "\\", "\\")
        $o.Full = $smbPerm.AccessRight -match "Full"
        $o.Write = $smbPerm.AccessRight -match "(Full|Change)"
        $o.Read = $smbPerm.AccessRight -match "(Full|Change|Read)"
        $o.Other = $smbPerm.AccessRight -notmatch "(Full|Change|Read)"

        $o
    }
    
    <#
    foreach ($aclPerm in (Get-SddlParts (Get-Acl -Path $share.Path).Sddl))
    {
        $o.Source = "ACL"
        $o.User = $aclPerm.AccountName
        $o.Type = $aclPerm.AccessControlType
        $o.IsOwner = $shareOwner -match $aclPerm.AccountName
        $o.Full = $aclPerm.AccessRight -match "Full"
        $o.Write = $aclPerm.AccessRight -match "(Full|Write)"
        $o.Read = $aclPerm.AccessRight -match "(Full|Read)"
        $o.Other = $aclPerm.AccessRight -notmatch "(Full|Write|Read)"

        $o
    }
    #>
}