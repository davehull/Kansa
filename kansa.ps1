<#
.SYNOPSIS
Kansa is a Powershell based incident response framework for Windows 
environments.
.DESCRIPTION
In this modular version of Mal-Seine, Kansa looks for a modules.conf
file in the -Modules directory. If one is found, it will control which 
modules execute and in what order. If no modules.conf is found, all 
modules will be executed in the order that ls reads them.

After parsing modules.conf or the -Modules path, Kansa will execute
each module on each target (remote hosts) and write the output to a
folder named for each module in the -Output path. Each target will have
its data written to separate files.

For example, the Get-PrefetchListing.ps1 module data will be written
to Output_timestamp\PrefetchListing\Hostname-PrefetchListing.txt.

If a module returns Powershell objects, its data can be written out in
one of several file formats, including csv, tsv and xml. Modules that
return objects should specify how they want Kansa to handle their 
output via an OUTPUT directive in the .SYNOPSIS .NOTES section.

Directives must appear on a line by themselves, must begin the line
and must be written in all capital letters. Here's an example:

OUTPUT tsv

This directive, instructs Kansa to treat the data returned by the 
given module as tab separated values and the data will be saved
to disk accordingly.

Modules that don't include an OUPUT directive will have their data
treated as text.

There are a few special OUTPUT directives: bin, zip and Default.
OUPUT bin would be used for binary data (i.e. memory dumps)
OUTPUT zip would be used for zip files, modules must compress the
data themselves, Kansa.ps1 will not do the compression. The default
module template includes code for compressing data and is meant to
serve as a reference.
OUTPUT Default should be used to let Powershell auto-detect the data
type and treat it accordingly.


Kansa.ps1 was written to avoid the need for CredSSP, therefore 
"second-hops" must be avoided. For more details on this see:

http://trustedsignal.blogspot.com/2014/04/kansa-modular-live-response-tool-for.html

The script assumes you will have administrator level privileges on
target hosts, though such privileges may not be required by all 
modules.

If you run this script without the -TargetList argument, Remote Server
Administration Tools (RSAT), is required. These are available from 
Microsoft's Download Center for Windows 7 and 8. You can search for 
RSAT at:

http://www.microsoft.com/en-us/download/default.aspx

.PARAMETER ModulePath
An optional parameter, default value is .\Modules\, that specifies the
path to the collector modules or a specific module. Spaces in the path 
are not supported, however, ModulePath may point directly to a specific 
module and if that module takes a parameter, you should have a space 
between the path to the script and its first argument, put the whole 
thing in quotes. See example.
This parameter will eventually be deprecated and the module path will
be hardcoded to .\Modules\. A new parameter will be added for 
specifying a single module from the command line.
.PARAMETER TargetList
An optional argument, the name of a file containing a list of servers 
from the current forest to collect data from.
PARAMETER Target
An optional argument, the name of a single system to collect data from.
.PARAMETER TargetCount
An optional parameter that specifies the maximum number of targets.

In the absence of the TargetList and / or Target arguments, Kansa will 
use Remote System Administration Tools (a separate installed package) 
to query Active Directory and will build a list of hosts to target 
automatically.

.PARAMETER Credential
An optional credential that the script will use for execution. Use the
$Credential = Get-Credential convention to populate a suitable variable.
.PARAMETER Pushbin
An optional flag that causes Kansa to push required binaries to the 
ADMIN$ shares of targets. Modules that require third-party binaries, 
must include the "BINDEP <binary>" directive.

For example, the Get-Autorunsc.ps1 collector has a binary dependency on
Sysinternals Autorunsc.exe. The Get-Autorunsc.ps1 collector contains a
special line called a "directive" that instructs Kansa.ps1 to copy the
Autorunsc.exe binary to remote systems when called with -Pushbin.

Kansa does not ship with third-party binaries. Users must place them in
the Modules\bin\ path and the BINDEP directive should reference the 
binary via its path relative to Kansa.ps1.

Directives should be placed in module's .SYNOPSIS sections under .NOTES
    * Directives must appear on a line by themselves
    * Directives must start the line 
    # Directives must be in all capital letters

For example, the directive for Get-Autorunsc.ps1 as of this writing is
BINDEP .\Modules\bin\Autorunsc.exe

If your required binaries are already present on each target and in the 
path where the modules expect them to be, you can omit the -Pushbin 
flag and save the step of copying binaries.
.PARAMETER Rmbin
An optional switch for removing binaries that may have been pushed to
remote hosts via -Pushbin either on this run, or during a previous run.
.PARAMETER Ascii
An optional switch that tells Kansa you want all text output (i.e. txt,
csv and tsv) and errors be written as Ascii. Unicode is the default.
.PARAMETER UpdatePath
An option switch that adds Analysis script paths to the user's path and
then exits. Kansa will automatically add Analysis script paths to the 
user's path when run normally, this switch is just for convenience when
coming back to the data for analysis.
.PARAMETER ListModules
An optional switch that lists the available modules. Useful for
constructing a modules.conf file. Kansa exits after listing.
You'll likely want to sort the according to the order of volatility.
.PARAMETER ListAnalysis
An optional switch that lists the available analysis scripts. Useful 
for constructing an analysis.conf file. Kansa exits after listing. If 
you use this switch to build an analysis.conf file, you'll likely want 
to edit the list so you're only running the analysis scripts you want 
to run.
.PARAMETER Analysis
An optional switch that causes Kansa to run automated analysis based on
the contents of the Analysis\Analysis.conf file.
.PARAMETER Transcribe
An optional flag that causes Start-Transcript to run at the start
of the script, writing to $OutputPath\yyyyMMddhhmmss.log
.PARAMETER Quiet
An optional flag that overrides Kansa's default of running with -Verbose.
.INPUTS
None
You cannot pipe objects to this cmdlet
.OUTPUTS
Various and sundry.
.NOTES
In the absence of a configuration file, specifying which modules to run, 
this script will run each module across all hosts.

Each module should return objects, ideally, though text is supported. 
See the discussion above about OUTPUT formats.

Because modules should only COLLECT data from remote hosts, their 
filenames must begin with "Get-". Examples:
Get-PrefetchListing.ps1
Get-Netstat.ps1

Any module not beginning with "Get-" will be ignored.

Note this read-only aspect is unenforced, therefore Kansa can be used 
to make changes to remote hosts. As a result, it can be used to 
facilitate remediation.

The script can take a list of targets, read from a text file, via the
-TargetList <file> argument. You may also supply the -TargetCount 
argument to limit how many hosts will be targeted. To target a single
host, use the -Target <hostname> argument.

In the absence of the -TargetList or -Target arguments, Kansa.ps1 will
query Acitve Directory for a complete list of hosts and will attempt to
target all of them. 

.EXAMPLE
Kansa.ps1
In the above example the user has specified no arguments, which will
cause Kansa to run modules per the .\Modules\Modules.conf file against
a list of hosts that it is able to query from Active Directory. Errors
and all output will be written to a timestamped output directory. If
.\Modules\Modules.conf is not found, all ps1 scripts starting with Get-
under the .\Modules\ directory (recursively) will be run.
.EXAMPLE
Kansa.ps1 -TargetList hosts.txt -Credential $Credential -Transcribe
In this example the user has specified a list of hosts to target, a 
user credential under which to execute. The -Transcribe flag is also
supplied, causing all script output to be written to a transcript. By
default, the script will also output verbose runstate information.
.EXAMPLE
Kansa.ps1 -ModulePath ".\Modules\Disk\Get-File.ps1 C:\Windows\WindowsUpdate.log" -Target HHWWSQL01
In this example -ModulePath refers to a specific module that takes a 
positional parameter (only positional parameters are supported) and the
script is being run against a single target.
.EXAMPLE
Kansa.ps1 -TargetList hostlist -Analysis
Runs collection according to the configuration in Modules\Modules.conf.
Following collection, runs analysis scripts per Analysis\Analysis.conf.
.EXAMPLE
Kansa.ps1 -ListModules
Returns a list of all the modules found under the default modules path.
.EXAMPLE
Kansa.ps1 -ListAnalysis
Returns a list of all analysis scripts found under the Analysis path.
#>

[CmdletBinding()]
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ModulePath="Modules\",
    [Parameter(Mandatory=$False,Position=1)]
        [String]$TargetList=$Null,
    [Parameter(Mandatory=$False,Position=2)]
        [String]$Target=$Null,
    [Parameter(Mandatory=$False,Position=3)]
        [int]$TargetCount=0,
    [Parameter(Mandatory=$False,Position=4)]
        [System.Management.Automation.PSCredential]$Credential=$Null,
    [Parameter(Mandatory=$False,Position=5)]
        [Switch]$Pushbin,
    [Parameter(Mandatory=$False,Position=6)]
        [Switch]$Rmbin,
    [Parameter(Mandatory=$False,Position=7)]
        [Int]$ThrottleLimit=0,
    [Parameter(Mandatory=$False,Position=8)]
        [Switch]$Ascii,
    [Parameter(Mandatory=$False,Position=9)]
        [Switch]$UpdatePath,
    [Parameter(Mandatory=$False,Position=10)]
        [Switch]$ListModules,
    [Parameter(Mandatory=$False,Position=11)]
        [Switch]$ListAnalysis,
    [Parameter(Mandatory=$False,Position=12)]
        [Switch]$Analysis,
    [Parameter(Mandatory=$False,Position=13)]
        [Switch]$Transcribe,
    [Parameter(Mandatory=$False,Position=14)]
        [Switch]$Quiet=$False
)

# Opening with a Try so the Finally block at the bottom will always call
# the Exit-Script function and clean up things as needed.
# Saw this cause an issue in an environment with PSv2. If you run into
# an issue where the script is exiting without really doing anything,
# comment out this and the Finally a the botom of the script, the error
# handling, won't be as robust, but the script should work.
Try {

# Long paths prevent data from being written, this is used to test their length
# Per http://msdn.microsoft.com/en-us/library/aa365247.aspx#maxpath, maximum
# path length should be 260 characters. We set it to 241 here to account for
# max computername length of 15 characters, it's part of the path, plus a 
# hyphen separator and a dot-three extension.
# extension -- 260 - 19 = 241.
Set-Variable -Name MAXPATH -Value 241 -Option Constant

# Since Kansa provides so much useful information through Write-Vebose, we
# want it to run with that flag enabled by default. This behavior can be
# overridden by passing the -Quiet flag. This is scoped only to this context,
# so we don't need to reset it when we're done.
if(!$Quiet) {
    $VerbosePreference = "Continue"
}

function FuncTemplate {
<#
.SYNOPSIS
Default function template, copy when making new function
#>
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$ParamTemplate=$Null
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    Try { 
        <# 
        Try/Catch blocks are for terminating errors. See some of the
        functions below for examples of how non-terminating errors can 
        be caught and handled. 
        #>
    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}
<# End FuncTemplate #>

function Exit-Script {
<#
.SYNOPSIS
Exit the script somewhat gracefully, closing any open transcript.
#>
    Set-Location $StartingPath
    if ($Transcribe) {
        $Suppress = Stop-Transcript
    }

    if ($Error) {
        "Exit-Script function was passed an error, this may be a duplicate that wasn't previously cleared, or Kansa.ps1 has crashed." | Add-Content -Encoding $Encoding $ErrorLog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    if (Test-Path($ErrorLog)) {
        Write-Output "Script completed with warnings or errors. See ${ErrorLog} for details."
    }

    if (!(Get-ChildItem $OutputPath)) {
        # $OutputPath is empty, nuke it
        "Output path was created, but Kansa finished with no hits, no runs and no errors. Nuking the folder."
        $suppress = Remove-Item $OutputPath -Force
    }

    Exit
}

function Get-Modules {
<#
.SYNOPSIS
Looks for modules.conf in the $Modulepath, default is Modules. If found,
returns an ordered hashtable of script files and their arguments, if any. 
If no modules.conf is found, returns an ordered hashtable of all modules
found in $Modulepath, but no arguments will be present so scripts will
run with default params. A module is a .ps1 script starting with Get-.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$ModulePath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    Write-Debug "`$ModulePath is ${ModulePath}."

    # User may have passed a full path to a specific module, posibly with an argument
    $ModuleScript = ($ModulePath -split " ")[0]
    $ModuleArgs   = @($ModulePath -split [regex]::escape($ModuleScript))[1].Trim()

    $Modules = $FoundModules = @()
    # Need to maintain the order for "order of volatility"
    $ModuleHash = New-Object System.Collections.Specialized.OrderedDictionary

    if ((ls $ModuleScript -ErrorAction SilentlyContinue).PSIsContainer -eq $False) {
        # User may have provided full path to a .ps1 module, which is how you run a single module explicitly
        $ModuleHash.Add((ls $ModuleScript), $ModuleArgs)

        if (Test-Path($ModuleScript)) {
            $Module = ls $ModuleScript | Select-Object -ExpandProperty BaseName
            Write-Verbose "Running module: `n$Module $ModuleArgs"
            Return $ModuleHash
        }
    }
    $ModConf = $ModulePath + "\" + "Modules.conf"
    if (Test-Path($Modconf)) {
        Write-Verbose "Found ${ModulePath}\Modules.conf."
        # ignore blank and commented lines, trim misc. white space
        $Modules = Get-Content $ModulePath\Modules.conf | % { $_.Trim() } | ? { $_ -gt 0 -and (!($_.StartsWith("#"))) }
        foreach ($Module in $Modules) {
            # verify listed modules exist
            $ModuleScript = ($Module -split " ")[0]
            $ModuleArgs   = ($Module -split [regex]::escape($ModuleScript))[1].Trim()
            $Modpath = $ModulePath + "\" + $ModuleScript
            if (!(Test-Path($Modpath))) {
                "WARNING: Could not find module specified in ${ModulePath}\Modules.conf: $ModuleScript. Skipping." | Add-Content -Encoding $Encoding $ErrorLog
            } else {
                # module found add it and its arguments to the $ModuleHash
                $ModuleHash.Add((ls $ModPath), $Moduleargs)
                # $FoundModules += ls $ModPath # deprecated code, remove after testing
            }
        }
        # $Modules = $FoundModules # deprecated, remove after testing
    } else {
        # we had no modules.conf
        foreach($Module in (ls -r $ModulePath\Get-*.ps1)) {
            $ModuleHash.Add($Module, $null)
        }
    }
    Write-Verbose "Running modules:`n$(($ModuleHash.Keys | Select-Object -ExpandProperty BaseName) -join "`n")"
    $ModuleHash
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Load-AD {
    # no targets provided so we'll query AD to build it, need to load the AD module
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    if (Get-Module -ListAvailable | ? { $_.Name -match "ActiveDirectory" }) {
        $Error.Clear()
        Import-Module ActiveDirectory
        if ($Error) {
            "ERROR: Could not load the required Active Directory module. Please install the Remote Server Administration Tool for AD. Quitting." | Add-Content -Encoding $Encoding $ErrorLog
            $Error.Clear()
            Exit
        }
    } else {
        "ERROR: Could not load the required Active Directory module. Please install the Remote Server Administration Tool for AD. Quitting." | Add-Content -Encoding $Encoding $ErrorLog
        Exit
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Get-Forest {
    # what forest are we in?
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    $Forest = (Get-ADForest).Name

    if ($Forest) {
        Write-Verbose "Forest is ${forest}."
        $Forest
    } elseif ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        "ERROR: Get-Forest could not find current forest. Quitting." | Add-Content -Encoding $Encoding $ErrorLog
        Exit
    }
}

function Get-Targets {
Param(
    [Parameter(Mandatory=$False,Position=0)]
        [String]$TargetList=$Null,
    [Parameter(Mandatory=$False,Position=1)]
        [int]$TargetCount=0
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    $Targets = $False
    if ($TargetList) {
        # user provided a list of targets
        if ($TargetCount -eq 0) {
            $Targets = Get-Content $TargetList | % { $_.Trim() } | Where-Object { $_.Length -gt 0 }
        } else {
            $Targets = Get-Content $TargetList | % { $_.Trim() } | Where-Object { $_.Length -gt 0 } | Select-Object -First $TargetCount
        }
    } else {
        # no target list provided, we'll query AD for it
        Write-Verbose "`$TargetCount is ${TargetCount}."
        if ($TargetCount -eq 0 -or $TargetCount -eq $Null) {
            $Targets = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name 
        } else {
            $Targets = Get-ADComputer -Filter * -ResultSetSize $TargetCount | Select-Object -ExpandProperty Name
        }
    }

    if ($Targets) {
        Write-Verbose "`$Targets are ${Targets}."
        return $Targets
    } else {
        Write-Verbose "Get-Targets function found no targets. Checking for errors."
    }
    
    if ($Error) { # if we make it here, something went wrong
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        "ERROR: Get-Targets function could not get a list of targets. Quitting."
        Exit
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Get-LegalFileName {
<#
.SYNOPSIS
Returns argument with illegal filename characters removed.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$Argument
)
    Write-Debug "Entering ($MyInvocation.MyCommand)"
    $Argument = $Arguments -join ""
    $Argument -replace [regex]::Escape("\") -replace [regex]::Escape("/") -replace [regex]::Escape(":") `
        -replace [regex]::Escape("*") -replace [regex]::Escape("?") -replace "`"" -replace [regex]::Escape("<") `
        -replace [regex]::Escape(">") -replace [regex]::Escape("|") -replace " "
}

function Get-Directives {
<#
.SYNOPSIS
Returns a hashtable of directives found in the script
As of this writing it will support both the legacy directives on the first two
lines fo the script and the newer .SYNOPSIS/.NOTES based directives. After all
collectors have been updated to use the newer method, the old code will be
removed.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Module,
    [Parameter(Mandatory=$False,Position=1)]
        [Switch]$AnalysisPath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    if ($AnalysisPath) {
        $Module = ".\Analysis\" + $Module
    }

    if (Test-Path($Module)) {
        
        $DirectiveHash = @{}

        $Directives = Get-Content $Module | Select-String -CaseSensitive -Pattern "OUTPUT|BINDEP|DATADIR"
        foreach ($Directive in $Directives) {
            if ( $Directive -match "(^OUTPUT|^# OUTPUT) (.*)" ) {
                $DirectiveHash.Add("OUTPUT", $($matches[2]))
            }
            if ( $Directive -match "(^BINDEP|^# BINDEP) (.*)" ) {
                $DirectiveHash.Add("BINDEP", $($matches[2]))
            }
            if ( $Directive -match "(^DATADIR|^# DATADIR) (.*)" ) {
                $DirectiveHash.Add("DATADIR", $($matches[2])) 
            }
        }
        $DirectiveHash
    } else {
        "WARNING: Get-Directives was passed invalid module $Module." | Add-Content -Encoding $Encoding $ErrorLog
    }
}


function Get-TargetData {
<#
.SYNOPSIS
Runs each module against each target. Writes out the returned data to host where Kansa is run from.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$Targets,
    [Parameter(Mandatory=$True,Position=1)]
        [System.Collections.Specialized.OrderedDictionary]$Modules,
    [Parameter(Mandatory=$False,Position=2)]
        [System.Management.Automation.PSCredential]$Credential=$False,
    [Parameter(Mandatory=$False,Position=3)]
        [Int]$ThrottleLimit
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()

    # Create our sessions with targets
    if ($Credential) {
        $PSSessions = New-PSSession -ComputerName $Targets -SessionOption (New-PSSessionOption -NoMachineProfile) -Credential $Credential
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    } else {
        $PSSessions = New-PSSession -ComputerName $Targets -SessionOption (New-PSSessionOption -NoMachineProfile)
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    foreach($Module in $Modules.Keys) {
        $ModuleName  = $Module | Select-Object -ExpandProperty BaseName
        $Arguments   = @()
        $Arguments   += $($Modules.Get_Item($Module)) -split ","
        if ($Arguments) {
            $ArgFileName = Get-LegalFileName $Arguments
        } else { $ArgFileName = "" }
            
        # Get our directives both old and new style
        $DirectivesHash  = @{}
        $DirectivesHash = Get-Directives $Module
        $OutputMethod = $($DirectivesHash.Get_Item("OUTPUT"))
        if ($Pushbin) {
            $bindep = $($DirectivesHash.Get_Item("BINDEP"))
            if ($bindep) {
                Push-Bindep -Targets $Targets -Module $Module -Bindep $bindep -Credential $Credential
            }
        }
            
        # run the module on the targets            
        if ($Arguments) {
            Write-Debug "Invoke-Command -Session $PSSessions -FilePath $Module -ArgumentList `"$Arguments`" -AsJob -ThrottleLimit $ThrottleLimit"
            $Job = Invoke-Command -Session $PSSessions -FilePath $Module -ArgumentList $Arguments -AsJob -ThrottleLimit $ThrottleLimit
            Write-Verbose "Waiting for $ModuleName $Arguments to complete."
        } else {
            Write-Debug "Invoke-Command -Session $PSSessions -FilePath $Module -AsJob -ThrottleLimit $ThrottleLimit"
            $Job = Invoke-Command -Session $PSSessions -FilePath $Module -AsJob -ThrottleLimit $ThrottleLimit                
            Write-Verbose "Waiting for $ModuleName to complete."
        }
        # Wait-Job does return data to stdout, add $suppress = to start of next line, if needed
        Wait-Job $Job
            
        # set up our output location
        $GetlessMod = $($ModuleName -replace "Get-") 
        # Long paths prevent output from being written, so we truncate $ArgFileName to accomodate
        # We're estimating the output path because at this point, we don't know what the hostname
        # is and it is part of the path. Hostnames are 15 characters max, so we assume worst case
        $EstOutPathLength = $OutputPath.Length + ($GetlessMod.Length * 2) + ($ArgFileName.Length * 2)
        if ($EstOutPathLength -gt $MAXPATH) { 
            # Get the path length without the arguments, then we can determine how long $ArgFileName can be
            $PathDiff = [int] $EstOutPathLength - ($OutputPath.Length + ($GetlessMod.Length * 2) -gt 0)
            $MaxArgLength = $PathDiff - $MAXPATH
            if ($MaxArgLength -gt 0 -and $MaxArgLength -lt $ArgFileName.Length) {
                $OrigArgFileName = $ArgFileName
                $ArgFileName = $ArgFileName.Substring(0, $MaxArgLength)
                "WARNING: ${GetlessMod}'s output path contains the arguments that were passed to it. Those arguments were truncated from $OrigArgFileName to $ArgFileName to accomodate Window's MAXPATH limit of 260 characters." | Add-Content -Encoding $Encoding $ErrorLog
            }
        }
                            
        $Suppress = New-Item -Path $OutputPath -name ($GetlessMod + $ArgFileName) -ItemType Directory
        foreach($ChildJob in $Job.ChildJobs) { 
            $Recpt = Receive-Job $ChildJob
            
            # Log errors from child jobs, including module and host that failed.
            if($Error) {
                $ModuleName + " reports error on " + $ChildJob.Location + ": `"" + $Error + "`"" | Add-Content -Encoding $Encoding $ErrorLog
                $Error.Clear()
            }

            # Now that we know our hostname, let's double check our path length, if it's too long, we'll write an error
            # Max path is 260 characters, if we're over 256, we can't accomodate an extension
            $Outfile = $OutputPath + $GetlessMod + $ArgFileName + "\" + $ChildJob.Location + "-" + $GetlessMod + $ArgFileName
            if ($Outfile.length -gt 256) {
                "ERROR: ${GetlessMod}'s output path length exceeds 260 character limit. Can't write the output to disk for $($ChildJob.Location)." | Add-Content -Encoding $Encoding $ErrorLog
                Continue
            }

            # save the data
            switch -Wildcard ($OutputMethod) {
                "*csv" {
                    $Outfile = $Outfile + ".csv"
                    $Recpt | ConvertTo-Csv -NoTypeInformation | % { $_ -replace "`"" } | Set-Content -Encoding $Encoding $Outfile
                }
                "*tsv" {
                    $Outfile = $Outfile + ".tsv"
                    $Recpt | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`"" } | Set-Content -Encoding $Encoding $Outfile
                }
                "*xml" {
                    $Outfile = $Outfile + ".xml"
                    $Recpt | Export-Clixml $Outfile -Encoding $Encoding
                }
                "*bin" {
                    $Outfile = $Outfile + ".bin"
                    $Recpt | Set-Content -Encoding Byte $Outfile
                }
                "*zip" {
                    # Compression should be done in the collector
                    # Default collector template has a function
                    # for compressing data as an example
                    $Outfile = $Outfile + ".zip"
                    $Recpt | Set-Content -Encoding Byte $Outfile
                }
                "*Default" {
                    # Default here means we let PowerShell figure out the output encoding
                    # Used by Get-File.ps1, which can grab arbitrary files
                    $Outfile = $Outfile
                    $Recpt | Set-Content -Encoding Default $Outfile
                }
                default {
                    $Outfile = $Outfile + ".txt"
                    $Recpt | Set-Content -Encoding $Encoding $Outfile
                }
            }
        }

        # Release memory reserved for Job data since we don't need it any more.
        # Fixes bug number 73.
        Remove-Job $Job

        if ($rmbin) {
            if ($bindep) {
                Remove-Bindep -Targets $Targets -Module $Module -Bindep $bindep -Credential $Credential
            }
        }

    }
    Remove-PSSession $PSSessions
    $Error | Add-Content -Encoding $Encoding $ErrorLog
    $Error.Clear()
    
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function Push-Bindep {
<#
.SYNOPSIS
Attempts to copy required binaries to targets.
If a module depends on an external binary, the binary should be copied 
to .\Modules\bin\ and the module should reference the binary in the 
.NOTES section of the .SYNOPSIS as follows:
BINDEP .\Modules\bin\autorunsc.exe

!! This directive is case-sensitve and must start the line !!

Some Modules may require multiple binary files, say an executable and 
required dlls. See the .\Modules\Disk\Get-FlsBodyFile.ps1 as an 
example. The BINDEP line in that module references 
.\Modules\bin\fls.zip. Kansa will copy that zip file to the targets, 
but the module itself handles the unzipping of the fls.zip file.

BINDEP must include the path to the binary, relative to Kansa.ps1's 
path.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$Targets,
    [Parameter(Mandatory=$True,Position=1)]
        [String]$Module,
    [Parameter(Mandatory=$True,Position=2)]
        [String]$Bindep,
    [Parameter(Mandatory=$False,Position=3)]
        [System.Management.Automation.PSCredential]$Credential
        
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    Write-Verbose "${Module} has dependency on ${Bindep}."
    if (-not (Test-Path("$Bindep"))) {
        Write-Verbose "${Bindep} not found in ${ModulePath}bin, skipping."
        "WARNING: ${Bindep} not found in ${ModulePath}\bin, skipping." | Add-Content -Encoding $Encoding $ErrorLog
        Continue
    }
    Write-Verbose "Attempting to copy ${Bindep} to targets..."
    foreach($Target in $Targets) {
        if ($Credential) {
            $suppress = New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$" -Credential $Credential
            Copy-Item "$Bindep" "KansaDrive:"
            $suppress = Remove-PSDrive -Name "KansaDrive"
        } else {
            $suppress = New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$"
            Copy-Item "$Bindep" "KansaDrive:"
            $suppress = Remove-PSDrive -Name "KansaDrive"
        }
    
        if ($Error) {
            "WARNING: Failed to copy ${Bindep} to ${Target}." | Add-Content -Encoding $Encoding $ErrorLog
            $Error | Add-Content -Encoding $Encoding $ErrorLog
            $Error.Clear()
        }
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}


function Remove-Bindep {
<#
.SYNOPSIS
Attempts to remove binaries from targets when Kansa.ps1 is run with 
-rmbin switch.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [Array]$Targets,
    [Parameter(Mandatory=$True,Position=1)]
        [String]$Module,
    [Parameter(Mandatory=$True,Position=2)]
        [String]$Bindep,
    [Parameter(Mandatory=$False,Position=3)]
        [System.Management.Automation.PSCredential]$Credential
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    $Bindep = $Bindep.Substring($Bindep.LastIndexOf("\") + 1)
    Write-Verbose "Attempting to remove ${Bindep} from remote hosts."
    foreach($Target in $Targets) {
        if ($Credential) {
            $suppress = New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$" -Credential $Credential
            Remove-Item "KansaDrive:\$Bindep" 
            $suppress = Remove-PSDrive -Name "KansaDrive"
        } else {
            $suppress = New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$"
            Remove-Item "KansaDrive:\$Bindep"
            $suppress = Remove-PSDrive -Name "KansaDrive"
        }
        
        if ($Error) {
            "WARNING: Failed to remove ${Bindep} to ${Target}." | Add-Content -Encoding $Encoding $ErrorLog
            $Error | Add-Content -Encoding $Encoding $ErrorLog
            $Error.Clear()
        }
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function List-Modules {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$ModulePath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()

    foreach ($dir in (ls $ModulePath)) {
        if ($dir.PSIsContainer -and $dir.name -ne "bin" -and $dir.name -ne "Private") {
            foreach($file in (ls $ModulePath\$dir\Get-*)) {
                $($dir.Name + "\" + (split-path -leaf $file))
            }
        } else {
            foreach($file in (ls $ModulePath\Get-*)) {
                $file.Name
            }
        }
    }
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function Set-KansaPath {
    # Update the path to inlcude Kansa analysis script paths, if they aren't already
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $kansapath = Split-Path $Invocation.MyCommand.Path
    $found = $False
    foreach($path in ($env:path -split ";")) {
        if ([regex]::escape($kansapath) -match [regex]::escape($path)) {
            $found = $True
        }
    }
    if (-not($found)) {
        $env:path = $env:path + ";$pwd\Analysis\ASEP;$pwd\Analysis\Config;$pwd\Analysis\Meta;$pwd\Analysis\Net;$pwd\Analysis\Process;$pwd\Analysis\Log;"
    }
}


function Get-Analysis {
<#
.SYNOPSIS
Runs analysis scripts as specified in .\Analyais\Analysis.conf
Saves output to AnalysisReports folder under the output path
Fails silently, but logs errors to Error.log file
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$OutputPath,
    [Parameter(Mandatory=$True,Position=1)]
        [String]$StartingPath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()

    if (Get-Command -Name Logparser.exe) {
        $AnalysisScripts = @()
        $AnalysisScripts = Get-Content "$StartingPath\Analysis\Analysis.conf" | % { $_.Trim() } | ? { $_ -gt 0 -and (!($_.StartsWith("#"))) }

        $AnalysisOutPath = $OutputPath + "\AnalysisReports\"
        $Suppress = New-Item -Path $AnalysisOutPath -ItemType Directory -Force

        # Get our DATADIR directive
        $DirectivesHash  = @{}
        foreach($AnalysisScript in $AnalysisScripts) {
            $DirectivesHash = Get-Directives $AnalysisScript -AnalysisPath
            $DataDir = $($DirectivesHash.Get_Item("DATADIR"))
            if ($DataDir) {
                if (Test-Path "$OutputPath$DataDir") {
                    Push-Location
                    Set-Location "$OutputPath$DataDir"
                    Write-Verbose "Running analysis script: ${AnalysisScript}"
                    $AnalysisFile = ((((($AnalysisScript -split "\\")[1]) -split "Get-")[1]) -split ".ps1")[0]
                    # As of this writing, all analysis output files are tsv
                    & "$StartingPath\Analysis\${AnalysisScript}" | Set-Content -Encoding $Encoding ($AnalysisOutPath + $AnalysisFile + ".tsv")
                    Pop-Location
                } else {
                    "WARNING: Analysis: No data found for ${AnalysisScript}." | Add-Content -Encoding $Encoding $ErrorLog
                    Continue
                }
            } else {
                "WARNING: Analysis script, .\Analysis\${AnalysisScript}, missing # DATADIR directive, skipping analysis." | Add-Content -Encoding $Encoding $ErrorLog
                Continue
            }        
        }
    } else {
        "Kansa could not find logparser.exe in path. Skipping Analysis." | Add-Content -Encoding $Encoding -$ErrorLog
    }
    # Non-terminating errors can be checked via
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
} # End Get-Analysis


# Do not stop or report errors as a matter of course.   #
# Instead write them out the error.log file and report  #
# that there were errors at the end, if there were any. #
$Error.Clear()
$ErrorActionPreference = "SilentlyContinue"
$StartingPath = Get-Location | Select-Object -ExpandProperty Path

# Create timestamped output path. Write transcript and error log #
# to output path. Keep this first in the script so we can catch  #
# errors in the error log of the output directory. We may create #
$Runtime = ([String] (Get-Date -Format yyyyMMddHHmmss))
$OutputPath = $StartingPath + "\Output_$Runtime\"
$Suppress = New-Item -Path $OutputPath -ItemType Directory -Force 

If ($Transcribe) {
    $TransFile = $OutputPath + ([string] (Get-Date -Format yyyyMMddHHmmss)) + ".log"
    $Suppress = Start-Transcript -Path $TransFile
}
Set-Variable -Name ErrorLog -Value ($OutputPath + "Error.Log") -Scope Script

if (Test-Path($ErrorLog)) {
    Remove-Item -Path $ErrorLog
}
# Done setting up output. #


# Set the output encoding #
if ($Ascii) {
    Set-Variable -Name Encoding -Value "Ascii" -Scope Script
} else {
    Set-Variable -Name Encoding -Value "Unicode" -Scope Script
}
# End set output encoding #


# Sanity check some parameters #
Write-Debug "Sanity checking parameters"
$Exit = $False
if ($TargetList -and -not (Test-Path($TargetList))) {
    "ERROR: User supplied TargetList, $TargetList, was not found." | Add-Content -Encoding $Encoding $ErrorLog
    $Exit = $True
}
if ($TargetCount -lt 0) {
    "ERROR: User supplied TargetCount, $TargetCount, was negative." | Add-Content -Encoding $Encoding $ErrorLog
    $Exit = $True
}
#TKTK Add test for $Credential
if ($Exit) {
    "ERROR: One or more errors were encountered with user supplied arguments. Exiting." | Add-Content -Encoding $Encoding $ErrorLog
    Exit
}
Write-Debug "Parameter sanity check complete."
# End paramter sanity checks #


# Update the user's path with Kansa Analysis paths. #
# Exit if that's all they wanted us to do.          #
Set-KansaPath
if ($UpdatePath) {
    # User provided UpdatePath switch so
    # exit after updating the path
    Exit
}
# Done updating the path. #


# If we're -Debug, show some settings. #
Write-Debug "`$ModulePath is ${ModulePath}."
Write-Debug "`$OutputPath is ${OutputPath}."
Write-Debug "`$ServerList is ${TargetList}."


# Get our modules #
if ($ListModules) {
    # User provided ListModules switch so exit
    # after returning the full list of modules
    List-Modules ".\Modules\"
    Exit
}
# Get-Modules reads the modules.conf file, if
# it exists, otherwise will have same data as
# List-Modules command above.
$Modules = Get-Modules -ModulePath $ModulePath
# Done getting modules #


# Get our analysis scripts #
if ($ListAnalysis) {
    # User provided ListAnalysis switch so exit
    # after returning a list of analysis scripts
    List-Modules ".\Analysis\"
    Exit
}


# Get our targets. #
if ($TargetList) {
    $Targets = Get-Targets -TargetList $TargetList -TargetCount $TargetCount
} elseif ($Target) {
    $Targets = $Target
} else {
    Write-Verbose "No Targets specified. Building one requires RAST and will take some time."
    $suppress = Load-AD
    $Targets  = Get-Targets -TargetCount $TargetCount
}
# Done getting targets #


# Finally, let's gather some data. #
Get-TargetData -Targets $Targets -Modules $Modules -Credential $Credential -ThrottleLimit $ThrottleLimit
# Done gathering data. #

# Are we running analysis scripts? #
if ($Analysis) {
    Get-Analysis $OutputPath $StartingPath
}
# Done running analysis #


# Code to remove binaries from remote hosts
if ($rmbin) {
    Remove-Bindep -Targets $Targets -Modules $Modules -Credential $Credential
}
# Done removing binaries #


# Clean up #
Exit
# We're done. #

# On some PSv2 systems, the outer Try/Finally caused issues. Commenting
# this out fixed it.
} Finally {
    Exit-Script
}
