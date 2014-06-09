# OUTPUT tsv
<#
.SYNOPSIS
Get listing of common temporary directories
#>

foreach($userpath in (Get-WmiObject win32_userprofile | Select-Object -ExpandProperty localpath)) {
    if (Test-Path(($userpath + "\AppData\Local\Temp\"))) {
        Get-ChildItem ($userpath + "\AppData\Local\Temp\*") | Select-Object FullName, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
    }
}