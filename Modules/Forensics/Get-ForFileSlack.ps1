<# 
.SYNOPSIS
    Get-ForFileSlack is a wrapper for Get-ForensicFileSlack. Get-ForFileSlack gets 
    the specified volume's slack space as a byte array.

    "Slack space" is the difference between the true size of a file's contents and 
    the allocated size of a file on disk.

    When NTFS stores data in a file, the data must be allocated in cluster-sized 
    chunks (commonly 4096 bytes), which creates slack space.

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
        Get-ForensicFileSlack -VolumeName $VolumeName
    }
    else{
        Get-ForensicFileSlack -Path $Path
    }
}
