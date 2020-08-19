<# 
.SYNOPSIS
    Get-ForFileRecord is a wrapper for Get-ForensicFileRecord. Get-ForFileRecord parses the $MFT file 
    and returns an array of FileRecord entries.

    By default, this cmdlet parses the $MFT file on the C:\ drive. To change the target drive, 
    use the VolumeName parameter or use the Path parameter to specify an exported $MFT file.

.PARAMETER VolumeName
    Specifies the name of the volume or logical partition.

    Enter the volume name in one of the following formats: \\.\C:, C:, or C.
    Defaults to \\.\C:

.PARAMETER Index
    Specifies the index of the file record in the MFT. 

.PARAMETER Path
    The path to the MFT; could be on a volume different from the default.

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

[cmdletbinding(DefaultParameterSetName='ByVolume')]
Param(
    [Parameter(ParameterSetName = 'ByVolume')]
    [ValidatePattern('^(\\\\\.\\)?([A-Za-z]:)$')]
    [string]$VolumeName = '\\.\C:',

    [Parameter(ParameterSetName = 'ByVolume')]
    [long]$Index = 0,

    [Parameter(Mandatory, ParameterSetName = 'ByPath')]
    [string]$Path
)

begin{}

process{
    if($PSCmdlet.ParameterSetName -eq 'ByVolume'){
        if($PSBoundParameters.ContainsKey('Index')){
            Get-ForensicFileRecord -VolumeName $VolumeName -Index $Index
        }
        else{
            Get-ForensicFileRecord -VolumeName $VolumeName
        }
    }
    else{
        Get-ForensicFileRecord -Path $Path
    }
}
