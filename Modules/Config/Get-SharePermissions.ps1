<#
.SYNOPSIS
Get-SharePermissions.ps1 enumerates the SMB shares on the target host and lists
the share and NTFS access rights for them.
.NOTES
OUTPUT TSV
#>
[CmdletBinding()]
Param(

)

foreach ($share in (Get-SmbShare))
{
    $shareName = $share.Name
    Write-Verbose "Grabbing share rights for $shareName"
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
    
    foreach ($aclPerm in (((Get-Acl -Path $share.Path).AccessToString).Split("`n")))
    {
        $aclPermParts = $aclPerm -split "(Allow|Deny)"
        $aclRights = ($aclPermParts[2].Trim() -split ",").Trim()
        
        
        $o.Source = "ACL"
        $o.User = $aclPermParts[0]
        $o.Type = $aclPermParts[1]
        $o.IsOwner = $shareOwner -match ($aclPermParts[0].Trim() -replace "\\", "\\")
        $o.Full = $o.Write = $o.Read = $o.Other = $False

        # The way ACL entries are written out as a string is...odd. I would
        # have preferred to use SDDL output, but parsing it lead me down too
        # many rabbit holes.
        while($aclRights)
        {
            $aclRight, $aclRights = $aclRights

            switch ($aclRight)
            {
                "FullControl" { $o.Full  = $o.Write = $o.Read = $True; break }
                "Write"       { $o.Write = $True; break }
                "Read"        { $o.Read  = $True; break }
                default       { $o.Other = $True }
            }
        }

        $o
    }
}