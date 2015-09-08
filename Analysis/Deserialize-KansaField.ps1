<# 
.SYNOPSIS
Deserialize-KansaField.ps1 "rehydrates" Kansa collected data enabling
further analysis.
.DESCRIPTION
During data collection with Kansa, binary objects, files, compressed
files, memory dumps and the like are GZipped, Base64 encoded and stored
as object properties, then returned as part of the object output to the
host Kansa was run from. (Note: ended previous sentence in preposition.
Don't care)
In order to analyze the binary blobs, they must be deserialized. This
script will do that for you. Point it at a Kansa output file, give it
the name of the field containing the serialized data and it will Base64
decode it, decompress it and save it to a file of your choosing, then
you can analyze it further with tools of your choice.
.PARAMETER InputFile
A required parameter, the name of the input file containing the field
that should be deserialized.
.PARAMETER Format
An optional parameter specifying the InputFile type where type is one
of CSV, JSON, TSV or XML.
.PARAMETER Field
A required parameter, the name of the field containing the data that 
should be rehydrated.
.PARAMETER OutputFile
A required parameter, the name of the file where the deserialized data
will be written.
.EXAMPLE
Deserialize-kansaField.ps1 -Inputfile <infilename> -Field <fieldname> -OutputFile <outfilename>
.NOTE
Special thanks to Matt for assistance with this!
#>


[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$InputFile,
    [Parameter(Mandatory=$False,Position=1)]
    [ValidateSet("CSV","JSON","TSV","XML")]
        [String]$Format="CSV",
    [Parameter(Mandatory=$True,Position=2)]
        [String]$Field,
    [Parameter(Mandatory=$True,Position=3)]
        [String]$OutputFile,
    [Parameter(Mandatory=$False,Position=4)]
        [switch]$Force
)

function GetTimestampUTC {
    Get-Date (Get-Date).ToUniversalTime() -Format "yyyy-MM-ddTHH:mm:ssZ"
}

function ConvertBase64-ToByte {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$base64String
)
    # Takes a Base64 encoded string and returns a byte array
    # Example: ConvertBase64-ToByte -base64String "AAAB"
    # Returns: @(0,0,1)
    Try {
        $Error.Clear()
        [System.Convert]::FromBase64String($base64String)
    } Catch {
        Write-Error ("Input string or file does not match Base64 encoding. Quitting.")
        exit
    }
}

$ErrorActionPreference = "SilentlyContinue"
if ($InPath = Resolve-Path $InputFile) {
    if ((Resolve-Path $OutputFile) -and (-not $Force)) {
        # Check that output file doesn't exist or -Force was used
        Write-Error ("{0}: Output file already exists. Remove it and try again or add -Force. Quitting." -f (GetTimestampUTC))
        Exit
    } else {
        # Either the output file does not exist or -Force was used

        $Suppress = New-Item -Path $OutputFile -ItemType File
        $OutputFile = ls $OutputFile

        switch ($Format) {
            # $Format dictates how we'll read the file
            "CSV" {
                $data = Import-Csv $InPath
            }
            "JSON" {
                $data = Get-Content -Raw -Path $InPath | ConvertFrom-Json
            }
            "TSV" {
                $data = Import-Csv -Delimiter "`t" -Path $InPath
            }
            "XML" {
                $data = Import-Clixml -Path $InPath
            }
            default {
                Write-Error ("{0}: Invalid or unsupported input format. Input file must be on of CSV, JSON, TSV or XML. Quitting." -f (GetTimestampUTC))
                Exit
            }
        }

        # Find the field
        if (-not $data.$Field) {
            Write-Error ("{0}: Could not find the specified field name, {1} in the input file. Check the data and try again. Quitting." -f (GetTimestampUTC), $Field)
            Exit
        } else {
            # Base64 decode the field into a byte array
            $CompressedByteArray = [byte[]](ConvertBase64-ToByte -base64String $data.$Field)

            # Create a memory stream to store compressed data
            $CompressedByteStream = New-Object System.IO.MemoryStream(@(,$CompressedByteArray))

            # Create an empty memory stream to store decompressed data
            $DecompressedStream = new-object -TypeName System.IO.MemoryStream

            # Decompress the memory stream
            $StreamDecompressor = New-Object System.IO.Compression.GZipStream $CompressedByteStream, ([System.IO.Compression.CompressionMode]::Decompress)

            # And copy decompressed bytes to $DecompressedStream
            $StreamDecompressor.CopyTo($DecompressedStream)

            # Write the bytes to disk
            [System.IO.File]::WriteAllBytes($OutputFile, $DecompressedStream.ToArray())

            $StreamDecompressor.Close()
            $CompressedByteStream.Close()
            Write-Verbose("Done.")
        }
    }
} else {
    Write-Error ("{0}: Could not resolve path to -InputFile argument {1}. Check the argument and try again, maybe. Quitting." -f (GetTimestampUTC), $InputFile)
    exit
}