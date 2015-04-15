<#
.SYNOPSIS
Get-Sigcheck.ps1 returns output from the Sysinternals' sigcheck.exe utility.

.NOTES
The following lines are required by Kansa.ps1. They are directives that
tell Kansa how to treat the output of this script and where to find the
binary that this script depends on.
OUTPUT tsv
BINDEP .\Modules\bin\sigcheck.exe

!!THIS SCRIPT ASSUMES SIGCHECK.EXE WILL BE IN $ENV:SYSTEMROOT!!
#>

if (Test-Path "$env:SystemRoot\sigcheck.exe") {

    # We'll randomly pick a path because doing $env:systemroot\ takes hours
    $rootpath = Get-Random -Minimum 1 -Maximum 6
    switch ($rootpath) {
        1 { $rootpath = "$env:temp\" }
        2 { $rootpath = "$env:systemroot\" }
        3 { $rootpath = "$env:allusersprofile\" }
        4 { $rootpath = "$env:ProgramFiles\" }
        5 { $rootpath = "$env:ProgramData\" }
        6 { $rootpath = "$env:ProgramFiles(x86)\" }
    }
    # Write-Verbose $rootpath
    Try {
        # We want to pop our location in the finally block
        Push-Location
        Set-Location $rootpath

        & $env:SystemRoot\sigcheck.exe /accepteula -a -e -c -h -q -s -r 2> $null | ConvertFrom-Csv | ForEach-Object {
            $_
        }
    } Catch {
        Write-Error ("Caught: {0}" -f $_)
    } Finally {
        Pop-Location
    }

} else {
    Write-Error "Sigcheck.exe not found in $env:SystemRoot."
}