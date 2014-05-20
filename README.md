Kansa
=====

A modular incident response framework in Powershell.

More info:
http://trustedsignal.blogspot.com/search/label/Kansa

##What does it do? 
It uses Powershell Remoting to run user contributed, ahem, user contributed modules across
hosts in an enterprise to collect data for use during incident response, breach hunts, or for building an
environmental baseline.

##Caveats:
Powershell relies on the Windows API. Your adversary may use subterfuge.*

* Collectors can be written to bypass the Windows API as well. Get-RekallPslist.ps1 for example.
