<#
.SYNOPSIS
Get-Lengths.ps1
Lists file sizes for the data acquired by Kansa modules, enabling
analysts to quickly spot differences at a very high level.
.PARAMETER Path
The path to the results to be analyzed.
.NOTES
OUTPUT tsv
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Path
)

# All Kansa module ouput follows the naming convention Host-Module.ext
# So bring in all files with a hyphen in their names
$files = ls -r $Path | ? { $_.Name -match ".*\-.*" }

$files | Select-Object BaseName, Length | Sort-Object Length | ConvertTo-Csv -Delimiter "`t"