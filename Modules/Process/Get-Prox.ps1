<#
.SYNOPSIS
Get-Prox.ps1 acquires Get-Process data
The Update-TypeData command is required in order
to prevent deserialization of some of the data due
to a bug mentioned here:
http://connect.microsoft.com/PowerShell/feedback/details/767928/it-isnt-possible-to-override-the-default-global-serialization-depth-for-all-objects-in-remote-sessions-when-using-invoke-command-or-start-job
.NOTES
Kansa.ps1 directive next line
OUTPUT xml
#>

Update-TypeData -TypeName System.Diagnostics.Process -SerializationDepth 3 -Force
Get-Process