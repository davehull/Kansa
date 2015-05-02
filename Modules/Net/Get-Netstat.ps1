<#
.SYNOPSIS
Get-Netstat.ps1 acquires netstat -naob output and reformats on the 
target as tsv output.

.NOTES
Next line needed by Kansa.ps1 for proper handling of this script's data
OUTPUT tsv
#>


function Get-AddrPort {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$AddrPort
)
    Write-Verbose "Entering $($MyInvocation.MyCommand)"
    Write-Verbose "Processing $AddrPort"
    if ($AddrPort -match '[0-9a-f]*:[0-9a-f]*:[0-9a-f%]*\]:[0-9]+') {
        $Addr, $Port = $AddrPort -split "]:"
        $Addr += "]"
    } else {
        $Addr, $Port = $AddrPort -split ":"
    }
    $Addr, $Port
    Write-Verbose "Exiting $($MyInvocation.MyCommand)"
}

if (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
# If run as admin, collect Component and Process names in addition to other data.
    $netstatScriptBlock = { & $env:windir\system32\netstat.exe -naob }
    foreach($line in $(& $netstatScriptBlock)) {
        if ($line.length -gt 1 -and $line -notmatch "Active |Proto ") {
            $line = $line.trim()
            if ($line.StartsWith("TCP")) {
                $Protocol, $LocalAddress, $ForeignAddress, $State, $ConPId = ($line -split '\s{2,}')
                $Component = $Process = $False
            } elseif ($line.StartsWith("UDP")) { 
                $State = "STATELESS"
                $Protocol, $LocalAddress, $ForeignAddress, $ConPid = ($line -split '\s{2,}')
                $Component = $Process = $False
            } elseif ($line -match "^\[[-_a-zA-Z0-9.]+\.(exe|com|ps1)\]$") {
                $Process = $line
                if ($Component -eq $False) {
                    # No Component given
                    $Component = $Process
                }
            } elseif ($line -match "Can not obtain ownership information") {
                $Process = $Component = $line
            } else {
                # We have the $Component
                $Component = $line
            }
            if ($State -match "TIME_WAIT") {
                $Component = "Not provided"
                $Process = "Not provided"
            }
            if ($Component -and $Process) {
                $LocalAddress, $LocalPort = Get-AddrPort($LocalAddress)
                $ForeignAddress, $ForeignPort = Get-AddrPort($ForeignAddress)

                $o = "" | Select-Object Protocol, LocalAddress, LocalPort, ForeignAddress, ForeignPort, State, ConPId, Component, Process
                $o.Protocol, $o.LocalAddress, $o.LocalPort, $o.ForeignAddress, $o.ForeignPort, $o.State, $o.ConPId, $o.Component, $o.Process = `
                    $Protocol, $LocalAddress, $LocalPort, $ForeignAddress, $ForeignPort, $State, $ConPid, $Component, $Process
                $o
            }
        }
    }
} else {
# If run as non-admin, we can't grab Component and Process name.
    $netstatScriptBlock = { & $env:windir\system32\netstat.exe -nao }
    ("Protocol","LocalAddress","LocalPort","ForeignAddress","ForeignPort","State","PId") -join "`t"
    foreach($line in $(& $netstatScriptBlock)) {
        if ($line.length -gt 1 -and $line -notmatch "Active |Proto ") {
            $line = $line.trim()
            if ($line.StartsWith("TCP")) {
                $Protocol, $LocalAddress, $ForeignAddress, $State, $ConPId = ($line -split '\s{2,}')
            } elseif ($line.StartsWith("UDP")) {
                $State = "STATELESS"
                $Protocol, $LocalAddress, $ForeignAddress, $ConPId = ($line -split '\s{2,}')
            }
            $LocalAddress, $LocalPort = Get-AddrPort($LocalAddress)
            $ForeignAddress, $ForeignPort = Get-AddrPort($ForeignAddress)
            $o = "" | Select-Object Protocol, LocalAddress, LocalPort, ForeignAddress, ForeignPort, State, PId
            $o.Protocol, $o.LocalAddress, $o.LocalPort, $o.ForeignAddress, $o.ForeignPort, $o.State, $o.PId = `
                $Protocol, $LocalAddress, $LocalPort, $ForeignAddress, $ForeignPort, $State, $Pid
            $o
        }
    }
}