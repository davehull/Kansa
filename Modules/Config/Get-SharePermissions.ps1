<#
.SYNOPSIS
Get-SharePermissions.ps1 enumerates the SMB shares on the local host and lists
the share permissions and NTFS access-control lists for them.
.NOTES
OUTPUT TSV
#>
[CmdletBinding()]
Param(

)

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
    
    foreach ($aclPerm in (((Get-Acl -Path $share.Path).AccessToString).Split("`n")))
    {
        $aclPermParts = $aclPerm -split "(Allow|Deny)"
        $aclRights = ($aclPermParts[2].Trim() -split ",").Trim()
        
        
        $o.Source = "ACL"
        $o.User = $aclPermParts[0]
        $o.Type = $aclPermParts[1]
        $o.IsOwner = $shareOwner -match ($aclPermParts[0].Trim() -replace "\\", "\\")
        $o.Full = $aclRights.Contains("FullControl")
        $o.Write = $aclRights.Contains("FullControl") -or $aclRights.Contains("Write")
        $o.Read = $aclRights.Contains("FullControl") -or $aclRights.Contains("Read")
        $o.Other = $aclPermParts[2].Trim() -match "(FullControl|Write|Read|,|\s){0}"

        $o
    }
}