<#
.SYNOPSIS
Author: Joseph Kjar
Date: 10/2016
This script provides generic functions that can be used to create a 
connection to Elk and send data over the established socket.
#>

function Generate-ElkAlert{
    param(
    [parameter(Mandatory=$true,Position=0)]
        [string]$srcScript="",
    [parameter(Mandatory=$true,Position=1)]
        [string]$srcHost="",
    [parameter(Mandatory=$true,Position=2)]
        [string]$alertName="",
    [parameter(Mandatory=$true,Position=3,ValueFromPipeLine=$true)]
        [System.Collections.Hashtable]$alertContent
    )

    $alertBody = New-Object System.Collections.Hashtable
    $alertBody.Add("Source Script",$srcScript)
    $alertBody.Add("Source Host",$srcHost)
    $alertBody.Add("Alert Name",$alertName)
    
    $alertContent.GetEnumerator() | % {
        $alertBody.Add($_.Key,$_.Value)
    }

    $jsonAlert = $alertBody | ConvertTo-Json
    Write-Host $jsonAlert
    return $jsonAlert
}

function Get-UDPSocket{
    param(
        $destIP="127.0.0.1",
        [int]$port=41337
    )

    # Parse IP
    $address = [System.Net.IPAddress]::Parse($destIP)
    # Create network endpoint
    $dest = New-Object System.Net.IPEndPoint $address,$port

    # Create socket
    $addrFam = [System.Net.Sockets.AddressFamily]::InterNetwork
    $socketType = [System.Net.Sockets.SocketType]::Dgram
    $protocol = [System.Net.Sockets.ProtocolType]::Udp

    $socket = New-Object System.Net.Sockets.Socket $addrFam,$socketType,$protocol

    # Connect to socket
    $socket.Connect($dest)

    return $socket
}

function Send-ElkAlertUDP{
    param(
        [object]$socket,
        [string]$alertContent = ""
    )

    # Create encoded buffer
    $enc = [System.Text.Encoding]::ASCII
    $message = $alertContent
    $buffer = $enc.GetBytes($message)
    
    # Send the buffer
    $sent = $socket.Send($buffer)

    return $sent
}

function Send-ElkAlertTCP{
    param(
        [object]$writer,
        [string]$alertContent = ""
    )
    if(($writer -eq $null) -or ($alertContent -eq $null)) { 
        return;
        Write-Verbose "Error"
    }
    $SLmessage = $alertContent.Replace("`r`n", '')
    $writer.WriteLine($SLmessage)
    return $SLmessage.Length
}

function Get-TCPWriter{
    param(
        $destIP="127.0.0.1",
        [int]$port=31337
    )

    #if check to see if ip/port are invalid and return a file streamwriter instead
    $socket = new-object System.Net.Sockets.TcpClient($destIP, $port)
    $stream = $socket.GetStream()
    $enc = [System.Text.Encoding]::ASCII
    $writer = new-object System.IO.StreamWriter($stream,$enc)
    $writer.AutoFlush = $false
    return $writer
}
