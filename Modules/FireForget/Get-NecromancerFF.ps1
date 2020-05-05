# The Necromancer module is designed to analyze non-running (dead) executables to look for suspicious
# binaries that are not currently running or potentially have never run like a long-game backdoor/RAT
# The module recurses the whole drive to find all files matching desired criteria and then gathering
# all applicable metadata about the files. Finally the binaries will be uploaded to a central
# repository where they can be run through a malware-analysis pipline to further enrich the records.
# The module can pull down a whitelist of binaries by hash or digitally-signed thumbprint. Binaries
# that match the whitelist will still have their metadata analyszed and collected to ID all endpoints
# where they are present, but the module will NOT attempt to upload whitelisted binaries for further
# analysis.  This is done to minimize strain on network infrastructure/bandwidth and the central
# repository servers.
if(!(Get-Variable -Name necroSvr -ErrorAction SilentlyContinue)){$necroSvr = "127.0.0.1"}
if(!(Get-Variable -Name necroPort -ErrorAction SilentlyContinue)){$necroPort = 80}
if(!(Get-Variable -Name searchFilter -ErrorAction SilentlyContinue)){$searchFilter = @('*.exe')}
if(!(Get-Variable -Name regFilter  -ErrorAction SilentlyContinue)){$regFilter = "\.(exe)$"}
if(!(Get-Variable -Name startPath -ErrorAction SilentlyContinue)){$startPath = "$env:SystemDrive\"}

if($necroSvr.GetType().Name -match "(array|\[\])"){$necroSvr = Get-Random -InputObject $necroSvr}
if($necroPort.GetType().Name -match "(array|\[\])"){$necroPort = Get-Random -InputObject $necroPort}
#future development: pull down sigcheck, densityscout, pescan and run them on files not on the whitelist
#add ability to look at ALL files and select files by magic-bytes for deeper analysis rather than just extensions


$killDelayMin = [Int](($killDelay + 600) / 60) # add 10min wiggleroom
$urlBinUpload = "http://$necroSvr"+':'+"$necroPort/ul" #REST endpoint to push unknown binaries to server
$urlWLDownload = "http://$necroSvr"+':'+"$necroPort/wl?killswitch=$killDelayMin" #download 'whitelist' of known-good/already-inspected files
$urlFinFlag = "http://$necroSvr"+':'+"$necroPort/fin" #REST endpoint to signal scan completion for temp suppressions
#$searchFilter = @('*.exe', '*.dll', '*.com', '*.sys', '*.msi', '*.bin', '*.scr') #good targetlist of PE extensions
#$startPath "C:\Users" #to narrow the scope and reduce strain on endpoints, optionally focus on PE files in the user profiles
#consider trying cmd /c 'dir /b/s/a .\* | findstr /i /r "\.exe$ \.dll$"' #...can't due to recursive infinite-loop bug
$Global:WMIProcess = (Get-WmiObject -query 'Select * from win32_process' | Select ExecutablePath).ExecutablePath

$hashKnown = @{}
$certKnown = @{}
$unknown = @{}

$whitelist = [char[]](Invoke-WebRequest $urlWLDownload | Select-Object -ExpandProperty Content) -join "" | convertfrom-csv -header hash,thumb
if ($whitelist){
    $whitelist | % { 
        if($_.hash -ne $null -and $_.hash -ne "") {$hashKnown[$_.hash]="Known"}
        if($_.thumb -ne $null -and $_.thumb -ne "") {$certKnown[$_.thumb]="Known"}
    }
}
$whitelist = $null
[System.GC]::Collect()

# Although a native powershell Get-FileHash cmdlet exists, it is more efficient to read all the bytes once
# and generate multiple hashes than to run that cmdlet 3x.
function Compute-3Hashes {
Param(
    [Parameter(Mandatory = $true, Position=1)]
    [string]$FilePath
)
    
    $hashMD5 = [System.Security.Cryptography.MD5]::Create()
    $hashSHA1 = [System.Security.Cryptography.SHA1]::Create()
    $hashSHA256 = [System.Security.Cryptography.SHA256]::Create()

    if (Test-Path $FilePath) {
        $FileName = Get-ChildItem -Force -File -LiteralPath $FilePath | Select-Object -ExpandProperty Fullname
        $fileData = [System.IO.File]::ReadAllBytes($FileName)

        $StringBuilder = New-Object System.Text.StringBuilder
        $hashMD5.ComputeHash($fileData) | %{[void]$StringBuilder.Append($_.ToString('x2'))}
        $strMD5hash = $StringBuilder.ToString()
        $StringBuilder = New-Object System.Text.StringBuilder
        $hashSHA1.ComputeHash($fileData) | %{[void]$StringBuilder.Append($_.ToString('x2'))}
        $strSHA1hash = $StringBuilder.ToString() 
        $StringBuilder = New-Object System.Text.StringBuilder
        $hashSHA256.ComputeHash($fileData) | %{[void]$StringBuilder.Append($_.ToString('x2'))}
        $strSHA256hash = $StringBuilder.ToString()
        
        $o = New-Object -TypeName psobject
        $o | Add-Member -MemberType NoteProperty -Name 'MD5' -Value $strMD5hash
        $o | Add-Member -MemberType NoteProperty -Name 'SHA1' -Value $strSHA1hash
        $o | Add-Member -MemberType NoteProperty -Name 'SHA256' -Value $strSHA256hash
        return $o        
    } else {
        #do nothing
    }
}

# Inaddition to gathering normal metadata via the Get-FileDetails helper function in the FFwrapper, we need to get information
# about authenticode signed binaries. Parsing the authenticode data is painful due to overlapping signer/stamper value names
function Get-FileDetailsPE{
Param([String]$filename)
    if (Test-Path $filename) {
        
        $r = @{}
        $r =  Get-FileDetails -hashtbl $r -filepath $filename -getMagicBytes 4 #-computeHash -algorithm @("MD5","SHA256")
        $running = $false
        if(($r) -and ($r.ContainsKey("FileFullName")) -and ($Global:WMIProcess -contains $r.FileFullName)){ $running = $true }        
        $r.add("Running",$running)
        
        $signature = Get-AuthenticodeSignature $filename | Select Status,SignerCertificate,TimeStamperCertificate
        $r.add("Signature",$(($signature.Status).ToString()))
        if ($signature.SignerCertificate -ne $Null) {
            $tmp = $signature.SignerCertificate | Select Subject,Issuer,Version,Thumbprint,SerialNumber,HasPrivateKey,NotBefore,NotAfter
            $tmp.psobject.properties | % {
                $theName = ''
                $theValue = ''
                if ($_.Name -match '(Issuer|Subject)'){
                    $str = $_
                    $obj = $str.Value -Split ',(?=(?:[^"]*"[^"]*")*[^"]*$)' | %{ $_ | ConvertFrom-StringData} | sort Keys
                    $i = 2
                    $pad = ''
                    foreach ($element in $obj) {
                        $theName = $('SignerCertificate.'+$str.Name+'.'+($element.Keys).Trim())
                        $theValue = ($element.Values).Trim()
                        if ($r.ContainsKey($theName)){
                            $theName = $theName + [String]$i
                            $i++
                        } else {
                            $i = 2
                        }
                        $r.add($theName,$theValue)
                    }
                } else {
                    $theName = $('SignerCertificate.'+$_.Name)
                    $theValue = $_.Value.ToString()
                    $r.add($theName,$theValue)
                }                
            }
        }
        if ($signature.TimeStamperCertificate -ne $Null) {
            $tmp = $signature.TimeStamperCertificate | Select Subject,Issuer,Version,Thumbprint,SerialNumber,HasPrivateKey,NotBefore,NotAfter
            $tmp.psobject.properties | % {
                $theName = ''
                $theValue = ''
                if ($_.Name -match '(Issuer|Subject)'){
                    $str = $_
                    $obj = $str.Value -Split ',(?=(?:[^"]*"[^"]*")*[^"]*$)' | %{ $_ | ConvertFrom-StringData} | sort Keys
                    $i = 2
                    $pad = ''
                    foreach ($element in $obj) {
                        $theName = $('StamperCertificate.'+$str.Name+'.'+($element.Keys).Trim())
                        $theValue = ($element.Values).Trim()
                        if ($r.ContainsKey($theName)){
                            $theName = $theName + [String]$i
                            $i++
                        } else {
                            $i = 2
                        }
                        $r.add($theName,$theValue)
                    }
                } else {
                    $theName = $('StamperCertificate.'+$_.Name)
                    $theValue = $_.Value.ToString()
                    $r.add($theName,$theValue)
                }
            }
        }
        $hashes = Compute-3Hashes -FilePath $filename
        $r.add("MD5",$hashes.MD5)
        $r.add("SHA1",$hashes.SHA1)
        $r.add("SHA256",$hashes.SHA256)

        #if(($r.GetType()).name -eq 'PSCustomObject'){
        #    $tmp = @{}
        #    foreach( $property in $r.psobject.properties.name ){
        #        $tmp[$property] = $r.$property
        #    }
        #    $r = $tmp
        #}

        #Set disposition based on whether this file is on the whitelist
        if( ($r.ContainsKey('StamperCertificate.Thumbprint')) -and ($certKnown.ContainsKey($r.'StamperCertificate.Thumbprint')) ){
            $r.add("Disposition","Known Code Signing Cert")
        } elseif ($hashKnown.ContainsKey($r.SHA256)){
            $r.add("Disposition","Known File Hash")
        } elseif ($unknown.ContainsKey($r.SHA256)) {
            $r.add("Disposition","Unknown")
        } else {
            $unknown.add($r.SHA256, $r.Fullname)
            $r.add("Disposition","Unknown")
        }

        # Attempt to upload all "Unknown" files to a central repository for further analysis
        # Temporarily do not attempt to upload files without the MZ header and at least 4 bytes long
        $uploadStatus = "Failed"
        $retries = 1
        if(($r.Disposition -eq "Unknown") -and ($r.FileLength -ge 4) -and ($r.FileMagicBytesASCII -match "MZ")){
            $status = Send-File -localFilePath $r.FileFullName -remoteFilename $r.SHA256 -url $urlBinUpload
            if($status[1] -eq 200) {
                $uploadStatus = "Successful"
            } else {
                while(($status[1] -ne 200) -and ($retries -lt 3)){
                    Start-Sleep -s $retries
                    $status = Send-File -localFilePath $r.FileFullName -remoteFilename $r.SHA256 -url $urlBinUpload
                    if($status[1] -eq 200){$uploadStatus = "Successful";break}
                    $retries += 1
                }
            }
        } else {
            $uploadStatus = "NotAttempted"
        }
        $r.add("UploadStatus",$uploadStatus)
        $r.add("UploadAttempts",$retries)
        Add-Result -hashtbl $r
    } 
}

$files = enhancedGCI -startPath $startPath -extensions $searchFilter -regex $regFilter
foreach ($file in $files){
    Get-FileDetailsPE -filename $file
}

$result = @{}
$result.add("KnownHashes",$hashKnown.Count)
$result.add("KnownCerts",$certKnown.Count)
$result.add("QueryExtension",$searchFilter)
$result.add("QueryRegexn",$regFilter)
$result.add("UnknownHashes",$unknown.Count)
$result.add("NecroServer",$necroSvr)
$result.add("NecroPort",$necroPort)
Add-Result -hashtbl $result

$response = Invoke-WebRequest $urlFinFlag #this Get-request will signal that the scan is complete so the box can be un-whitelisted in SOAR platform

#TODO: 
# error handling to catch exception when rest endpoint is busy, check for status code too
# Build Whitelist from NSRL, Microsoft, and RL Trustfactor of 0 with evil of 0
