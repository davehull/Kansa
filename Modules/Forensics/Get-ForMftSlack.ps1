<# 
.SYNOPSIS
    Get-ForMftSlack is a wrapper for Get-ForensicMftSlack. Get-ForMftSlack 
    returns a byte array representing the slack space found in Master File 
    Table (MFT) records.

    Each MFT File Record is 1024 bytes long. When a file record does not 
    allocate all 1024 bytes, the remaining bytes are considered "slack". 
    To compute slack space, compare the AllocatedSize and RealSize properties 
    of a FileRecord object.

.PARAMETER VolumeName
    Specifies the name of the volume or logical partition.

    Enter the volume name in one of the following formats: \\.\C:, C:, or C.
    Defaults to \\.\C:

.PARAMETER Index
    Specifies the index number of the file to return slack space for.

.PARAMETER Path
    The path of the file to return slack space for.

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

    [Parameter(ParameterSetName = 'ByPath')]
    [string]$Path
)

begin{}

process{
    if($PSCmdlet.ParameterSetName -eq 'ByVolume'){
        Get-ForensicMftSlack -VolumeName $VolumeName
    }
    else{
        Get-ForensicMftSlack -Path $Path
    }
}
