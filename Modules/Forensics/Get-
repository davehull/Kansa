<# 
.SYNOPSIS
    Get-ForUsnJrnl is a wrapper for Get-ForensicUsnJrnl. Get-ForUsnJrnl cmdlet parses the 
    $UsnJrnl file's $J data stream to return UsnJrnl entries. If you do not specify a Usn 
    (Update Sequence Number), it returns all entries in the $UsnJrnl.

    The $UsnJrnl file maintains a record of all file system operations that have occurred. 
    Because the file is circular, entries are overwritten.

.PARAMETER VolumeName
    Specifies the name of the volume or logical partition.

    Enter the volume name in one of the following formats: \\.\C:, C:, or C.
    Defaults to \\.\C:


.PARAMETER Usn
    Specifies the Update Sequence Number

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

[cmdletbinding(DefaultParameterSetName='ByVolume')]
Param(
    [Parameter(ParameterSetName = 'ByVolume')]
    [ValidatePattern('^(\\\\\.\\)?([A-Za-z]:)$')]
    [string]$VolumeName = '\\.\C:',

    [Parameter(Mandatory, ParameterSetName = 'ByUsn')]
    [long]$Usn
)

begin{}

process{
    if($PSCmdlet.ParameterSetName -eq 'ByVolume'){
        Get-ForensicUsnJrnl -VolumeName $VolumeName
    }
    else{
        Get-ForensicUsnJrnl -Usn $Usn
    }
}
