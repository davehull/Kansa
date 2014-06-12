# OUTPUT txt
# Get-Reg.ps1 is the start of a series of modules that will collect registry based artifacts

function rot13 {
# Returns a Rot13 string of the input $value
# May not be the most efficient way to do this
Param(
[Parameter(Mandatory=$True,Position=0)]
    [string]$value
)
    $newvalue = @()

    for ($i = 0; $i -lt $value.length; $i++) {
        $charnum = [int]$value[$i]
        if ($charnum -ge [int][char]'a' -and $charnum -le [int][char]'z') {
            if ($charnum -gt [int][char]'m') {
                $charnum -= 13
            } else {
                $charnum += 13
            }
        } elseif ($charnum -ge [int][char]'A' -and $charnum -le [int][char]'Z') {
            if ($charnum -gt [int][char]'M') {
                $charnum -= 13
            } else {
                $charnum += 13
            }
        }
        $newvalue += [char]$charnum
    }
    $newvalue -join ""
}



if (Get-Command Reg.exe -ErrorAction SilentlyContinue) { 
	$regexe = Reg.exe | Select-Object -ExpandProperty path
    foreach ($userpath in (Get-WmiObject win32_userprofile | Select-Object -ExpandProperty localpath)) {
        if (Test-Path($userpath + "\ntuser.dat")) {
            $regload = & $regexe load "hku\KansaTempHive" ($userpath + "\ntuser.dat")
            if ($regload -notmatch "ERROR") {
                $userpath
                Set-Location "Registry::HKEY_USERS\KansaTempHive\Software\Microsoft\Windows\CurrentVersion\Explorer\"
                if (Test-Path("UserAssist")) {
                    "UserAssist found."
                    foreach ($uavalue in (ls "UserAssist" -Recurse | select -expandproperty property)) {
                        if ($uavalue -match '.*({[-A-Za-z0-9]*}).*') {
                            $GUID = $($matches[1])
                            $uavalue
                            $uavalue = $uavalue -replace $GUID
                            $rot13uav = rot13 $uavalue
                            $GUID + $rot13uav
                        } else {
                            $rot13uav = rot13 $uavalue
                            $rot13uav
                        }
                    }
                }
                Set-Location $env:SystemDrive
                [gc]::collect()
                reg unload "hku\KansaTempHive"
            }
        }
    }
}