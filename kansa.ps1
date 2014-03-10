<#
.SYNOPSIS
Kansa is the codename for the modular rewrite of Mal-Seine.

In this modular version of Mal-Seine, Kansa enumerates the available 
modules, calls the main function of each user designated module, 
redirects error and output information from the modules to their
proper places.

This script was written with the intention of avoiding the need for
CredSSP, therefore the need for second-hops must be avoided.

The script requires Remote Server Administration Tools (RSAT). These
are available from Microsoft's Download Center for Windows 7 and 8.
You can search for RSAT at:

http://www.microsoft.com/en-us/download/default.aspx


#>