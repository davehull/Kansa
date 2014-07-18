<# 
.SYNOPSIS
Get-File.ps1 retrieves the user specified file.
.PARAMETER File
A recommended parameter, a sensible default is provided, that points to
the file you want to acquire from remote systems.

When used with Kansa.ps1, parameters must be positional. Named params
are not supported.
.EXAMPLE
Get-File.ps1 C:\Users\Administrator\NTUser.dat
.NOTES
When passing specific modules with parameters via Kansa.ps1's
-ModulePath parameter, be sure to quote the entire string, like shown
here:
.\kansa.ps1 -Target localhost -ModulePath ".\Modules\Disk\Get-File.ps1 C:\boot.log"

Following line is needed by Kansa.ps1 to determine how to handle output
OUTPUT Default
#>


[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$File="C:\Users\Administrator\NTUser.dat"
)

if (Test-Path($File)) {
    Get-Content -ReadCount 0 -Raw $File
}  