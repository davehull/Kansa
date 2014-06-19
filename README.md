Kansa
=====

A modular incident response framework in Powershell.

More info:
http://trustedsignal.blogspot.com/search/label/Kansa

##What does it do? 
It uses Powershell Remoting to run user contributed, ahem, user contributed modules across
hosts in an enterprise to collect data for use during incident response, breach hunts, or for building an
environmental baseline.

##How do you use it?
Here's a very simple command line example you can run on your own local host.
1. Open an elevated Powershell Prompt (Right-click Run As Administrator)
2. At the command prompt, enter: .\kansa.ps1 -Target localhost -ModulePath .\Modules -Verbose
The script should start collecting data or you may see an error about not having Windows Remote Management enabled.
If so, do a little searching online, it's easy to turn on. Turn it on and try again.
When it finishes running, you'll have a new Output_<timestamp> subdirectory, with subdirectories for data collected
by each module. You can cd into those subdirectories and checkout the data. There are some analysis scripts in the
Analysis directory, but many of those won't make sense on a collection of data from a single host. Kansa was written
for collection and analysis of data from dozens, hundreds, thousands, tens of thousands of systems.

##Caveats:
Powershell relies on the Windows API. Your adversary may use subterfuge.*

* Collectors can be written to bypass the Windows API as well. Get-RekallPslist.ps1 for example.
