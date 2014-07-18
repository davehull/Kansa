<#
.SYNOPSIS
Get-Handle acquires handle data using sysinternals handle.exe

!!THIS SCRIPT ASSUMES HANDLE.EXE WILL BE IN $ENV:SYSTEMROOT!!

If you have handle.exe in your Modules\bin\ path and run the script with the -Pushbin
flag, Kansa will attempt to copy the binary to the ADMIN$. Binaries are not removed, so
subsequent runs won't require -Pushbin.
.NOTES
Below are directives required by Kansa.ps1, they are case sensitive.
The first, OUTPUT tsv, tells Kansa.ps1 that output from this script
should be saved as tsv data. The second, BINDEP, tells Kansa that
the executable following it needs to be copied to remote systems.
.NOTES
Next two lines are Kansa.ps1 directives
OUTPUT tsv
BINDEP .\Modules\bin\Handle.exe
#>


if (Test-Path "$env:SystemRoot\handle.exe") {
    $data = (& $env:SystemRoot\handle.exe /accepteula -a)
    #("Process","PId","Owner","Type","Perms","Name") -join $Delimiter
    foreach($line in $data) {
        $line = $line.Trim()
        if ($line -match " pid: ") {
            $HandleId = $Type = $Perms = $Name = $null
            $pattern = "(?<ProcessName>^[-a-zA-Z0-9_.]+) pid: (?<PId>\d+) (?<Owner>.+$)"
            if ($line -match $pattern) {
                $ProcessName,$ProcId,$Owner = ($matches['ProcessName'],$matches['PId'],$matches['Owner'])
            }
        } else {
            $pattern = "(?<HandleId>^[a-f0-9]+): (?<Type>\w+)"
            if ($line -match $pattern) {
                $HandleId,$Type = ($matches['HandleId'],$matches['Type'])
                $Perms = $Name = $null
                switch ($Type) {
                    "File" {
                        $pattern = "(?<HandleId>^[a-f0-9]+):\s+(?<Type>\w+)\s+(?<Perms>\([-RWD]+\))\s+(?<Name>.*)"
                        if ($line -match $pattern) {
                            $Perms,$Name = ($matches['Perms'],$matches['Name'])
                        }
                    }
                    default {
                        $pattern = "(?<HandleId>^[a-f0-9]+):\s+(?<Type>\w+)\s+(?<Name>.*)"
                        if ($line -match $pattern) {
                            $Name = ($matches['Name'])
                        }
                    }
                }
                if ($Name -ne $null) {
                    $o = "" | Select-Object ProcessName, ProcId, HandleId, Owner, Type, Perms, Name
                    $o.ProcessName, $o.ProcId, $o.HandleId, $o.Owner, $o.Type, $o.Perms, $o.name = `
                        $ProcessName,$ProcId,("0x" + $HandleId),$Owner,$Type,$Perms,$Name
                    $o
                }
            }
        }
    }

} else {
    Write-Error "Handle.exe not found in $env:SystemRoot."
}