<# 
.SYNOPSIS
    Get-ForAttrDef is a wrapper for Get-ForensicAttrDef. Get-ForAttrDef parses the $AttrDef file on the specified volume 
    and returns information about all MFT file attributes usable in the volume.

    By default, the cmdlet parses the $AttrDef file on the C:\ drive. To change the target drive, use the VolumeName 
    parameter or use the Path parameter to specify an exported $AttrDef file.

.PARAMETER VolumeName
    Specifies the name of the volume or logical partition.

    Enter the volume name in one of the following formats: \\.\C:, C:, or C.
    Defaults to \\.\C:

.PARAMETER Path
    The path to the desired MFT.

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

[cmdletbinding(DefaultParameterSetName='ByVolume')]
Param(
    [Parameter(ParameterSetName = 'ByVolume')]
    [ValidatePattern('^(\\\\\.\\)?([A-Za-z]:)$')]
    [string]$VolumeName = '\\.\C:',

    [Parameter(Mandatory, ParameterSetName = 'ByPath', ValueFromPipelineByPropertyName = $true)]
    [string]$Path
)

begin{}

process{
    if($PSCmdlet.ParameterSetName -eq 'ByVolume'){
        Get-ForensicAttrDef -VolumeName $VolumeName
    }
    else{
        Get-ForensicAttrDef -Path $Path
    }
}
