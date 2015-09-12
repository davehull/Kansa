<#
.SYNOPSIS
Get-PSDotNetVersion.ps1 returns an object with PowerShell and .NET
version information.
.DESCRIPTION
Get-PSDotNetVersion.ps1 dynamically builds an object with properties
from $PSVersiontable's keys and mscorlib.dll's version information. As
of this writing, the object may have the following structure, depending
on how many versions of the .NET framework are installed:

PSVersion                 :
WSManStackVersion         :
SerializationVersion      :
CLRVersion                :
BuildVersion              :
PSCompatibleVersions      :
PSRemotingProtocolVersion :
.NET_1                    :
.NET_2                    :
#>

$obj = "" | Select-Object $($PSVersionTable.Keys)
foreach($item in $PSVersionTable.Keys) { 
    $obj.$item = $($PSVersionTable[$item] -join ".")
}

$i = 1
Get-ChildItem -Force "$($env:windir)\Microsoft.Net\Framework" -Include mscorlib.dll -Recurse | ForEach-Object { 
    $obj | Add-Member NoteProperty .NET_$i $_.VersionInfo.ProductVersion
    $i++
}

$obj