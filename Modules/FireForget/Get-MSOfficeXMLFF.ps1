# This module was born out of a request from our incident response team to look for a suspicious Office document.
# The filename and hash of the office document changed on every endpoint, but the metadata in the Office XML had
# some common markers such as the author and date created etc... embedded in the XML.  So this module can get a
# list of all office documents on a system or in a specific path and then use native powershell compression
# libraries to open the document like a zip folder in RAM and look at the xml subcomponents for a particular 
# regex that is the unique signature for a given document.  You can also optionally upload the file sample to a
# contral collection server or delete the file.

if(!(Get-Variable -Name necroSvr -ErrorAction SilentlyContinue)){$necroSvr = @("127.0.0.1")} # File server using REST API for uploading files found
if(!(Get-Variable -Name necroPort -ErrorAction SilentlyContinue)){$necroPort = @(80)} # port used by the REST-API server
if(!(Get-Variable -Name deleteDoc -ErrorAction SilentlyContinue)){$deleteDoc = $false} # Pass in a $true value for this parameter to tell the module to delete any copies of files that match your criteria #WARNING #DANGER be sure your regex patterns are very specific before you delete all the Office docs.  You'll be more secure but your users will become agitated
if(!(Get-Variable -Name uploadDoc -ErrorAction SilentlyContinue)){$uploadDoc = $false} # Pass in a $true value if you want to collect
if(!(Get-Variable -Name stringPattern -ErrorAction SilentlyContinue)){$stringPattern = "unique regex string in XML"} # regex pattern that you want to search INSIDE of the office XML components
if(!(Get-Variable -Name FilePattern -ErrorAction SilentlyContinue)){$FilePattern = ""} # specify the filename pattern of Office documents that contain the string you are searching for in the filesystem
if(!(Get-Variable -Name FileExtensions -ErrorAction SilentlyContinue)){$FileExtensions = @("*.docx", "*.docm", "*.dotx", "*.dotm", "*.xlsx", "*.xlsm", "*.xltx", "*.xltmm", "*.pptx", "*.pptm", "*.potx", "*.potm")} # focus your search on specific Office file extensions
if(!(Get-Variable -Name FileStartPath -ErrorAction SilentlyContinue)){$FileStartPath = ""} # Specify the top level folder from which the module will recurse looking for files $env:SystemDrive\Users\ 
if(!(Get-Variable -Name XMLFilePattern -ErrorAction SilentlyContinue)){$XMLFilePattern = 'docProps/core.xml'} # Specify which XML document components/subparts inside of the XML document archive/zip contain the regex stringPattern you are looking for

$rndSvr = Get-Random -InputObject $necroSvr
$rndPort = Get-Random -InputObject $necroPort
$urlFileUpload = "http://$rndSvr"+':'+"$rndPort/ul"

$officeFiles = enhancedGCI -startPath $FileStartPath -extensions $FileExtensions -regex $FilePattern

Add-Type -Assembly System.IO.Compression.FileSystem

$found = $false

foreach($f in $officeFiles) {
    $zip = [IO.Compression.ZipFile]::Openread($f)
    $docs = $zip.Entries | where FullName -match $XMLFilePattern
    foreach ($doc in $docs){
        $stream = $doc.Open()
        $reader = New-Object IO.StreamReader($stream)
        $XML = $reader.ReadToEnd()
        $reader.Close()
        $stream.Close()
        $tempresult = $XML -match $stringPattern
        if ($tempresult) { 
            $found = $true 
            $result = @{}
            $result = Get-FileDetails -hashtbl $result -filepath $f -computeHash -algorithm @("MD5", "SHA256")
            $result.add("FileExists",$found)
            if($uploadDoc){
                Send-File -localFilePath $f -remoteFilename $result.FilehashSHA256 -url $urlFileUpload
            }            
            if($deleteDoc){
                $zip.Dispose()
                $XML = $null
                $doc = $null
                $docs = $null
                $zip = $null
                [System.GC]::Collect()
                Start-Sleep -Seconds 5
                Remove-Item -Force -LiteralPath $f
                $result.add("Deleted",$true)
                $exists = Test-Path -PathType Leaf -LiteralPath $f
                $result.add("ConfirmedDeletion",!$exists)
            }else{
                $result.add("Deleted",$false)
            }
            $result.Add("OfficeFilesInspected",$officeFiles.count)
            $LLOuser = Get-LLOuser
            $result.add("HostLastLoggedOnUser",$LLOuser.Name)
            $result.add("HostLastLoggedOnUserID",$LLOuser.UserID)
            $result.add("HostLastLoggedOnTitle",$LLOuser.Title)
            $result.add("HostLastLoggedOnDept",$LLOuser.Dept)
            $result.add("HostLastLoggedOnDiv",$LLOuser.Div)
            $result.add("HostLastLoggedOnDesc",$LLOuser.Desc)
            Add-Result -hashtbl $result
            if($deleteDoc){
                break
            }
        }
    }
    $zip.Dispose()
}

if(!$found){
    $result = @{}
    $result.Add("FileExists",$found)
    $result.Add("OfficeFilesInspected",$officeFiles.count)
    Add-Result -hashtbl $result
}
