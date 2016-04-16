<#
.SYNOPSIS
Get-WMIIETelemetry.ps1
Queries the IEURLInfo class in the CIMv2/IETelemetry namespace and lists the
information it contains.

.DESCRIPTION
IEURLInfo properties include visited URLs, the number of times a URL was
visited, and number of times the site caused IE to crash. The properties
returned depend on the version of Internet Explorer installed, so stack-ranking
across all results may not be possible.

This namespace will only exist if the Enterprise Site Discovery toolkit is
installed on the target system. Details on the toolkit and scripts to deploy it
are available at the links below. Please make sure you read and understand all
of the warnings and potential impacts of using this toolkit.

https://blogs.msdn.microsoft.com/ie/2014/10/24/announcing-the-enterprise-site-discovery-toolkit-for-internet-explorer-11/
https://technet.microsoft.com/itpro/internet-explorer/ie11-deploy-guide/collect-data-using-enterprise-site-discovery

Thank you, Jon Glass (@GlassSec) for pointing out this class.

.NOTES
Kansa.ps1 output directive follows
OUTPUT tsv
#>

try {
    $IEUrlInfo = Get-WmiObject -Namespace 'root\cimv2\IETelemetry' -Class IEURLInfo -ErrorAction Stop
    $IEUrlInfo
}
catch [System.Management.ManagementException] {
    throw 'WMI Namespace root\fimv2\IETelemetry does not exist.'
}