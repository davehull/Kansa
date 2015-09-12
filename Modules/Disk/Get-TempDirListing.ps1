<#
.SYNOPSIS
Get-TempDirListing.ps1 returns listing of common temp directories.
.NOTES
Next line is required by kansa.ps1 for proper handling of script output
OUTPUT tsv
#>

foreach($userpath in (Get-WmiObject win32_userprofile | Select-Object -ExpandProperty localpath)) {
    if (Test-Path(($userpath + "\AppData\Local\Temp\"))) {
        Get-ChildItem -Force ($userpath + "\AppData\Local\Temp\*") | Select-Object FullName, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
    }
}