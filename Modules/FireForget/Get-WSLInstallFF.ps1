# This is a simple module to check for Windows Subsystem for Linux (WSL) installations and packages. Since attackers can
# leverage WSL for evasion tactics and most AV solutions on windows won't flag ELF binaries for suspicious behvior this
# represents a potential secutiy blindspot. This module will help to gain visibility on where WSL is installed if it has
# not yet been disabled by corporate policy, or if savvy developers have found ways to circumvent such mitigating controls

$result = @{}
$WSLdism = $false
$WSLreg = $false
$WSLpkg = $false
$WSLusers = @()
$keyword = $false

$dismchk = dism /online /Get-FeatureInfo /FeatureName:Microsoft-Windows-Subsystem-Linux
if($dismchk -match "State : Enabled") {
    $WSLdism = $true
}

$regchk = Get-ItemProperty 'REGISTRY::HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\Notifications\OptionalFeatures\Microsoft-Windows-Subsystem-Linux'
if($regchk){
    $WSLreg = $true
}

$profiles = gci -Force -Directory "$env:SystemDrive\Users"
foreach($prof in $profiles){
    if(Test-Path -PathType Container -Path "$($prof.FullName)\AppData\Local\Packages"){
        $WSLpkg = $true
        $WSLusers += "$($prof.Name)"
        $subfolders = @()
        $subfoldersCreated = @()
        gci -Directory -Force -Path "$($prof.FullName)\AppData\Local\Packages" | %{
            $subfolders+="$($_.FullName)"
            $subfoldersCreated+="$($_.FullName); $($_.CreationTime)"
        }
        if($subfolders){
            $r = @{}
            $r.Add("PackageList",$true)
            $r.Add("Packages",$subfolders)
            $r.Add("PackagesCreated",$subfoldersCreated)
            Add-Result -hashtbl $r
        }
    }
}
$evilPkgs = enhancedGCI -startPath "C:\Users" -regex "(msfconsole|john_1\.9\.0|exploitdb|aircrack-ng)"
foreach($pkg in $evilPkgs){
    $keyword = $true
    $p = @{}
    $p.Add("BlacklistKeyword","$pkg")
    Add-Result -hashtbl $p
}

$result.Add("WSL-DismCheck",$WSLdism)
$result.Add("WSL-RegistryCheck",$WSLreg)
$result.Add("WSL-PackagesFound",$WSLpkg)
$result.Add("PackageList",$false)
$result.Add("BlacklistKeywordFound",$keyword)
$result.Add("WSL-Users",[array]$WSLusers)
Add-Result -hashtbl $result
