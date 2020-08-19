<# 
.SYNOPSIS
    Get-ForFileRecordIndex is a wrapper for Get-ForFileRecordIndex. Get-ForFileRecordIndex returns the 
    Master File Table Record Index Number for the specified file.

.PARAMETER Path
    The path of a file for which the user wants the MFT record entry for.

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

Param(
    [Parameter(Mandatory, ParameterSetName = 'ByPath')]
    [Alias('FullName')]
    [string]$Path
)

begin{}

process{
    Get-ForensicFileRecordIndex -Path $Path
}
