# Simple module to enumerate the contents of each Startup folder under each user profile to look for unusual startup
# values that may be used for persistence

$userprofiles = (gci -Force -Directory -Path $($env:SystemDrive + "\Users")).FullName
[System.Collections.ArrayList]$paths = @()
foreach ($user in $userprofiles) { [void]$paths.Add($($user + "\AppData\Roaming\Microsoft\Windows\Start Menu\Programs\Startup\")) }
[void]$paths.Add($($env:SystemDrive + "\ProgramData\Start Menu\Programs\Startup\")) # look at default and All Users folders as well
[void]$paths.Add($($env:SystemDrive + "\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\")) # look at default and All Users folders as well
foreach ($path in $paths) {
    if (Test-Path $path){
        $files = gci -Force -Path $path -File -ErrorAction SilentlyContinue
        foreach ($file in $files){
            $result = @{}
            if ($file.Name -ne 'desktop.ini'){
                #don't want to hash the desktop.ini files since they are very prolific and will incur significant computational overhead, plus they will vary a lot so the hash may not be helpful
                $result = Get-FileDetails -hashtbl $result -filepath $file.FullName -computeHash -algorithm MD5 -getContent
            } else{
                $result = Get-FileDetails -hashtbl $result -filepath $file.FullName -getContent
                #https://isc.sans.edu/forums/diary/Desktopini+as+a+postexploitation+tool/25912/
            }
            $hidden = $false
            $system = $false
            $readonly = $false
            if($result -and ($result.ContainsKey("FileMode"))){
                if ($result.FileMode -match 'h') { $hidden = $true }
                if ($result.FileMode -match 's') { $system = $true }
                if ($result.FileMode -match 'r') { $readonly = $true }
            }
            $result.add("FileIsHidden",$hidden)
            $result.add("FileIsSystem",$system)
            $result.add("FileIsReadOnly",$readonly)
            Add-Result -hashtbl $result
        }
    }
}
