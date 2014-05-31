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



if ($pathToReg = Get-Command Reg.exe | Select-Object -ExpandProperty path) { 
    foreach ($userpath in (Get-WmiObject win32_userprofile | Select-Object localpath)) {
    <# TKTK if $userpath contains an ntuser.dat
    reg load "hku\$userpath" "$userpath\ntuser.dat"
    set-location registry::\hkey_users
    get-itemproperty .\$userpath\path\to\key\value
    

    
    }
}

#>