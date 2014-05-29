# OUTPUT txt
# Get-Reg.ps1 is the start of a series of modules that will collect registry based artifacts

if ($pathToReg = Get-Command Reg.exe | Select-Object -ExpandProperty path) { 
    foreach ($userpath in (Get-WmiObject win32_userprofile | Select-Object localpath)) {
    <# TKTK if $userpath contains an ntuser.dat
    reg load "hku\$userpath" "$userpath\ntuser.dat"
    set-location registry::\hkey_users
    get-itemproperty .\$userpath\path\to\key\value
    

    #>
    }
}