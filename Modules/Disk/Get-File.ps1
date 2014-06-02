# OUTPUT bin
# Get-File.ps1 retrieves the user specified file.
# How does the user specify the file? By editing
# the $targetFile value below with a full path.

$targetFile = "C:\Users\mosecsvc\ntuser.dat"

if (Test-Path($targetFile)) {
    Get-Content -ReadCount 0 -Raw -Encoding Byte $targetFile
}  