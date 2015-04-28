<#
.SYNOPSIS
Get-CertStore.ps1 enumerates certificate stores.
.DESCRIPTION
Get-CertStore.ps1 uses PowerShell's Certificate provider to access and
enumerate information about certificates on the host.
.NOTES
The following lines are required by Kansa.ps1. The first is an OUTPUT
directive that tells Kansa how to tread the output from this script.
OUTPUT csv
#>

Try {
    Push-Location
    Set-Location Cert:
    ls -r * | fl *
} Catch {
    ("Caught exception: {0}." -f $_)
} Finally {
    Pop-Location
}