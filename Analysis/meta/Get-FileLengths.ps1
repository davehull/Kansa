<#
.SYNOPSIS
Get-Lengths.ps1
Lists sizes for the user specified files. Enabling
analysts to quickly spot differences at a very high level.
.PARAMETER FileNamePattern
A pattern common to the files to be analyzed, for example,
-FileNamePattern SvcTrigs, will match all files with SvcTrigs
in their name.
.EXAMPLE
.\Get-FileLengths.ps1 -FileNamePattern ..\Output\*WMIEvt*
.EXAMPLE
.\Analysis\meta\Get-FileLengths.ps1 -FileNamePattern .\Output\*dnscache.tsv
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$FileNamePattern
)

function Get-Files {
<#
.SYNOPSIS
Returns the list of input files matching the user supplied file name pattern.
Traverses subdirectories.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$FileNamePattern
)
    Write-Verbose "Entering $($MyInvocation.MyCommand)"
    Write-Verbose "Looking for files matching user supplied pattern, $FileNamePattern"
    Write-Verbose "This process traverses subdirectories so it may take some time."
    $Files = @(ls -r $FileNamePattern)
    if ($Files) {
        Write-Verbose "File(s) matching pattern, ${FileNamePattern}:`n$($Files -join "`n")"
        $Files
    } else {
        Write-Error "No input files were found matching the user supplied pattern, `
            ${FileNamePattern}."
        Write-Verbose "Exiting $($MyInvocation.MyCommand)"
        exit
    }
    Write-Verbose "Exiting $($MyInvocation.MyCommand)"
}


$files = Get-Files $FileNamePattern

$files | Select-Object BaseName, Length | Sort-Object Length | ConvertTo-Csv -Delimiter "`t"