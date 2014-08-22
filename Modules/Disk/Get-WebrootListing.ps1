<#
.SYNOPSIS
Get-WebrootListing.ps1 returns a recursive listing of files in a web server's 
document root. Comparing these items may allow you identify web shells left
behind by attackers to enable re-compromise after remediation.
.PARAMETER BasePath
Optional base path to start the listing. Uses IIS's default of C:\inetpub\wwwroot
if this isn't provided.
.NOTES
Next line is required by kansa.ps1 for proper handling of script output
OUTPUT tsv
#>

Param(
    [Parameter(Mandatory=$False,Position=0)]
        [string]$BasePath="C:\inetpub\wwwroot"
)

if (Test-Path $BasePath -PathType Container) {
        Get-ChildItem $BasePath -Recurse | Select-Object FullName, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc
}