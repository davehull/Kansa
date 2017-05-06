Kansa
=====

A modular incident response framework in Powershell. It's been tested in PSv2 / .NET 2 and
later and works mostly without issue.

But really, upgrade to PSv3 or later. Be happy.

More info:  
http://trustedsignal.blogspot.com/search/label/Kansa  
http://www.powershellmagazine.com/2014/07/18/kansa-a-powershell-based-incident-response-framework/  

## What does it do?
It uses Powershell Remoting to run user contributed, ahem, user contri-  
buted modules across hosts in an enterprise to collect data for use  
during incident response, breach hunts, or for building an environmental  
baseline.

## How do you use it?
Here's a very simple command line example you can run on your own local  
host.  

1.  After downloading the project and unzipping it, you'll likely need  
to "unblock" the ps1 files. The easiest way to do this if you're using  
Powershell v3 or later is to cd to the directory where Kansa resides  
and do:  
```Powershell
ls -r *.ps1 | Unblock-File
```
1. Ensure that you check your execution policies with PowerShell. Check [Using the Set-ExecutionPolicy Cmdlet](https://technet.microsoft.com/en-us/library/ee176961.aspx) for information on how to do so within your environment.  
```
Set-ExecutionPolicy AllSigned | RemoteSigned | Unrestricted
```
1. If you're not running PS v3 or later, [Sysinternal's Streams utility](https://technet.microsoft.com/en-us/sysinternals/streams.aspx) can  
be used to remove the alternate data streams that Powershell uses to  
determine if files came from the Internet. Once you've removed those  
ADSes, you'll be able to run the scripts without issue.  
```
c:\ streams -sd <Kansa directory>
```

I've not run into any issues running the downloaded scripts via Windows  
Remote Management / Powershell Remoting through Kansa, so you shouldn't  
have to do anything if you want to run the scripts via remoting.  

2.  Open an elevated Powershell Prompt (Right-click Run As Administrator)  

3.  At the command prompt, enter:
```Powershell
.\kansa.ps1 -Target $env:COMPUTERNAME -ModulePath .\Modules -Verbose  
```
The script should start collecting data or you may see an error about  
not having Windows Remote Management enabled. If so, do a little  
searching online, it's easy to turn on. Turn it on and try again. When  
it finishes running, you'll have a new Output_timestamp subdirectory,  
with subdirectories for data collected by each module. You can cd into  
those subdirectories and checkout the data. There are some analysis  
scripts in the Analysis directory, but many of those won't make sense  
on a collection of data from a single host. Kansa was written for  
collection and analysis of data from dozens, hundreds, thousands, tens  
of thousands of systems.  

## Running Modules Standalone
Kansa modules can be run as standalone utilities outside of the Kansa  
framework. Why might you want to do this? Consider netstat -naob, the  
output of the command line utility is ugly and doesn't easily lend  
itself to analysis. Running  
```Powershell
Modules\Net\Get-Netstat.ps1
```
as a standalone script will call netstat -naob, but it will return  
Powershell objects in an easy to read, easy to analyze format. You can  
easily convert its output to CSV, TSV or XML using normal Powershell  
cmdlets. Here's an example:  
```Powershell
.\Get-Netstat.ps1 | ConvertTo-CSV -Delimiter "`t" -NoTypeInformation | % { $_ -replace "`"" } | Set-Content netstat.tsv
```
the result of the above will be a file called netstat.tsv containing  
unquoted, tab separate values for netstat -naob's ouput.

## Caveats:
Powershell relies on the Windows API. Your adversary may use subterfuge.*

* Collectors can be written to bypass the Windows API as well.  
Get-RekallPslist.ps1 for example.
