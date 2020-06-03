# This module is used to recursively find all alternate datastreams in a given path to identify outliers
# It will also attempt to collect the content of the ADS and ship it to ELK so you can disposition it 
# there without having to reach back out to the target workstation to make a determination

if(!(Get-Variable -Name startPath -ErrorAction SilentlyContinue)){$startPath = "C:\Users"}
if(!(Get-Variable -Name fileExtensions -ErrorAction SilentlyContinue)){$fileExtensions = "*"}
if(!(Get-Variable -Name filePattern -ErrorAction SilentlyContinue)){$filePattern = "."}

$ErrorActionPreference = "SilentlyContinue"

# Variation on the recursive Get-FileDetails helper function that focuses on finding all alternate datastreams
# in a given filesystem tree
function findStreams{
    Param([String]$startPath,[String]$regex,[String[]]$extensions)
    if ($startPath -like '*\AppData\Local\Box*'){
        Return
    }
    try{
        foreach ($extension in $extensions){
            $firstPass = [IO.Directory]::EnumerateFiles($startPath, $extension)
            $firstPass | where-object {$_ -Match $regex} | %{ gi -force -LiteralPath $_ -Stream * | Where Stream -NotMatch ':\$DATA' | Select FileName,Stream,Length }
        }
        [IO.Directory]::EnumerateDirectories($startPath) | % { 
            if ([IO.File]::GetAttributes($_) -NotLike '*ReparsePoint*'){
                findStreams -startPath $_ -regex $regex -extensions $extensions
            }
        }
    } catch {
    }
}

$streams = findStreams -startPath $startPath -extensions $fileExtensions -regex $filePattern
foreach($strm in $streams){
    $result = Get-FileDetails -filepath $strm.FileName -computeHash -algorithm @("MD5","SHA256")
    $result.add("StreamName",$strm.Stream)
    $result.add("StreamSize",$strm.Length)
    $content = gc -raw -LiteralPath $strm.FileName -Stream $strm.Stream
    if($strm.Length -lt 10000){
        $result.add("StreamContent",$content)
    } else {
        $result.add("StreamContent","Alternate Data Stream is greater than 10K") 
        $result.add("StreamContentTruncated",$content.Substring(0,9999))
    }
    $adscontent = gc -raw $strm.FileName -Stream $strm.Stream -Encoding Byte
    $adsstream = New-Object -TypeName 'System.IO.MemoryStream' -ArgumentList (,$adscontent)
    $streamMD5 = Get-FileHash -InputStream $adsstream -Algorithm MD5
    $result.add("StreamMD5", $streamMD5.Hash)
    Add-Result -hashtbl $result
    $content = $null
    $adscontent = $null
    $adsstream = $null
    [System.GC]::Collect()
}
