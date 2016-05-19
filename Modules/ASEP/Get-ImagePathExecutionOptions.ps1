<#
.SYNOPSIS
  Checks for persistence by attaching a debugger to an image file execution
  option record in the registry.
  
.DESCRIPTION
  Paths and filters from tweets by Casey Smith (@subTee) and Matt Graeber
  (@mattifestation) on May 19, 2016.
  
.NOTES
OUTPUT csv
#>

Get-ItemProperty -Path 'HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\*' | Where-Object { $_.Debugger }
Get-ItemProperty -Path 'HKLM:SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\*' | Where-Object { $_.Debugger }