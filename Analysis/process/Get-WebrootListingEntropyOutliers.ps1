<#
.SYNOPSIS
Get-WebrootListingEntropyOutliers.ps1

Compares files entropy to the average of others with the same extension
and outputs those more than 3 * MAD from the mean.

Requires logparser.exe in your path.
.NOTES
DATADIR WebrootListing
#>

function Get-Median {
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [double[]]$Data
    )

    $Data = $Data | Sort-Object
    if ($Data.Count%2) {
        # Odd number of elements, return the one in the middle.
        $Median = $Data[[Math]::Floor($Data.Count/2)]
    }
    else {
        # Even number of elements, return the average of the two 
        # middle values.
        $Median = ($Data[$Data.Count/2], $Data[($Data.Count/2) - 1] | Measure-Object -Average).Average
    }
    return $Median
}

function Get-MedianAbsoluteDeviation {
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [double[]]$Data,
        [Parameter(Mandatory=$False,Position=1)]
            [double]$Center=(Get-Median $Data),
        [Parameter(Mandatory=$False,Position=2)]
            [double]$ScaleFactor=1.4826
    )

    # Median Absolute Deviation is a robust measure of vaiance in a 
    # statistical sample. There are many different variations of the
    # same concept, including Mean Absolute Deviation (change $Center
    # to the output of ($Data | Measure-Object -Average).Average).
    #
    # This is a rough translation of the R function mad() to PowerShell.

    $MAD = $ScaleFactor * (Get-Median ($Data | foreach { [Math]::Abs($_ - $Center) }))
    return $MAD
}

if (Get-Command logparser.exe) {
    $lp_query = @"
        SELECT
            EXTRACT_EXTENSION(FullName) AS Extension,
            AVG(ALL TO_REAL(Entropy)) AS AvgEntropy
        FROM
            *WebRootListing.tsv
        GROUP BY
            EXTRACT_EXTENSION(FullName)
        HAVING
            AvgEntropy > 0.0
"@

    # Get file extensions with entropy (excludes directories).
    $lp_results = & logparser -stats:off -i:tsv -o:csv -dtlines:0 -fixedsep:on "$lp_query" | ConvertFrom-Csv

    # LogParser doesn't have built-in formulas for deviation, so we have
    # to do this step ourselves.
    foreach ($lp_result in $lp_results) {
        $extension = $lp_result.Extension
        $avgEntropy = $lp_result.AvgEntropy

        $lp_query = @"
            SELECT
                FullName,
                Length,
                CreationTimeUtc,
                LastAccessTimeUtc,
                LastWriteTimeUtc,
                Entropy,
                PSComputerName
            FROM
                *WebRootListing.tsv
            WHERE
                EXTRACT_EXTENSION(FullName) = '$extension'
"@
        
        $lp_files = & logparser -stats:off -i:tsv -o:csv -dtlines:0 -fixedsep:on "$lp_query" | ConvertFrom-Csv
        $ext_MAD = Get-MedianAbsoluteDeviation ($lp_files).Entropy

        foreach ($lp_file in $lp_files) {
            if ([Math]::Abs($lp_file.Entropy - $avgEntropy) -gt (3 * $ext_MAD)) {
                $o = $lp_file | Select-Object "FullName","Length","CreationTimeUtc","LastAccessTimeUtc","LastWriteTimeUtc","Entropy","PSComputerName"
                Add-Member -InputObject $o -MemberType NoteProperty -Name "EntropyAvg" -Value $avgEntropy
                Add-Member -InputObject $o -MemberType NoteProperty -Name "EntropyMAD" -Value $ext_MAD
                $o
            }
        }
    }
} else {
    $ScriptName = [System.IO.Path]::GetFileName($MyInvocation.ScriptName)
    "${ScriptName} requires logparser.exe in the path."
}