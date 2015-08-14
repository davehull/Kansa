<#
.SYNOPSIS
Get-CertStore.ps1 enumerates certificate stores.
.DESCRIPTION
Get-CertStore.ps1 uses PowerShell's Certificate provider to access and
enumerate information about certificates on the host.
#>

$ErrorActionPreference = "Continue"

Try {
    Push-Location
    Set-Location Cert:
    ls -r * | Select-Object PSParentPath,FriendlyName,NotAfter,NotBefore,SerialNumber,Thumbprint,Issuer,Subject
} Catch {
    ("Caught exception: {0}." -f $_)
} Finally {
    Pop-Location
}