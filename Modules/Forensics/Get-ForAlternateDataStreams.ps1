<# 
.SYNOPSIS
    Get-ForAlternateDataStream is a wrapper for Get-ForensicAlternateDataStream. Get-ForAlternateDataStream parses the Master File Table 
    and returns AlternateDataStream objects for files that contain more than one $DATA attribute.

    NTFS stores file contents in $DATA attributes. The file system allows a single file to maintain multiple $DATA attributes. When a file 
    has more than one $DATA attribute the additional attributes are referred to as "Alternate Data Streams".

.PARAMETER VolumeName
    Specifies the name of the volume or logical partition.

    Enter the volume name in one of the following formats: \\.\C:, C:, or C.
    Defaults to \\.\C:

.PARAMETER Path
    The path of a file that should be checked for alternate data streams.

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

[cmdletbinding(DefaultParameterSetName='ByVolume')]
Param(
    [Parameter(ParameterSetName = 'ByVolume')]
    [ValidatePattern('^(\\\\\.\\)?([A-Za-z]:)$')]
    [string]$VolumeName = '\\.\C:',

    [Parameter(Mandatory, ParameterSetName = 'ByPath')]
    [Alias('FullName')]
    [string]$Path
)

begin{}

process{
    if($PSCmdlet.ParameterSetName -eq 'ByVolume'){
        Get-ForensicAlternateDataStream -VolumeName $VolumeName
    }
    else{
        Get-ForensicAlternateDataStream -Path $Path
    }
}
