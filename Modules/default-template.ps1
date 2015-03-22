<#
.SYNOPSIS
This is a template for Kansa collectors aka modules.

Modules can be written to take parameters with arguments passed via 
Modules\Modules.conf or via the command line. Named parameters do not
work. Parameters passed via command line must be quoted, multiple
parameters must be comma separated. 

Example:
Kansa.ps1 ".\Modules\Disk\Get-FilesByHash.ps1 9E2639ECE5631BAB3A41E3495C1DC119,MD5,C:\,\.ps1$" -Target localhost -Verbose

Parameters passed via Modules\Modules.conf must not be quoted.
Example:
Disk\Get-FilesByHash.ps1 9E2639ECE5631BAB3A41E3495C1DC119,MD5,C:\,\.ps1$

Q. How does a module tell Kansa.ps1 how to handle its output?
A. Iff a module returns Powershell objects, the module can tell Kansa
how to handle the output via a special "directive" in the .SYNOPSIS 
section of the collector script.

Output directives look like the one of the following:
OUTPUT csv
OUTPUT tsv
OUTPUT txt
OUTPUT xml
OUTPUT Default

All directives:
Must start at the beginning of a line
Are case-sensitive
Should be somewhere in the .SYNOPSIS section, 
In .NOTES is the current convention.

Kansa.ps1 will then treat the objects accordingly.

Two exceptions for output directives:
OUTPUT bin
OUTPUT zip

Above are not Powershell object output. Some modules return binary
data, bin would be memory image or other binary file, zip would be for
compressed data, obviously.

Q. Where should I place the OUTPUT directive?
A. As long as the directives follow the restrictions above, they start
the line and are capitalized as above, they will be picked up by 
Kansa.ps1 and honored. By convention, they are typically placed in the 
.NOTES section of the .SYNOPSIS.

Q. What if a module doesn't specify its output?
A. The caller will assume the output is text and pipe it to a text
file.

Q. Are there naming requirements for modules?
A. Yes. Because modules are intended only to gather data, they must be 
named according to Powershell's verb-noun convention. Examples:
Get-PrefetchListing.ps1
Get-DNSCache.ps1
Get-Prox.ps1

Modules that don't start with Get- will be ignored. Note that there are
cases where having a module that makes changes to remote hosts is 
desireable, during tactical remediation, for example. In such cases, 
you may choose to name such a module, Get-Remediation.ps1.

Q. I have an idea for a module, but it requires an executable that 
doesn't ship with Windows. Any way to do that?
A. Yes, just as modules can use the OUTPUT directive to instruct Kansa
how to handle their output, they can include a BINDEP directive that 
tells Kansa that they have a binary dependency. When Kansa.ps1 is run
with the -Pushbin switch, Kansa.ps1 will look through the script for 
the BINDEP directive that tells Kansa where to find the binary that
needs to be copied to remote hosts. Following BINDEP should be a path
to the binary relative to Kansa.ps1.

Just as with the OUTPUT directives, these are placed in the .SYNOPSIS
.NOTES section by convention.

Binaries will be copied to the ADMIN$ share of remote hosts.

See the Modules\Process\Get-Handle.ps1 script for an example.

Q. Any other requirements?
A. Many modules assume they will be run with administrator privileges,
Get-Netstat.ps1, for example. Interestingly, Get-Netstat.ps1 will run
without admin privs, but it won't provide the output that the analyst 
wanted.
#>

# Zip function, in case your collector needs it. It's currently used
# by Get-PrefetchFiles.ps1 and Get-PSProfiles.ps1, both collect 
# multiple files
function add-zip
{
    param([string]$zipfilename)

    if (-not (Test-Path($zipfilename))) {
        Set-Content $zipfilename ("PK" + [char]5 + [char]6 + ("$([char]0)" * 18))
        (dir $zipfilename).IsReadOnly = $false
    }

    $shellApplication = New-Object -com shell.application
    $zipPackage = $shellApplication.NameSpace($zipfilename)

    foreach($file in $input) {
        $zipPackage.CopyHere($file.FullName)
        Start-Sleep -milliseconds 100
    }
}

# Expand-Zip does what the name implies, here for reference, used by Get-FlsBodyfile.ps1
Function Expand-Zip ($zipfile, $destination) {
	[int32]$copyOption = 16 # Yes to all
    $shell = New-Object -ComObject shell.application
    $zip = $shell.Namespace($zipfile)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item, $copyOption)
    }
}    