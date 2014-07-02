# OUTPUT Default
# Get-File.ps1 retrieves the user specified file.
# How does the user specify the file? By editing
# the $targetFile value below with a full path.

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$File="C:\Users\Administrator\NTUser.dat"
)

if (Test-Path($File)) {
    Get-Content -ReadCount 0 -Raw $File
}  