<# 
.SYNOPSIS
Decompress-KansaOutputFile decompress and create files for CSV created by kansa for scripts:Get-Recent,Get-OfficeTrustedRecords,Get-File and any script that based on Get-file.ps1

.DESCRIPTION
Decompress-KansaOutputFile decompress and create files for CSV created by kansa for scripts:Get-Recent,Get-OfficeTrustedRecords,Get-File and any script that based on Get-file.ps1

.PARAMETER InputFile
CSV file that contains the compressed data

.PARAMETER OutputDirectory
Directory to write files
.EXAMPLE
Get-Recent.ps1

.NOTES
it's not aim to run in kansa, but after kansa reterives the csv file
*Don't forget to import the module first : Import-Module ./Decompress-KansaFileOutput*

.EXAMPLE
Decompress-KansaFileOutput -InputFile "G:\Kansa\Output_20200129135810\Recent2\192.168.1.7-Recent2.csv" -OutputDirectory "G:\Kansa\Output_20200129135810\Recent2"
*Don't forget to import the module first : Import-Module ./Decompress-KansaFileOutput*

#>
function Decompress-KansaOutputFile{

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,Position=0)]
            [string]$InputFile,
        [Parameter(Mandatory=$False,Position=1)]
            [string]$OutputDirectory
    )
    process
    {
        if($OutputDirectory[-1] -notlike "\")
        {
             $OutputDirectory = $OutputDirectory + "\"

        }
        $Files =@()
        $Files += Import-Csv $InputFile

        foreach($file in $Files)
        {

            $database64 = $file.content
            $UserName= $file.Username
            
            $byteArray = [System.Convert]::FromBase64String($database64)
            $input = New-Object System.IO.MemoryStream( , $byteArray )
	        $output = New-Object System.IO.MemoryStream
            $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)
	        $gzipStream.CopyTo( $output )
            $gzipStream.Close()
		    $input.Close()
		    [byte[]] $byteOutArray = $output.ToArray()
            $DirPath = $OutputDirectory + "$UserName\"
            if(-not (Test-Path $DirPath))
            {
                New-Item -ItemType Directory -Path $DirPath | Out-Null
            }

            $Path = $DirPath + $file.BaseName
            $byteOutArray | Set-Content -Path $Path -Encoding Byte 

            
        }
    }
}