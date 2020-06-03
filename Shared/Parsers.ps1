<#
.SYNOPSIS
Author: Joseph Kjar
Date: 10/2016
This script contains the functions used to clean up and parse the raw kansa output. If your 
kansa output needs to be massaged to accomodate a consumer, a function can be created here
and called within the main kansa.ps1 script.
#>


function DecompressJSON {
<#
.SYNOPSIS
Due to a bug in powershell, it is necessary to export all raw kansa output as "compressed" JSON.
This isn't true compression, it just removes all extra whitespace in the JSON output.
However, most JSON consumers struggle with the compressed JSON despite the fact that it is 
syntactically correct. As a result, it is necessary to write the raw output in the compressed format
and then use this function to uncompress it by restoring the whitespace.
#>

Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
    $rawDataPaths
)

    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    Try { 
        foreach ($dataPath in $rawDataPaths){
            # Read in compressed JSON
            $c = Get-Content $dataPath

            # Add a newline between each property of an entry
            $c = $c | ForEach-Object {$_ -replace '","', "`",`n`""}

            # Add a newline between each entry in the JSON list
            $c = $c | ForEach-Object {$_ -replace '},{', "},`n{"}

            # Write back out to same path on disk
            $c | Out-File $dataPath -Force
        }
    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"   
}
<# End DecompressJSON #>

function DecompressGZ {
<#
.SYNOPSIS
This function takes a path to a GZIP compressed file and outputs the decompressed data
#>
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$True,Position=0,ValueFromPipeline=$true)]
        [string]$inData,
    [Parameter(Mandatory=$True,Position=1)]
        [string]$outFile,
    [Parameter(Mandatory=$False,Position=2)]
        [string]$fileExt
)
   Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    if ($fileExt){
        $outFile = $outFile + ".$fileExt"
    }

    Try { 
        Write-Verbose "Opening file stream for $inData"
        $inStrm = New-Object System.IO.FileStream $inData, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
        $inStrm.Seek(0,0) | Out-Null
        $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)

        # Create new GZipStream in decompress mode
        $GZipStream = New-object -TypeName System.IO.Compression.GZipStream -ArgumentList $inStrm, ([System.IO.Compression.CompressionMode]::Decompress)

        $buffer = New-Object byte[](1024)
        while($true){
            $read = $gzipstream.Read($buffer, 0, 1024)
            if ($read -le 0){break}
            $output.Write($buffer, 0, $read)
        }

        # Close the stream objects
        $gzipStream.Close()
        $output.Close()
        $inStrm.Close()

    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)" 
}
<# End DecompressGZ #>

function Parse-GPResult {
<#
.SYNOPSIS
This function performs custom parsing on the output of the GPResult module
#>
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        $rawDataPaths
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    Try { 
        foreach ($dataPath in $rawDataPaths){

        # Read raw script output
        $c = get-content $dataPath
        
        # convert to PSObject array
        $converted = $c | convertFrom-JSON

        # second item in array contains B64 encoded gzip
        $encodedGPR = $converted.GPResultB64GZ

        # decode gzip to byte array
        $rawGPR = [System.Convert]::FromBase64String($encodedGPR)

        # Set path for compressed file
        $splitPath = $dataPath.Split("\")
        $relativePath = ""
        for ($i=0; $i -lt ($splitPath.Length-1); $i++){$relativePath += $splitPath.Get($i)+"`\"}
        $fileName = $splitPath.Get($splitPath.Length-1)
        $fileName = $fileName.Split(".")[0]
        $gzip = ("$relativePath" + "$fileName" + ".gz")
        $outFile = ("$relativePath" + "$fileName")

        # Export decoded, compressed gzip to file
        [io.file]::WriteAllBytes("$gzip", $rawGPR)

        # Decompress the file
        DecompressGZ $gzip $outFile "XML"

        # Clean up old JSON file
        Remove-Item -Path $dataPath
        }

    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}
<# End Parse-GPResult #>

function Parse-Autoruns {
<#
.SYNOPSIS
This function performs custom parsing on the output of the Autoruns module
#>
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        $rawDataPaths
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    Try { 
        foreach ($dataPath in $rawDataPaths){

        # Read raw script output
        $c = get-content $dataPath | ConvertFrom-Csv

        # Convert to JSON
        $c = $c | ConvertTo-Json -Compress

        # Remove extra spaces
        $c = $c -replace '\\u0000', ""

        # Convert back to psobject for de-duplication
        $jsonc = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $jsonc.MaxJsonLength = [System.Int32]::MaxValue
        $jsonc.RecursionLimit = 99
        $c = $jsonc.DeserializeObject($c)
        #$c = $c | ConvertFrom-Json

        # New collection for final results
        $cleanDataColl = New-Object System.Collections.ArrayList

        # Only add good entries to new collection
        for ($i=0; $i -lt $c.Count; $i++){
            if(($c[$i].'Entry Location' -ne "") -and ($c[$i].enabled -ne "")){
                [void]$cleanDataColl.Add($c[$i])
            }
        }

        # Convert clean collection back to JSON
        $cleanData = $cleanDataColl | ConvertTo-Json -Compress
        $cleanData2 = $cleanDataColl | ConvertTo-Csv

        # Set path for output file
        $splitPath = $dataPath.Split("\")
        $relativePath = ""
        for ($i=0; $i -lt ($splitPath.Length-1); $i++){$relativePath += $splitPath.Get($i)+"`\"}
        $fileName = $splitPath.Get($splitPath.Length-1)
        $fileName = $fileName.Split(".")[0]
        $outFile = ("$relativePath" + "$fileName" + ".json")
        $outFile2 = ("$relativePath" + "$fileName" + ".csv")

        # Write file
        $cleanData | Out-File -Force $outFile
        $cleanData2 | Export-Csv -Path $outFile2

        # Clean up old JSON file
        Remove-Item -Path $dataPath
        }

    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}
<# End Parse-Autoruns #>

function Parse-GetProx {
<#
.SYNOPSIS
This function performs custom parsing on the output of the Get-Prox module
#>
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        $rawDataPaths
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    Try { 
        foreach ($dataPath in $rawDataPaths){

        # Read raw script output
        $c = get-content $dataPath | ConvertFrom-Csv
        
        # Convert to JSON
        $c = $c | ConvertTo-Json -Compress

        # Set path for output file
        $splitPath = $dataPath.Split("\")
        $relativePath = ""
        for ($i=0; $i -lt ($splitPath.Length-1); $i++){$relativePath += $splitPath.Get($i)+"`\"}
        $fileName = $splitPath.Get($splitPath.Length-1)
        $fileName = $fileName.Split(".")[0]
        $outFile = ("$relativePath" + "$fileName" + ".json")
        
        # Write out JSON file
        $c | Out-File -Force $outFile

        # Clean up old CSV file
        Remove-Item -Path $dataPath
        }

    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}
<# End Parse-GetProx #>

function Parse-GetProcdump {
<#
.SYNOPSIS
This function performs custom parsing on the output of the Get-Procdump module
#>
Param(
    [Parameter(Mandatory=$true,Position=0,ValueFromPipeline=$true)]
        $rawDataPaths
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    Try { 
        foreach ($dataPath in $rawDataPaths){

        # Read raw script output
        $c = get-content $dataPath

        # Convert back to psobject
        $jsonc = New-Object System.Web.Script.Serialization.JavaScriptSerializer
        $jsonc.MaxJsonLength = [System.Int32]::MaxValue
        $jsonc.RecursionLimit = 99
        $converted = $jsonc.DeserializeObject($c)

        # second item in array contains B64 encoded gzip
        $encodedFile = $converted.Base64EncodedGzippedBytes

        # decode gzip to byte array
        $rawFile = [System.Convert]::FromBase64String($encodedFile)

        # Set path for compressed file
        $splitPath = $dataPath.Split("\")
        $relativePath = ""
        for ($i=0; $i -lt ($splitPath.Length-1); $i++){$relativePath += $splitPath.Get($i)+"`\"}
        $fileName = $splitPath.Get($splitPath.Length-1)
        $fileName = $fileName.Split(".")[0]
        $gzip = ("$relativePath" + "$fileName" + ".gz")
        $outFile = ("$relativePath" + "$fileName")

        # Export decoded, compressed gzip to file
        [io.file]::WriteAllBytes("$gzip", $rawFile)

        # Decompress the file
        DecompressGZ $gzip $outFile "DMP"

        # Clean up old JSON file
        Remove-Item -Path $dataPath
        }

    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}
<# End Parse-GetProcdump #>
