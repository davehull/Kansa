# OUTPUT txt
<#
.SYNOPSIS
Get-Netstat.ps1 acquires netstat -naob output and reformats on the 
target as tsv output.
ToDo: Output from this module is tab delimited text. Need to rewrite it so
it works with the OUTPUT tsv directive. I think that means returning objects
rather than text.
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

("Protocol","LocalAddress","LocalPort","ForeignAddress","ForeignPort","State","PId","Component","Process") -join "`t"
foreach($line in $(& $env:windir\system32\netstat.exe -naob)) {
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
            ($Protocol, $LocalAddress, $LocalPort, $ForeignAddress, $ForeignPort, $State, $ConPid, $Component, $Process) -join "`t"
        }
    }
}

