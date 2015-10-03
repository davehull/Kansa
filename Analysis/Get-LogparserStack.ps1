<#
.SYNOPSIS
Get-LogparserStack.ps1 is an interactive script that can be used to 
calculate the frequency of data.
.PARAMETER FilePattern
A required parameter that will be used in Logparser's FROM clause.
Examples: *Autorunsc.tsv, *.csv, *.tsv
.PARAMETER Delimiter
An optional parameter that specifies the delimiter for both input and
output files. Default is "," for csv.
.PARAMETER Direction
An optional parameter that specifies whether the output should be 
sorted in ascending or the default descending order.
.PARAMETER OutFile
An optional parameter, the name of a file where output will be written.
.PARAMETER SaveQuery
An optional parameter, the name of a file where the query will be written.
.Parameter Divorce
An optional switch that if provided causes the script to create a new
subdirectory where it will move files with different headers. You can
then analyze files with common headers, then cd into the subdirectory
and repeat the analysis.
.EXAMPLE
Get-LogparserStack.ps1 -FilePattern *SigCheck.csv
.EXAMPLE
Get-LogparserStack.ps1 -FilePattern *.csv -Direction Ascending
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [string]$FilePattern,
    [Parameter(Mandatory=$False,Position=1)]
        [string]$Delimiter=",",
    [Parameter(Mandatory=$False,Position=2)]
        [string]$Direction="DESC",
    [Parameter(Mandatory=$False,Position=3)]
        [string]$OutFile,
    [Parameter(Mandatory=$False,Position=4)]
        [string]$SaveQueryTo,
    [Parameter(Mandatory=$False,Position=5)]
        [switch]$Divorce
)

$ErrorActionPreference = "Stop"
$VerbosePreference = "Continue"
$Error.Clear()

function GetTimeStampUtc {
    Get-Date (Get-Date).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ"
}

function GetInputFiles {
# Returns an array of files matching $FilePattern
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$FilePattern
)
    Write-Verbose ("{0}: Building list of files matching {1}." -f (GetTimeStampUtc), $FilePattern)
    $Files = @()
    $Files += (Get-ChildItem -Force *$FilePattern*)
    $Files
}

function GetHeader {
# Compare first two lines of each input file, if first two lines don't
# match each other, assume the first is a header line. If header lines
# from all files match, return header, else alert the user that some
# files don't have matching headers
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$InputFiles,
    [Parameter(Mandatory=$False,Position=1)]
        [string]$Delimiter
)
    $header   = @()
    $NumLines = 2

    $InputFiles | ForEach-Object {
        $line        = @()
        $currentFile = $_
        Try {
            # Write-Verbose("{0}: Reading first two lines of {1}." -f (GetTimeStampUtc), $currentFile.Name)
            $FileReader = New-Object System.IO.StreamReader($currentFile.FullName)
            for($i=0; $i -lt $NumLines; $i++) {
                $line += $FileReader.ReadLine()
            }
        } Catch {
            ("{0}: Caught: {1}." -f (GetTimeStampUtc), $currentFile.FullName)
        } Finally {
            $FileReader.Close()
        }

        # Write-Verbose ("{0}: Checking for presence of header in {1}." -f (GetTimeStampUtc), $currentFile.Name)
        if ($line[0] -ne $line[1]) {
            # First two lines should not match, if one is a header

            if ($header) {
                # Do we have a header yet?

                if ($header -eq $line[0]) {
                    # $header should match $line[0], move on
                    Write-Verbose ("{0}: Header match found in {1}." -f (GetTimeStampUtc), $currentFile.Name)
                } elseif (-not($Divorce)) {
                    # Files do not have matching header rows, may want to add an option in the future to discard files that don't have the expected header rather than quit.
                    Write-Host ("{0}: ## ERROR ##" -f (GetTimeStampUtc)) -ForegroundColor Red
                    Write-Host ("{0}: Header row of {1} does not match header row of {2}. Consider running again with the -Divorce flag. Quitting." -f (GetTimeStampUtc), $currentFile.Name, $previousFile.Name) -ForegroundColor Red
                    exit
                } elseif ($Divorce) {
                    # File does not have a matching header, make a new subdirectory and move it.
                    Write-Host ("{0}: Moving {1} to Divorced path." -f (GetTimeStampUtc), $currentFile.Name) -ForegroundColor Red
                    if (-not(Test-Path "${pwd}\Divorced")) {
                        New-Item -Path $pwd -Name Divorce -ItemType Directory
                    }
                    Move-Item $currentFile.FullName Divorce
                }
            } else {
                # First header
                Write-Verbose ("{0}: {1} appears to have a header on line one." -f (GetTimeStampUtc), $currentFile.Name)
                $header = $line[0]
                if ($Delimiter -match "`t" -and ($header -match "`"")) {
                    Write-Host ("{0}: {1} appears to have quoted field names. Logparser doesn't support quoted tab delimited data. Quitting.`n" -f (GetTimeStampUtc), $currentFile.Name) -ForegroundColor Red
                    exit
                }
            }
        } else {
            Write-Host ("{0}: The first two lines of {1} match each other. One of them should be a header. Quitting." -f (GetTimeStampUtc), $_.FullName)
            exit
        }
        # Keep track of our previous file for error reporting
        $previousFile = $currentFile
    }
    $header.split($Delimiter) -replace "`""
}

function GetSelectFields {
# Returns an array of fields that will be in the SELECT statement
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$header
)
    $SelectFields = @()
    $Field        = ""
    While($Field -ne "quit") {
        $Field = Read-Host ("[?] Enter the fields you want to GROUP BY, one per line. Enter `"quit`" when finished")
        if ($header -Contains $Field) {
            if ([array]::IndexOf($SelectFields, $Field) -lt 0) {
                $SelectFields += $Field
            } else {
                Write-Host -ForegroundColor red ("{0}: You've already entered {1}." -f (GetTimeStampUtc), $Field)
            }
        } elseif ($Field -ne "quit") {
            Write-Host -ForegroundColor red ("{0}: You entered {1}, which is not a field in the header row." -f (GetTimeStampUtc), $Field)
        }
    }

    if ($SelectFields.count) {
        $SelectFields
    } else {
        Write-Host -ForegroundColor red ("[*] You didn't select any fields. Quitting.")
        exit
    }
}

function GetStackField {
# Returns a field for frequency analysis
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$header
)
    $Field = $False
    While(!($Field)) {
        $Field = Read-Host ("[?] Enter the field to pass to COUNT()")
        if ($header -Contains $Field) {
            $Field
        } else {
            Write-Host -ForegroundColor red ("{0}: You entered {1}, which is not a field in the header row." -f (GetTimeStampUtc), $Field)
            $Field = $False
        }
    }
}

function GetQuery {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [string]$StackField,
    [Parameter(Mandatory=$True,Position=1)]
        [Array]$SelectFields,
    [Parameter(Mandatory=$False,Position=2)]
        [string]$Direction="DESC",
    [Parameter(Mandatory=$False,Position=3)]
        [string]$OutFile=$false,
    [Parameter(Mandatory=$False,Position=4)]
        [string]$SaveQueryTo=$false
)
    $BracketedFields = @()
    if ($Direction -notmatch "DESC") {
        $Direction = $null
    }
    $Query = @"
SELECT 
`tCOUNT([$StackField]) as CNT
"@
    $SelectFields | ForEach-Object {
        $BracketedFields += "[$_]"
    }
    $Query += ",`n`t" + ($BracketedFields -join ",`n`t")
    if ($OutFile) {
        $Query += "`n INTO $OutFile"
    }
    $Query += "`nFROM $FilePattern`n"
    $Query += "GROUP BY`n`t" + ($BracketedFields -join ",`n`t")
    $Query += "`nORDER BY`n`t CNT $Direction"
    
    if ($SaveQueryTo) {
        $Query | Set-Content -Encoding Ascii $SaveQueryTo
    }

    $Query
}

if (Get-Command logparser.exe) {
    $CallArgs = @('-stats:off')
    $InputFiles = GetInputFiles -FilePattern $FilePattern
    $Header = GetHeader -InputFiles $InputFiles -Delimiter $Delimiter
    
    Write-Host ("Header row is:`n`t" + ($Header -join ", "))
    $StackField   = GetStackField -header $Header
    $SelectFields = GetSelectFields -header $Header

    $Query = GetQuery -StackField $StackField -SelectFields $SelectFields -Direction $Direction -OutFile $OutFile -SaveQueryTo $SaveQueryTo

    switch ($Delimiter) {
        "," {
            $CallArgs += "-i:csv"
        }
        "`t" {
            $CallArgs += "-i:tsv"
            $CallArgs += "-fixedsep:on"
        } default {
            $CallArgs += "i:tsv"
            $CallArgs += "-iseparator:$Delimiter"
            $CallArgs += "-fixedsep:on"
        }
    }


    if ($OutFile) {
        $CallArgs += "-dtlines:0"
        $CallArgs += "-o:tsv"
        $CallArgs += "-oSeparator:$Delimiter"
        $CallArgs += "$Query"
        Write-Verbose ("{0}: Will attempt to write output to {1}." -f (GetTimeStampUtc), $OutFile)
        Try {
            & 'logparser' $CallArgs
        } Catch {
            ("{0}: Caught {1}." -f (GetTimeStampUtc), $_)
        }
    } else {
        $CallArgs += "-dtlines:0"
        $CallArgs += "-rtp:-1"
        $CallArgs += "$Query"
        & 'logparser' $CallArgs
    }

} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}