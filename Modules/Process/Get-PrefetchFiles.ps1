<#
.SYNOPSIS
Acquires copies of prefetch files, if enabled, copying them
to a zip file. The zip file is then encoded and returned as a powershell object. 
.NOTES
The output of this script needs to be processed by the Deserialize-KansaField.ps1 script.
Example:
Deserialize-KansaField.ps1 -InputFile .\COMPUTERNAME-PrefetchFiles.csv -Field Content -OutputFile PrefetchFiles.zip
#>

function GetBase64GzippedStream {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [System.IO.FileInfo]$File
)
    # Read profile into memory stream
    $memFile = New-Object System.IO.MemoryStream (,[System.IO.File]::ReadAllBytes($File))
        
    # Create an empty memory stream to store our GZipped bytes in
    $memStrm = New-Object System.IO.MemoryStream

    # Create a GZipStream with $memStrm as its underlying storage
    $gzStrm  = New-Object System.IO.Compression.GZipStream $memStrm, ([System.IO.Compression.CompressionMode]::Compress)

    # Pass $memFile's bytes through the GZipstream into the $memStrm
    $gzStrm.Write($memFile.ToArray(), 0, $File.Length)
    $gzStrm.Close()
    $gzStrm.Dispose()

    # Return Base64 Encoded GZipped stream
    [System.Convert]::ToBase64String($memStrm.ToArray())   
}

function add-zip
{
    param([string]$zipfilename)

    if (-not (Test-Path($zipfilename))) {
        Set-Content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (dir $zipfilename).IsReadOnly = $false
    }

    $shellApplication = New-Object -com shell.application
    $zipPackage = $shellApplication.NameSpace($zipfilename)

    foreach($file in $input) {
        $zipPackage.CopyHere($file.FullName)
        Start-Sleep -milliseconds 100
    }
}

$pfconf = (Get-ItemProperty "hklm:\system\currentcontrolset\control\session manager\memory management\prefetchparameters").EnablePrefetcher 
Switch -Regex ($pfconf) {
    "[1-3]" {
        $zipfile = (($env:TEMP) + "\" + ($env:COMPUTERNAME) + "-PrefetchFiles.zip")
        if (Test-Path $zipfile) { rm $zipfile -Force }
        ls $env:windir\Prefetch\*.pf | add-zip $zipfile
        
        #Reuse code from get-file.ps1 to encode the zip file. 
        $obj = "" | Select-Object FullName,Length,CreationTimeUtc,LastAccessTimeUtc,LastWriteTimeUtc,Content
        $Target = ls $zipfile
        $obj.FullName          = $Target.FullName
        $obj.Length            = $Target.Length
        $obj.CreationTimeUtc   = $Target.CreationTimeUtc
        $obj.LastAccessTimeUtc = $Target.LastAccessTimeUtc
        $obj.LastWriteTimeUtc  = $Target.LastWriteTimeUtc
        $obj.Content           = GetBase64GzippedStream($Target)
        $obj
        $suppress = Remove-Item $zipfile
    }
    default {
    # No Prefetch files, nothing to do, nothing to return
    }
}
