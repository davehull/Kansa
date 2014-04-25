# OUTPUT txt
<#
.SYNOPSIS
Get-Prox.ps1 acquires Get-Process data
I had to adjust the output of this module
to txt, though in reality it is still xml.
When Get-Process is run remotely, the thread
property isn't preserved if the data is sent
directly back to the host where the command 
was invoked, but if the data is written to disk
first on the remote host, the full fidelity of
the thread property is preserved. A call to 
Get-Content is then used to read it from disk
causing it to be sent back to the calling host.
Odd Powershell issue that I'd love to hear an
explanation about.
#>

Get-Process | Export-Clixml KansaProx.xml -Depth 10
Get-Content -ReadCount 0 -Raw KansaProx.xml
Remove-Item KansaProx.xml