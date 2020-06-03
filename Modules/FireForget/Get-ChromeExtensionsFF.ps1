# This module is designed to enumerate ALL installed chrome extensions for every user profile on a
# target system. Idenfifying known-malicious or low-frequency-of-occurrence extensions can help to
# find evil extensions or just help to baseline extensions across the environment. The module will
# perform web requests to resolve extension GUIDs to display-names and thus generate a massive 
# spike in web-traffic if invoked across hundreds of thousands of systems with even a few chrome
# extensions.

if(!(Get-Variable -Name tgtAppID -ErrorAction SilentlyContinue)){$tgtAppID = ".*"}
if(!(Get-Variable -Name startPath -ErrorAction SilentlyContinue)){$startPath = "C:\Users"}
if(!(Get-Variable -Name storeLookup -ErrorAction SilentlyContinue)){$storeLookup = $false}
if(!(Get-Variable -Name remove -ErrorAction SilentlyContinue)){$remove = $False}

if($remove -and ($tgtAppID -contains '*')){
    $remove = $false
}

$userdirs = Get-ChildItem $startPath
$tgtAppFound = $false

function GUIDLookup{
    param( [string]$GUID )

    $URI = 'https://chrome.google.com/webstore/detail/'
    $app_ID = $GUID

    $data = Invoke-WebRequest -Uri ($URI + $app_ID) | select Content
    $data = $data.Content
    # Regex which pulls the title from og:title meta property
    $title = [regex] '(?<=og:title" content=")([\S\s]*?)(?=">)' 
    $cuttitle = $title.Match($data).value.trim()
    return $cuttitle 
}

foreach ($dir in $userdirs){
    $chromePath = "$startPath\$($dir.Name)\AppData\Local\Google\Chrome\User Data\Default\Extensions"
    $chromeExists = Test-Path $chromePath
    
    if ($chromeExists){
        $dirListing = Get-ChildItem $chromePath
        foreach ($folder in $dirListing){
            if($folder.Name -notmatch $tgtAppID){
                #Do Nothing
            }else{
                $tgtAppFound = $true
                $version_folders = Get-ChildItem -Path "$($folder.FullName)"
                $writedate = [datetime](Get-ItemProperty -Path $chromePath\$folder\$version_folders -Name LastWriteTime).LastWriteTime            
                foreach ($version_folder in $version_folders) {
                    ##: The extension folder name is the app id in the Chrome web store
                    $appid = $folder.BaseName
                    ##: First check the manifest for a name
                    $name = ""
                    $launchfile = ""
                    $launchurl = ""
                    $background = ""
                    $version = ""
                    $updateurl = ""
                    if( (Test-Path -Path "$($version_folder.FullName)\manifest.json") ) {
                        try {
                            $json = Get-Content -Raw -Path "$($version_folder.FullName)\manifest.json" | ConvertFrom-Json
                            $name = $json.name
                            if($json.app.launch){
                                if($json.app.launch.local_path){
                                    $launchfile = $json.app.launch.local_path
                                    }                            
                                if($json.app.launch.web_url){
                                    $launchurl = $json.app.launch.web_url
                                    }                            
                                }
                            if($json.background){
                                $background = $json.background.scripts
                            }                        
                            if($json.version){
                                $version = $json.version
                                }
                            if($json.update_url){
                                $updateurl = $json.update_url
                                }                        
                        } catch {
                            #$_
                            $name = ""
                        }
                    
                    }
                
                    ##: If we find _MSG_ in the manifest it's probably an app
                    if( $name -like "*MSG*" ) {
                        ##: Sometimes the folder is en
                        $fieldname = $name -match '^__MSG_(\w+)__'
                        $matchedfieldname = $Matches[1]
                        if( Test-Path -Path "$($version_folder.FullName)\_locales\en\messages.json" ) {
                            try { 
                                $json = Get-Content -Raw -Path "$($version_folder.FullName)\_locales\en\messages.json" | ConvertFrom-Json
                                $name = $json.appName.message
                                ##: Try a lot of different ways to get the name
                                if(!$name) {
                                    $name = $json.$matchedfieldname.message
                                } 
                            } catch { 
                                #$_
                                $name = ""
                            }
                        }
                        ##: Sometimes the folder is en_US
                        if( Test-Path -Path "$($version_folder.FullName)\_locales\en_US\messages.json" ) {
                            try {
                                $json = Get-Content -Raw -Path "$($version_folder.FullName)\_locales\en_US\messages.json" | ConvertFrom-Json
                                $name = $json.appName.message
                                ##: Try a lot of different ways to get the name
                                if(!$name) {
                                    $name = $json.$matchedfieldname.message
                                }
                            } catch {
                                #$_
                                $name = ""
                            }
                        }
                    }

                    if($storeLookup){ 
                        $title = GUIDLookup($folder) 
                    }else{
                        $title = "Lookup Disabled"
                    }
                    $result = @{}
                    $result.add("User Folder", "$chromePath")
                    $result.add("AppID", "$appid")
                    $result.add("OnDiskName", "$name")
                    $result.add("FolderVersion", "$version_folder")
                    $result.add("ManifestVersion", "$version")
                    $result.add("StoreName", "$title")
                    $result.add("LaunchFile", "$launchfile")
                    $result.add("UpdateUrl", "$updateurl")
                    $result.add("LaunchUrl", "$launchurl")
                    $result.add("Background", "$background")
                    $result.add("LastWrite_Installed", "$writedate")
                    $result.add("Status", "Installed")
                    Add-Result -hashtbl $result
                }
                if($remove){
                    $status = "Removal Failed"
                    Remove-Item -Recurse -Force -LiteralPath "$chromePath\$folder\"
                    $success = !(Test-Path -LiteralPath "$chromePath\$folder\")
                    if($success){ $status = "Removed" }
                    $result = @{}
                    $result.add("User Folder", "$chromePath")
                    $result.add("Extension Folder", "$chromePath\$folder\")
                    $result.add("AppID", "$appid")
                    $result.add("Status", $status)
                    Add-Result -hashtbl $result
                }
            }
        }
        if(!$tgtAppFound){
            $result = @{}
            $result.add("User Folder", "$chromePath")
            $result.add("Chrome Exists", $chromeExists)
            $result.Add("AppID",$tgtAppID)
            $result.Add("Status","NotFound")
            Add-Result -hashtbl $result
        }
    }
}
