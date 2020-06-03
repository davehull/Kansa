# This module is designed to crawl the filesystem and identify any MS Office documents with Dynamic
# Data Exchange (DDE) functionality. When the "feature" was discovered by sensepost researchers in
# late 2017 we wrote this module to see 1) if any legitimate documents used this feature so we could
# weigh the risk of disabling it, and 2) determine if any weaponized DDE MSOffice docs had been sent
# to our users before perimeter defenses were in place. It looks for IOCs detailed in the Sensepost
# Blog.  https://sensepost.com/blog/2017/macro-less-code-exec-in-msword/
# https://github.com/Neo23x0/signature-base/blob/master/yara/gen_dde_in_office_docs.yar
# Warning! Since this code crawls the entire filesystem and inspects all Word/Excel documents it
# runs very slowly.  The yara rules also produce many false-positives

#$Files = New-Object -TypeName System.Collections.ArrayList 
$extRegex = [regex]'\.(doc|docx|xls|xlsx)$'
$DDElegacyWDregex = [regex]'(?i)\x13\s*(DDE|DDEAUTO)\b[^\x14]+'
$DDElegacyXLregex = [regex]'\x01.\x00{3}.\x00{2}[A-Za-z]+\x03'
$DDEopenXMLWDregex = [regex]'(?i)="\s*\b(DDE|DDEAUTO)\b.+;\s*">'
$DDEopenXMLWDregex2 = [regex]'(?i)<w:instrText.*>\s*\b(DDE|DDEAUTO)\b.*</w:instrText>'
$DDEopenXMLXLregex = [regex]'(?i)<ddeLink\b'
#$legacyXLRE1 = [regex]'\xAE\x01.\x00{3}.\x00{2}[A-Za-z]+\x03' #PS can only do hex regex of \xdd where d=digit, so \xAE will never match the bytestream...not designed to regex against byte streams/arrays
#$legacyXLRE1 = [regex]'xAEx01x[0-9A-F]{2}(x00){3}x[0-9A-F]{2}(x00){2}(x[4-7][0-9A-F])+x03' #used if byte array is converted into paddedByte string

$files = enhancedGCI -startPath "$env:SystemDrive\" -extensions @("*.doc", "*.docx", "*.xls", "*.xlsx")
#gci -File -Path 'C:\' -Recurse -Force -ErrorAction SilentlyContinue -Attributes !ReparsePoint | ? -FilterScript {($_.Extension -match $extRegex)} |% { [void]$Files.Add($_.FullName) }
#  -not ($_.Attributes -match "Reparsepoint")  # need to stop gci from recursive loops ie appdata\appdata\appdata

Add-Type -Assembly System.IO.Compression.FileSystem

foreach ($file in $files) {
    
	if ((Test-Path -LiteralPath $file -PathType Leaf) -and (-not($file.split('\')[-1]).startswith('~$'))) {
        $myfile = gi -Force -LiteralPath $file
        if ( $myfile.Length -lt 30000000 ) { 
            $DDEresult = "No DDE"
            #write-host $myfile.FullName
            if ($myfile.Extension -eq '.docx') {
                $zip = [IO.Compression.ZipFile]::OpenRead($file)
                $doc = $zip.Entries | where FullName -like 'word/document.xml'
                $stream = $doc.Open()
                $reader = New-Object IO.StreamReader($stream)
                $XML = $reader.ReadToEnd()
                $stream.Close()
                $reader.Close()
                $tempresult = $XML -match "$DDEopenXMLWDregex|$DDEopenXMLWDregex2"
                if ($tempresult) { 
                    $DDEresult = "Contains DDE Fields" 
                }
            } ElseIf ($myfile.Extension -eq '.doc') {
                $stream = $myfile.OpenRead()
                $reader = New-Object IO.StreamReader($stream)
                $data = $reader.ReadToEnd()
                $stream.Close()
                $reader.Close()
                $tempresult = $data | Select-String -Pattern $DDElegacyWDregex
                if ($tempresult) { 
                    $DDEresult = "Contains DDE Fields" 
                }
            } ElseIf ($myfile.Extension -eq '.xlsx') {
                $zip = [IO.Compression.ZipFile]::OpenRead($file)
                $doc = $zip.Entries | where FullName -like "xl/externalLinks/externalLink1.xml"
                $XML = $null
                if ($doc -ne $null) {
                    $stream = $doc.Open()
                    $reader = New-Object IO.StreamReader($stream)
                    $XML = $reader.ReadToEnd()
                    $stream.Close()
                    $reader.Close()
                }
                $tempresult = $XML -match $DDEopenXMLXLregex 
                if ($tempresult) { 
                    $DDEresult = "Contains DDE Fields" 
                }
            } ElseIf ($myfile.Extension -eq '.xls') {
                $stream = $myfile.OpenRead()
                $reader = New-Object IO.StreamReader($stream)
                $data = $reader.ReadToEnd()
                $stream.Close()
                $reader.Close()
                $tempresult = $data -match $DDElegacyXLregex
                if ($tempresult) { 
                    $DDEresult = "Contains DDE Fields" 
                }
            }
            $result = @{}
            $result.add("DDE", $DDEresult)
            $result.add("ExtensionRegEx", "$extRegex")
            $result.add("Filename", "$($file.Split('\')[-1])")
            $result.add("Filepath", "$($myfile.Fullname)")
            $result.add("Filesize", $myfile.Length)
            $result.add("LastWriteTime", "$($myfile.LastWriteTime)")
            Add-Result -hashtbl $result
        }
        else{
			$myfile = gi $file
            $result = @{}
            $result.add("DDE", "Files over 30MB not scanned")
            $result.add("ExtensionRegEx", "$extRegex")
            $result.add("Filename", "$($file.Split('\')[-1])")
            $result.add("Filepath", "$($myfile.Fullname)")
            $result.add("Filesize", $myfile.Length)
            $result.add("LastWriteTime", "$($myfile.LastWriteTime)")
            Add-Result -hashtbl $result
        }
	}
}
