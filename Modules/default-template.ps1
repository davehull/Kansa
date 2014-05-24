# OUTPUT txt
<#
.SYNOPSIS
Default module template

Q. How does a module tell the caller how to handle its output?
A. Iff a module returns objects, the module can tell Kansa how to handle the output
by placing a comment on the FIRST line of the module like one of the following:
# OUTPUT csv
# OUTPUT tsv
# OUTPUT txt
# OUTPUT xml
Kansa.ps1 will then treat the objects accordingly.

Two exceptions:
# OUTPUT bin
# OUTPUT zip

Some modules may need to return binary data, Get-ProcDump.ps1 for example. Others may
return multiple files, these have to be zipped up and returned as zip files, Get-
PrefetchFiles.ps1 is an example. Those two output specifiers cause the data to be
handled as binary data.

Q. Can't I place the OUTPUT directive on line two?
A. Not if you want it to work correctly. OUTPUT directives shall only
be honored if they are on the first line of the module. Be they on line
two or three or greater, they shall not be enforced.

Q. What if a module doesn't specify its output?
A. The caller will assume the output is text and pipe it to a text file.

Q. Are there naming requirements for modules?
A. Yes. because modules are intended only to gather data, they must be 
named according to Powershell's verb-noun convention. Examples:
Get-PrefetchListing.ps1
Get-DNSCache.ps1
Get-Prox.ps1

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
    $shell = New-Object -ComObject shell.application
    $zip = $shell.Namespace($zipfile)
    foreach($item in $zip.items()) {
        $shell.Namespace($destination).copyhere($item)
    }
}    