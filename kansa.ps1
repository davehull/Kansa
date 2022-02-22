<#
.SYNOPSIS
Kansa is a Powershell based incident response framework for Windows 
environments.
"Improvements" have been made by adding two additional output formats: 
GL and SPLUNK.  Both allow the user to route data output to a GrayLog 
or Splunk instance respectively, while also writing the output to JSON 
files in a manner similar to the default JSON output format.
.CONFIGURATION
In order to use the GL and SPLUNK output formats, the user needs to configure
the appropriate OutputFormat parameter for their specific receiving system's 
configuration - this is done in logging.conf, which must reside in the same
directory as kansa.ps1. If you want to move logging.conf, edit the appropriate
line(s) in the Get-LoggingConf function (somewhere around line 445).
For GrayLog output, the facility parameter in the message body should be 
configured by the user... Unless the user is fine with the pre-defined facility.
.DESCRIPTION
Kansa is a modular, PowerShell based incident response framework for
Windows environments that have Windows Remote Management enabled.
Kansa looks for a modules.conf file in the .\Modules directory. If one
is found, it controls which modules execute and in what order. If no 
modules.conf is found, all modules will be executed in the order that 
ls reads them.
After parsing modules.conf or the -ModulesPath parameter argument, 
Kansa will execute each module on each target (remote host) and 
write the output to a folder named for each module in a time stamped
output path. Each target will have its data written to separate files.
For example, the Get-PrefetchListing.ps1 module data will be written
to Output_timestamp\PrefetchListing\Hostname-PrefetchListing.txt.
All modules should return Powershell objects. Kansa converts those
objects into one of several file formats, including csv, json, tsv and
xml. The default output format is csv. Kansa's user may specify 
alternate output formats at the command line via the -OutputFormat 
parameter argument.
Kansa.ps1 was written to avoid the need for CredSSP, therefore 
"second-hops" should be avoided. For more details on this see:
http://trustedsignal.blogspot.com/2014/04/kansa-modular-live-response-tool-for.html
The script assumes you will have administrator level privileges on
target hosts, though such privileges may not be required by all 
modules.
If you run this script without the -TargetList argument, Remote Server
Administration Tools (RSAT), is required. These are available from 
Microsoft's Download Center for Windows 7 and 8. You can search for 
RSAT at: http://www.microsoft.com/en-us/download/default.aspx
.PARAMETER ModulePath
An optional parameter, default value is .\Modules\, that specifies the
path to the collector modules or a specific module. Spaces in the path 
are not supported, however, ModulePath may point directly to a specific 
module and if that module takes a parameter, you should have a space 
between the path to the script and its first argument, put the whole 
thing in quotes. See example.
.PARAMETER TargetList
An optional parameter, the name of a file containing a list of servers 
to collect data from. If these hosts are outside the current forest, 
fully qualified domain names are required. In general, it is advised to
use FQDNs.
.PARAMETER Target
An optional parameter, the name of a single system to collect data from.
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
For example, the Get-AutorunscDeep.ps1 collector has a dependency on
Sysinternals Autorunsc.exe. The Get-AutorunscDeep.ps1 collector 
contains a special line called a "directive" that instructs Kansa.ps1
to copy the Autorunsc.exe binary to remote systems when called with the
-Pushbin flag. The user executing Kansa is responsible for downloading
any required binaries, they are not distributed with Kansa.
Kansa does not ship with third-party binaries. Conventionally, 
third-party binaries are placed in the .\Modules\bin\ path. The BINDEP
directive should reference the binary via its path relative to 
Kansa.ps1.
Directives should be placed in module's .SYNOPSIS sections under .NOTES
    * Directives must appear on a line by themselves
    * Directives must start the line 
    # Directives must be in all capital letters
For example, the directive for Get-AutorunscDeep.ps1 as of this writing is
BINDEP .\Modules\bin\Autorunsc.exe
If your required binaries are already present on each target and in the 
path where the modules expect them to be, you can omit the -Pushbin 
flag and save the step of copying binaries.
.PARAMETER Rmbin
An optional switch for removing binaries that may have been pushed to
remote hosts via -Pushbin either on this run, or during a previous run.
.PARAMETER Ascii
An optional switch that tells Kansa you want all text output (i.e. txt,
csv and tsv) and errors written as Ascii. Unicode is the default.
.PARAMETER UpdatePath
An optional switch that adds Analysis script paths to the user's path 
and then exits. Kansa will automatically add Analysis script paths to
the user's path when run normally, this switch is for convenience when
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
.PARAMETER UseSSL
An optional flag for use in environments that have authentication
certificates deployed. If this flag is used and certificates are
deployed, connections will be made over HTTPS and will be encrypted.
Without this flag traffic passes in the clear. Note authentication is
done via Kerberos regardless of whether or not SSL is used. Alternate
authentication methods are available via the -Authentication parameter
argument.
.PARAMETER Port
An optional parameter if WinRM is listening on a non-standard port.
.PARAMETER Authentication
An optional parameter specifying what authentication method should be 
used. The default is Kerberos, but that won't work for authenticating
against local administrator accounts or for scenarios with non-domain
joined systems. 
Valid options: Basic, CredSSP, Default, Digest, Kerberos, Negotiate, 
NegotiateWithImplicitCredential.
Whereever possible, you should use Kerberos, some of these options are
considered dangerous, so be careful and read up on the different
methods before using an alternate.
.PARAMETER JSONDepth
An optional parameter specifying how many levels of contained objects
are included in the JSON representation. Default was 10, but has been 
changed to 20.

.PARAMETER AutoParse
Although all modules produce standard output (csv, tsv, json), some 
output requires additional processing to be truly useful. Examples of 
this are autoruns and gpresult output. Added by Joseph Kjar

.PARAMETER ElkAlert
This instructs Kansa to forward module results to an ELK listener.
Logstash was used in testing, but any log ingestion service that can
accept raw json TCP or UDP data fed in on one record per line will work. 
The configuration for the listener (IP, port, etc.) is passed into a 
separate script file (ElkSender.ps1). NOTE: Standard Elk listeners expect
to receive JSON-formatted strings. Since Kansa is capable of producing 
output in various formats, be sure to specify JSON output if you wish to 
use this option. ElkAlert requires AutoParse. This variable is an array of 
string IP addresses so you can manually load-balance across multiple 
logstash servers if you don't have a load-balancer or other stream-processing
service like kafka.  The exact IP will be chosen from the supllied array at
random at execution-time.

.PARAMETER JobTimeout
This tells Kansa how long to wait for the current set of jobs to complete
before timing out and proceeding to the next batch (default 10 minutes). 
This parameter is greatly affected by changes to ThrottleLimit, as processing
1000 endpoints concurrently versus 200 will result in much longer job times.
If larger jobs are required, consider lengthening the JobTimeout. This 
parameter should also be modified if any of the modules in use take a 
particularly long time to run (e.g. searching all files on disk). 

.PARAMETER ElkPort
This tells the kansa framework what TCP/UDP port to send the results (output)
and errors for each kansa execution.  Results will still remain cached
locally on the Kansa server if log collection fails.  This variable is an
array of integers so you can manually load-balance across multiple logstash
ingest ports if you don't have a load-balancer or other stream-processing
service like kafka.  The exact port will be chosen from the supllied array at
random at execution-time.

.PARAMETER FireForget
Enabling this flag instructs the kansa framwork to enable the Fire&Forget mode
of operation. Traditional Kansa jobs connect to the target execute the module
scripts and remain connected for the duration of execution to collect the
results and bring them back to the kansa "server" where kansa was invoked. In
Fire&Forget mode, the Kansa  framework connects to each target only long-
enough to spawn an orgphaned child process that contains the complete module
code and then disconnects moving on to the next target.  This improves 
deployment speed and allows for much longer-running modules to be executed, 
but since the server doesn't stick around to get the results each self-
contained module needs to be "patched" with additional functionality to send 
results to a central logging repository upon completion. This extra 
functionality is contained in the FFwrapper module.  On invocation, with this
flag set, Kansa will wrap the module with the FFwrapper code and pass
parameters specified by FFargs through to the new merged module placing the 
resulting dynamically frankensteined module in the FFStagePath folder. Using
the FireForget flag will not work for ANY kansa module at this time since the
output of each module must consist of an array of hashtables. Use the 
FFTemplate.ps1 as a model to follow (or any of the modules in the FireForget
module folder.

.PARAMETER FFwrapper
Specifies the path to the Fire&Forget wrapper ps1 file that will be wrapped
around are Fire&Forget standalone kansa module at launch-time to make it
self-contained.  It will add functionality to gather results and send them
to a central logging repository such as ELK. The module code will be placed
inside the wrapper where the #<InsertFireForgetModuleContentsHERE> tag is
located

.PARAMETER FFArgs
This is a hashtable of module-specific parameters that can be passed-thru
to a Fire&Forget Module.  These variables will replace the tag 
#<InsertFireForgetArgumentsHERE> dynamically at launch time.  The key names
will be the name of the variables and the values will be assigned
accordingly. Valid FFarg hashtable types include integers, strings, arrays
(of other valid FFarg types), and even other hashtables.  The function
recursiveFFArgParser will recursively parse the FFarg variable and write 
a variable assignment block at the aforementioned tag at execution time.
Some default values are specified to ensure low-risk defaults for safety
mechanisms in the default FFwrapper.

.PARAMETER FFStagePath
This value specifies the path where Fire&Forget modules that have been 
dynamically spliced together with the FFwrapper and FFargs at runtime.
Upon successful merging of module codebases the finished product that will
be pushed to the target and spawned as an orphaned child process is 
written to the FFStagePath folder. It is left there even after Kansa 
completes its deployment and exits.  This allows analysts/developers to
inspect the resulting code for troubleshooting or to review for accuracy
prior to launch.  At next execution if the merged module still exists it
will be overwritten.

.PARAMETER SafeWord
In some environments Antivirus or Endpoint security products (EDR/EPP)
may do deep inspection of powershell scripts for malware analysis. The
modules contained in the kansa project contain code snippets that could
trigger these detection/prevention mechanisms and neutering a kansa job
meant to conduct threat-hunting or incident response. This is especially
true of Fire&Forget modules which use many shady-looking techniques to
compress/encode large powershell scripts into small blocks that can be
passed via WMi API calls to spawn an orphaned child process running with
elevated privileges.  In order to ensure success, an org may choose to
whitelist processes that use a safeword. For security, this safeword can
be specified dynamically at each kansa invocation so that it lasts only
for the duration of that kansa job and does not represent a permanent
security blindspot that attackers may discover and attempt to exploit.
Analysts may opt to integrate API calls with their AV/EDR/EPP products
to request/submit a temporary safeword or suppression.

.INPUTS
None
You cannot pipe objects to this cmdlet
.OUTPUTS
Various and sundry.
.NOTES
In the absence of a configuration file, specifying which modules to run, 
this script will run each module across all hosts.
Each module should return objects.
Because modules should only COLLECT data from remote hosts, their 
filenames must begin with "Get-". Examples:
Get-PrefetchListing.ps1
Get-Netstat.ps1
Any module not beginning with "Get-" will be ignored.
Note this read-only aspect is unenforced, therefore, Kansa can be used 
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
.EXAMPLE
Kansa.ps1 -TargetList hostlist -Pushbin -Rmbin -AutoParse -ElkAlert -Verbose
Runs all modules in Modules.conf against the hosts specified in hostlist. Runs 
the autoparse function to clean up output, and sends the formatted JSON output
to an Elk listener.
.EXAMPLE
.\kansa.ps1 -ModulePath .\Modules\FireForget\Get-AccessibilityHijackFF.ps1 
    -Credential $cred -TargetList .\targets.txt -AutoParse -ElkAlert @("192.168.1.31") 
    -ElkPort @(1337) -FireForget -FFwrapper .\Modules\FireForget\FFwrapper.ps1 
    -FFStagePath .\Modules\FFStaging 
    -FFArgs @{delayedStart = $false; killSwitch = $true; killDelay = 3600; CPUpriority = "Normal"} 
    -SafeWord "NotTheDroidsURLooking4" 
Runs kansa module Get-AccessibilityHijackFF.ps1 in Fire&Forget mode against all systems
listed in the .\targets.txt (one target per line) running using the elevated permissions
specified in the PSCredential $cred object. Kansa will automatically parse the results
and send them to the specified Elk cluster specified by the IP 192.168.1.31 and port 1337.
The module will be wrapped with the FFwrapper.ps1 with module-specific FFargs being transcribed
into the new code and the resulting script will be placed in the .\Modules\FFStaging folder.
Many of these arguments are the default values and do not need to be explicitly specified
they are used here for illustrative purposes only.
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
    [ValidateSet("CSV","JSON","TSV","XML","GL","SPLUNK")]
        [String]$OutputFormat="CSV",
    [Parameter(Mandatory=$False,Position=6)]
        [Switch]$Pushbin,
    [Parameter(Mandatory=$False,Position=7)]
        [Switch]$Rmbin,
    [Parameter(Mandatory=$False,Position=8)]
        [Int]$ThrottleLimit=200,
    [Parameter(Mandatory=$False,Position=9)]
    [ValidateSet("Ascii","BigEndianUnicode","Byte","Default","Oem","String","Unicode","Unknown","UTF32","UTF7","UTF8")]
        [String]$Encoding="Unicode",
    [Parameter(Mandatory=$False,Position=10)]
        [Switch]$UpdatePath,
    [Parameter(Mandatory=$False,Position=11)]
        [Switch]$ListModules,
    [Parameter(Mandatory=$False,Position=12)]
        [Switch]$ListAnalysis,
    [Parameter(Mandatory=$False,Position=13)]
        [Switch]$Analysis,
    [Parameter(Mandatory=$False,Position=14)]
        [Switch]$Transcribe,
    [Parameter(Mandatory=$False,Position=15)]
        [Switch]$Quiet=$False,
    [Parameter(Mandatory=$False,Position=16)]
        [Switch]$UseSSL,
    [Parameter(Mandatory=$False,Position=17)]
        [ValidateRange(0,65535)]
        [uint16]$Port=5985,
    [Parameter(Mandatory=$False,Position=18)]
        [ValidateSet("Basic","CredSSP","Default","Digest","Kerberos","Negotiate","NegotiateWithImplicitCredential")]
        [String]$Authentication="Kerberos",
    [Parameter(Mandatory=$false,Position=19)]
        [int32]$JSONDepth=20,
	[Parameter(Mandatory=$false,Position=20)]
		[Switch]$AutoParse,
    [Parameter(Mandatory=$false,Position=21)]
        [String[]]$ElkAlert=@(),
    [Parameter(Mandatory=$false,Position=22)]
        [int32]$JobTimeout=900,
    [Parameter(Mandatory=$false,Position=23)]
        [uint16[]]$ElkPort=@(1337),
    [Parameter(Mandatory=$false,Position=24)]
        [Switch]$FireForget,
    [Parameter(Mandatory=$false,Position=25)]
        [String]$FFwrapper="Modules\FireForget\FFwrapper.ps1",
    [Parameter(Mandatory=$false,Position=26)]
        [hashtable]$FFArgs=@{delayedStart = $true; maxDelay = 3600; killSwitch = $true; killDelay = 1800; VDIcheck = $false; CPUpriority = "Idle" },
    [Parameter(Mandatory=$false,Position=27)]
        [String]$FFStagePath="Modules\FFStaging\",
    [Parameter(Mandatory=$false,Position=28)]
        [String]$SafeWord="safeword"
)

# First check to see if Kansa is already in use on the current  #
# machine. If it is, alert the user and exit.                   #
if (Test-Path $PSScriptRoot\IN_USE_BY_*){
    $BusyUser = Get-ChildItem $PSScriptRoot\IN_USE_BY_* | select Name
    $BusyUser = $BusyUser.Name.Split("_")[-1]
    Write-Verbose "$BusyUser is using Kansa on this machine, exiting..."
    Exit
}
else {
    $BusyFileName = "IN_USE_BY_$env:USERNAME"
    New-Item -Path $PSScriptRoot -Name $BusyFileName -ItemType "file" | Out-Null
}

# Opening with a Try so the Finally block at the bottom will always call
# the Exit-Script function and clean up things as needed.
Try {

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
    }$Recpt | ConvertTo-Json -Depth $JSONDepth -Compress | Set-Content -Encoding $Encoding $Outfile

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
        [void] (Stop-Transcript)
    }

    if ($Error) {
        "Exit-Script function was passed an error, this may be a duplicate that wasn't previously cleared, or Kansa.ps1 has crashed." | Add-Content -Encoding $Encoding $ErrorLog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    if (Test-Path($ErrorLog)) {
        Write-Output "Script completed with warnings or errors. See ${ErrorLog} for details."
    }

    if (!(Get-ChildItem -Force $OutputPath)) {
        # $OutputPath is empty, nuke it
        "Output path was created, but Kansa finished with no hits, no runs and no errors. Nuking the folder."
        [void] (Remove-Item $OutputPath -Force)
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
    $Error.Clear()
    # ToDo: There should probably be some error handling in this function.

    Write-Debug ('$ModulePath argument is {0}.' -f $ModulePath)

    # User may have passed a full path to a specific module, possibly with an argument
    $ModuleScript = ($ModulePath -split " ")[0]
    $ModuleArgs   = @($ModulePath -split [regex]::escape($ModuleScript))[1].Trim()

    $Modules = $FoundModules = @()
    # Need to maintain the order for "order of volatility"
    $ModuleHash = New-Object System.Collections.Specialized.OrderedDictionary

    if (Test-Path($ModuleScript)) {
    	if (!(ls $ModuleScript | Select-Object -ExpandProperty PSIsContainer)) {
        	# User may have provided full path to a .ps1 module, which is how you run a single module explicitly
        	$ModuleHash.Add((ls $ModuleScript), $ModuleArgs)

        
            	$Module = ls $ModuleScript | Select-Object -ExpandProperty BaseName
           	Write-Verbose "Running module: `n$Module $ModuleArgs"
            	Return $ModuleHash
        }
    }
    $ModConf = $ModulePath + "\" + "Modules.conf"
    if (Test-Path($Modconf)) {
        Write-Verbose "Found ${ModulePath}\Modules.conf."
        # ignore blank and commented lines, trim misc. white space
        Get-Content $ModulePath\Modules.conf | Foreach-Object { $_.Trim() } | ? { $_ -gt 0 -and (!($_.StartsWith("#"))) } | Foreach-Object { $Module = $_
            # verify listed modules exist
            $ModuleScript = ($Module -split " ")[0]
            $ModuleArgs   = ($Module -split [regex]::escape($ModuleScript))[1].Trim()
            $Modpath = $ModulePath + "\" + $ModuleScript
            if (!(Test-Path($Modpath))) {
                "WARNING: Could not find module specified in ${ModulePath}\Modules.conf: $ModuleScript. Skipping." | Add-Content -Encoding $Encoding $ErrorLog
            } else {
                # module found add it and its arguments to the $ModuleHash
                $ModuleHash.Add((ls $ModPath), $Moduleargs)
            }
        }
    } else {
        # we had no modules.conf
        ls -r "${ModulePath}\Get-*.ps1" | Foreach-Object { $Module = $_
            $ModuleHash.Add($Module, $null)
        }
    }
    Write-Verbose "Running modules:`n$(($ModuleHash.Keys | Select-Object -ExpandProperty BaseName) -join "`n")"
    $ModuleHash
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Get-LoggingConf {
<#
.SYNOPSIS
If $OutputFormat is either GL or Splunk, load the proper configuration so that
the output reaches the proper destination.
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$OutputFormat,
    [Parameter(Mandatory=$False,Position=1)]
        [String]$LoggingConf = ".\logging.conf"
)

    Write-Debug "Results will be sent to $($OutputFormat)"
    $Error.Clear()
    # ToDo: There should probably be some error handling in this function.

    if (Test-Path($LoggingConf)) {
        Write-Verbose "Found logging.conf"
        # We should only grab lines that correspond with our desired destination, otherwise, data will just fly off in to the ether
        # and you'll be stuck analyzing JSON files.
        if ($OutputFormat -eq "splunk") {
            Get-Content $LoggingConf | Foreach-Object { $_.Trim() } | ? {$_.StartsWith('spl') -and (!($_.StartsWith("#")))}
        }
        elseif ($OutputFormat -eq "gl") {
            Get-Content $LoggingConf | Foreach-Object { $_.Trim() } | ? {$_.StartsWith('gl') -and (!($_.StartsWith("#")))}
        }
    }
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
        $Error.Clear()
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
        $Error.Clear()
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
            $Targets = Get-Content $TargetList | Foreach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 }
        } else {
            $Targets = Get-Content $TargetList | Foreach-Object { $_.Trim() } | Where-Object { $_.Length -gt 0 } | Select-Object -First $TargetCount
        }
    } else {
        # no target list provided, we'll query AD for it
        Write-Verbose "`$TargetCount is ${TargetCount}."
        if ($TargetCount -eq 0 -or $TargetCount -eq $Null) {
            $Targets = Get-ADComputer -Filter * | Select-Object -ExpandProperty Name 
        } else {
            $Targets = Get-ADComputer -Filter * -ResultSetSize $TargetCount | Select-Object -ExpandProperty Name
        }
        # Iterate through targets, cleaning up AD Replication errors
        # In some AD environments, when there are duplicate object names, AD will add the objectGUID to the Name
        # displayed in the format of "hostname\0ACNF:ObjectGUID".  If you expand the property Name, you get 2 lines
        # returned, the hostname, and then CNF:ObjectGUID. This code will look for hosts with more than one line and return
        # the first line which is assumed to be the host name.
        foreach ($item in $Targets) {
            $numlines = $item | Measure-Object -Line
            if ($numlines.Lines -gt 1) {
                $lines = $item.Split("`n")
                $i = [array]::IndexOf($targets, $item)
                $targets[$i] = $lines[0]
            }
        }
        $TargetList = "hosts.txt"
        Set-Content -Path $TargetList -Value $Targets -Encoding $Encoding
    }

    if ($Targets) {
        Write-Verbose "$($Targets.count) targets found`n"
        if($Targets.GetType().Name -match "String"){
            $tmp = New-Object System.Collections.ArrayList
            if($Targets.count -eq 1){ $Targets = @($Targets)}
            [void]$tmp.Add($Targets)
            return [System.Collections.ArrayList]$tmp
        }else{
            return $Targets
        }
    } else {
        Write-Verbose "Get-Targets function found no targets. Checking for errors."
    }
    
    if ($Error) { # if we make it here, something went wrong
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        "ERROR: Get-Targets function could not get a list of targets. Quitting."
        $Error.Clear()
        Exit
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"
}

function Get-LegalFileName {
<#
.SYNOPSIS
Returns argument with illegal filename characters removed.
Collector module output are named after the module and any
arguments.
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
Directives are used for two things:
1) The BINDEP directive tells Kansa that a module depends on some 
binary and what the name of the binary is. If Kansa is called with 
-PushBin, the script will look in Modules\bin\ for the binary and 
attempt to copy it to targets. Specify multiple BINDEPs by
separating each path with a semi-colon (;).
2) The DATADIR directive tells Kansa what the output path is for
the given module's data so that if it is called with the -Analysis
flag, the analysis scripts can find the data.
TK Some collector output paths are dynamically generated based on
arguments, so this breaks for analysis. Solve.
3) Added support for an OUTPUT directive, allowing a module to 
override the OutputFormat specified when calling KANSA
#>
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Module,
    [Parameter(Mandatory=$False,Position=1)]
        [Switch]$AnalysisPath
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()
    if ($AnalysisPath) {
        $Module = ".\Analysis\" + $Module
    }

    if (Test-Path($Module)) {
        
        $DirectiveHash = @{}

        Get-Content $Module | Select-String -CaseSensitive -Pattern "BINDEP|DATADIR|OUTPUT" | Foreach-Object { $Directive = $_
            if ( $Directive -match "(^BINDEP|^# BINDEP) (.*)" ) {
                $DirectiveHash.Add("BINDEP", $($matches[2]))
            }
            if ( $Directive -match "(^DATADIR|^# DATADIR) (.*)" ) {
                $DirectiveHash.Add("DATADIR", $($matches[2])) 
            }
            if ( $Directive -match "(^OUTPUT|^# OUTPUT) (.*)" ) {
                $DirectiveHash.Add("OUTPUT", $($matches[2])) 
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
        [Int]$ThrottleLimit,
    [Parameter(Mandatory=$False,Position=4)]
        [Array]$LogConf
)
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()

    $myModuleName = $Modules.Keys | Select -First 1 | Select-Object -ExpandProperty BaseName

    # Create our sessions with targets
    if ($Credential) {
        if ($UseSSL) {
            $PSSessions = New-PSSession -ComputerName $Targets -Port $Port -UseSSL -Authentication $Authentication -SessionOption (New-PSSessionOption -NoMachineProfile -OpenTimeout 1500 -OperationTimeout 5000 -CancelTimeout 5000) -Credential $Credential
        } else {
            $PSSessions = New-PSSession -ComputerName $Targets -Port $Port -Authentication $Authentication -SessionOption (New-PSSessionOption -NoMachineProfile -OpenTimeout 1500 -OperationTimeout 5000 -CancelTimeout 5000) -Credential $Credential
        }
    } else {
        if ($UseSSL) {
            $PSSessions = New-PSSession -ComputerName $Targets -Port $Port -UseSSL -Authentication $Authentication -SessionOption (New-PSSessionOption -NoMachineProfile -OpenTimeout 1500 -OperationTimeout 5000 -CancelTimeout 5000)
        } else {
            $PSSessions = New-PSSession -ComputerName $Targets -Port $Port -Authentication $Authentication -SessionOption (New-PSSessionOption -NoMachineProfile -OpenTimeout 1500 -OperationTimeout 5000 -CancelTimeout 5000)
        }
    }

    # Check for and log errors
    if ($Error) {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }

    if ($PSSessions) {

        $Modules.Keys | Foreach-Object { $Module = $_
            $ModuleName  = $Module | Select-Object -ExpandProperty BaseName
            $Arguments   = @()
            $Arguments   += $($Modules.Get_Item($Module)) -split ","
            if ($Arguments) {
                $ArgFileName = Get-LegalFileName $Arguments
            } else { $ArgFileName = "" }
            
            # Get our directives both old and new style
            $DirectivesHash  = @{}
            $DirectivesHash = Get-Directives $Module
            if ($Pushbin) {
                $bindeps = [string]$DirectivesHash.Get_Item("BINDEP") -split ';'
                foreach($bindep in $bindeps) {
                if ($bindep) {
		 #$PSScriptRoot is parsed as literal string into $bindep from the module script rather than the directory path, below is a fix to replace the literal '$PSScriptRoot' with the directory path required
		 if($bindep -match "PSScriptRoot"){
		 $bindep = $bindep.Trim("$")
		 $bindep = $bindep.Replace("PSScriptRoot", $PSScriptRoot)
		 }
                    # Send-File only supports a single destination at a time, so we have to loop this.
                    # Fix for Issue 146, originally suggested by sc2pyro.
                    foreach ($PSSession in $PSSessions)
                    {
                        $RemoteWindir = Invoke-Command -Session $PSSession -ScriptBlock { Get-ChildItem -Force env: | Where-Object { $_.Name -match "windir" } | Select-Object -ExpandProperty value }
                        $null = Send-File -Path (ls $bindep).FullName -Destination $RemoteWindir -Session $PSSession
                        }
                    }
                }
            }

            # set up external logging parameters to be used below
        if ($LogConf) {
            $LogConf | foreach {
                $logAssign = $_ -split '=' 
                New-Variable -Name $logAssign[0] -Value $logAssign[1] -Force
            }
        }
            
            # run the module on the targets            
            if ($Arguments) {
                Write-Debug "Invoke-Command -Session $PSSessions -FilePath $Module -ArgumentList `"$Arguments`" -AsJob -ThrottleLimit $ThrottleLimit"
                $Job = Invoke-Command -Session $PSSessions -FilePath $Module -ArgumentList $Arguments -AsJob -ThrottleLimit $ThrottleLimit
                Write-Verbose "Waiting for $ModuleName $Arguments to complete.`n"
            } else {
                Write-Debug "Invoke-Command -Session $PSSessions -FilePath $Module -AsJob -ThrottleLimit $ThrottleLimit"
                $Job = Invoke-Command -Session $PSSessions -FilePath $Module -AsJob -ThrottleLimit $ThrottleLimit                
                Write-Verbose "Waiting for $ModuleName to complete.`n"
            }
            # Wait-Job does return data to stdout, add $suppress = to start of next line, if needed
            # Each set of jobs has a 10 minute timeout to prevent endless stalling
            $Job | Wait-Job -Timeout $JobTimeout
            if ($Job.State -contains "Running"){ Write-Verbose "Job timeout exceeded, continuing...`n" }
            
            # set up our output location
            $GetlessMod = $($ModuleName -replace "Get-") 
            # Long paths prevent output from being written, so we truncate $ArgFileName to accomodate
            # We're estimating the output path because at this point, we don't know what the hostname
            # is and it is part of the path. Hostnames are 15 characters max, so we assume worst case.
            # Per http://msdn.microsoft.com/en-us/library/aa365247.aspx#maxpath, maximum
            # path length should be 260 characters. 
			Set-Variable -Name MAXPATH -Value 260 -Option Constant
			Set-Variable -Name EXTLENGTH -Value 4 -Option Constant
			Set-Variable -Name SEPARATOR -Value 1 -Option Constant
			Set-Variable -Name CMPNAMELENGTH -Value 15 -Option Constant
			
			# Esitmate path length without arguments
			$EstOutPathLength = $OutputPath.Length + $GetlessMod.Length + $SEPARATOR + $CMPNAMELENGTH + $SEPARATOR + $GetlessMod.Length + $EXTLENGTH
			
			# Clean up $ArgFileName
			$ArgFileName = $ArgFileName -replace "'","-" -replace "--","-"
			
			if ($EstOutPathLength + $ArgFileName.Length + $ArgFileName.Length -gt $MAXPATH)
			{
				$MaxArgLength = [int]($MAXPATH - $EstOutPathLength) / 2 # Divide by two because args are in folder and file name
				$OrigArgFileName = $ArgFileName
				$ArgFileName = $ArgFileName.Substring(0, $MaxArgLength)
				"WARNING: ${GetlessMod}'s output path contains arguments that were passed to it. Those arguments were truncated from $OrigArgFileName to $ArgFileName to accommodate Window's MAXPATH limitations of 260 characters."
			}
			
            # Set Module output directory based on module name and arg file name (if present)
            $ModuleOutputDir = ($GetlessMod + $ArgFileName)

            # Add module output directory to collection of all module output dirs, avoid duplicates
            if ($ModulePathColl -notcontains $ModuleOutputDir){
                [void] $ModulePathColl.add($ModuleOutputDir) 
            }
        
            # Create module output directory on disk if it doesn't exist
            $pathExists = Test-Path $OutputPath\$ModuleOutputDir
            if ($pathExists -eq $False){
                [void] (New-Item -Path $OutputPath -name $ModuleOutputDir -ItemType Directory)
            }

            $Job.ChildJobs | Foreach-Object { $ChildJob = $_
                $Recpt = Receive-Job $ChildJob

                # Remove excess properties that we don't need in the module output
                foreach ($i in $Recpt){
                    if(-not ([string]::IsNullOrEmpty($i))){
		    $i.PSObject.Properties.Remove("PSShowComputerName")
                    $i.PSObject.Properties.Remove("RunspaceId")
		    }
                }
            
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
		try{
                # save the data
                switch -Wildcard ($OutputFormat) {
                    "*csv" {
                        $Outfile = $Outfile + ".csv"
                        $Recpt | Export-Csv -NoTypeInformation -Encoding $Encoding $Outfile
                    }
                    "*json" {					
                        $Outfile = $Outfile + ".json"
                        $Recpt | ConvertTo-Json -Depth $JSONDepth -Compress | Set-Content -Encoding $Encoding $Outfile
                    }
                    "*tsv" {
                        $Outfile = $Outfile + ".tsv"
                        # LogParser can't handle quoted tab separated values, so we'll strip the quotes.
                        $Recpt | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | ForEach-Object { $_ -replace "`"" } | Set-Content -Encoding $Encoding $Outfile
				    }
                    "*xml" {
                        $Outfile = $Outfile + ".xml"
                        $Recpt | Export-Clixml $Outfile -Encoding $Encoding
                    }
                    "*gl" {
                    # We're going to handle output to a GrayLog instance in two ways... we're going to attempt to send it to the GrayLog server
                    # and we're also going to write the output to JSON files.
                    $Outfile = $Outfile + ".json"
                    $Recpt | ConvertTo-Json -Depth $JSONDepth | Set-Content -Encoding $Encoding $Outfile
                    # The next line tells Kansa where to send the data; hopefully you've entered the proper information in logging.conf
                    $glurl = "http://${glServerName}:$glServerPort/gelf"
                    # The next few lines define how we're going to handle information output from the various Kansa modules, then ship it off to GL
                    ForEach ($item in $Recpt){
                        $body = @{
                            message = $item
                            facility = "main"
                            host = $Target.Split(":")[0]
                            } | ConvertTo-Json
                            Invoke-RestMethod -Method Post -Uri $glurl -Body $body
                        }

                    } # end GL definition
                "*splunk" {
                    # We're going to handle output to a Splunk instance in two ways... we're going to attempt to send it to a Splunk instance
                    # and we're also going to write the output to JSON files.  Much like the above GrayLog example.
                    $Outfile = $Outfile + ".json"
                    $Recpt | ConvertTo-Json -Depth $JSONDepth | Set-Content -Encoding $Encoding $Outfile
                    # Parameters for the next line are configured in logging.conf... don't say I didn't warn you
                    $url = "http://${splServerName}:$splServerPort/services/collector/event"
                    $header = @{Authorization = "Splunk $splHECToken"}
                    # The next few lines define how we're going to handle information output from the various Kansa modules and then ship it off to Splunk
                    ForEach ($item in $Recpt){
                        $body = @{
                        event = $item
                        source = "$GetlessMod"
                        sourcetype = "_json"
                        host = $ChildJob.Location
                        } | ConvertTo-Json
                        Invoke-RestMethod -Method Post -Uri $url -Headers $header -Body $body
                        }
                    
                    } # end Splunk definition
                    <# Following output formats are no longer supported in Kansa
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
                    #>
                    default {
                        $Outfile = $Outfile + ".csv"
                        $Recpt | Export-Csv -NoTypeInformation -Encoding $Encoding $Outfile
                    }
                }
		}catch{("Caught:{0}" -f $_)}
            }

            # Release memory reserved for Job data since we don't need it any more.
            # Fixes bug number 73.
            Remove-Job $Job

            if ($rmbin) {
                if ($bindeps) {
                foreach ($bindep in $bindeps) {
                    $RemoteBinDep = "$RemoteWinDir\$(split-path -path $bindep -leaf)"
                    Invoke-Command -Session $PSSession -ScriptBlock { Remove-Item -force -path $using:RemoteBinDep}
                }
            }
        }

        }
        Remove-PSSession $PSSessions
    }

    if ($Error) {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    
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
    $Targets | Foreach-Object { $Target = $_
    Try {
        if ($Credential) {
            [void] (New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$" -Credential $Credential)
            Copy-Item "$Bindep" "KansaDrive:"
            [void] (Remove-PSDrive -Name "KansaDrive")
        } else {
            [void] (New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$")
            Copy-Item "$Bindep" "KansaDrive:"
            [void] (Remove-PSDrive -Name "KansaDrive")
        }
    } Catch [Exception] {
        "Caught: $_" | Add-Content -Encoding $Encoding $ErrorLog
    }
        if ($Error) {
            "WARNING: Failed to copy ${Bindep} to ${Target}." | Add-Content -Encoding $Encoding $ErrorLog
            $Error | Add-Content -Encoding $Encoding $ErrorLog
            $Error.Clear()
        }
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}

function Send-File {
	<#
	.SYNOPSIS
		This function sends a file (or folder of files recursively) to a destination WinRm session. This function was originally
		built by Lee Holmes (http://poshcode.org/2216) but has been modified to recursively send folders of files as well
		as to support UNC paths.
	.PARAMETER Path
		The local or UNC folder path that you'd like to copy to the session. This also support multiple paths in a comma-delimited format.
		If this is a UNC path, it will be copied locally to accomodate copying.  If it's a folder, it will recursively copy
		all files and folders to the destination.
	.PARAMETER Destination
		The local path on the remote computer where you'd like to copy the folder or file.  If the folder does not exist on the remote
		computer it will be created.
	.PARAMETER Session
		The remote session. Create with New-PSSession.
	.EXAMPLE
		$session = New-PSSession -ComputerName MYSERVER
		Send-File -Path C:\test.txt -Destination C:\ -Session $session
		This example will copy the file C:\test.txt to be C:\test.txt on the computer MYSERVER
	.INPUTS
		None. This function does not accept pipeline input.
	.OUTPUTS
		System.IO.FileInfo
	#>
	[CmdletBinding()]
	param
	(
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string[]]$Path,
		
		[Parameter(Mandatory)]
		[ValidateNotNullOrEmpty()]
		[string]$Destination,
		
		[Parameter(Mandatory)]
		[System.Management.Automation.Runspaces.PSSession]$Session
	)
	process
	{
		foreach ($p in $Path)
		{
			try
			{
				if ($p.StartsWith('\\'))
				{
					Write-Verbose -Message "[$($p)] is a UNC path. Copying locally first"
					Copy-Item -Path $p -Destination ([environment]::GetEnvironmentVariable('TEMP', 'Machine'))
					$p = "$([environment]::GetEnvironmentVariable('TEMP', 'Machine'))\$($p | Split-Path -Leaf)"
				}
				if (Test-Path -Path $p -PathType Container)
				{
					Write-Log -Source $MyInvocation.MyCommand -Message "[$($p)] is a folder. Sending all files"
					$files = Get-ChildItem -Force -Path $p -File -Recurse
					$sendFileParamColl = @()
					foreach ($file in $Files)
					{
						$sendParams = @{
							'Session' = $Session
							'Path' = $file.FullName
						}
						if ($file.DirectoryName -ne $p) ## It's a subdirectory
						{
							$subdirpath = $file.DirectoryName.Replace("$p\", '')
							$sendParams.Destination = "$Destination\$subDirPath"
						}
						else
						{
							$sendParams.Destination = $Destination
						}
						$sendFileParamColl += $sendParams
					}
					foreach ($paramBlock in $sendFileParamColl)
					{
						Send-File @paramBlock
					}
				}
				else
				{
					Write-Verbose -Message "Starting WinRM copy of [$($p)] to [$($Destination)]"
					# Get the source file, and then get its contents
					$sourceBytes = [System.IO.File]::ReadAllBytes($p);
					$streamChunks = @();
					
					# Now break it into chunks to stream.
					$streamSize = 1MB;
					for ($position = 0; $position -lt $sourceBytes.Length; $position += $streamSize)
					{
						$remaining = $sourceBytes.Length - $position
						$remaining = [Math]::Min($remaining, $streamSize)
						
						$nextChunk = New-Object byte[] $remaining
						[Array]::Copy($sourcebytes, $position, $nextChunk, 0, $remaining)
						$streamChunks +=, $nextChunk
					}
					$remoteScript = {
						if (-not (Test-Path -Path $using:Destination -PathType Container))
						{
							$null = New-Item -Path $using:Destination -Type Directory -Force
						}
						$fileDest = "$using:Destination\$($using:p | Split-Path -Leaf)"
						## Create a new array to hold the file content
						$destBytes = New-Object byte[] $using:length
						$position = 0
						
						## Go through the input, and fill in the new array of file content
						foreach ($chunk in $input)
						{
							[GC]::Collect()
							[Array]::Copy($chunk, 0, $destBytes, $position, $chunk.Length)
							$position += $chunk.Length
						}
						
						[IO.File]::WriteAllBytes($fileDest, $destBytes)
						
						Get-Item -Force $fileDest
						[GC]::Collect()
					}
					
					# Stream the chunks into the remote script.
					$Length = $sourceBytes.Length
					$streamChunks | Invoke-Command -Session $Session -ScriptBlock $remoteScript
					Write-Verbose -Message "WinRM copy of [$($p)] to [$($Destination)] complete"
				}
			}
			catch
			{
				Write-Error $_.Exception.Message
			}
		}
	}
	
}

function Remove-Bindep {
<#
.SYNOPSIS
Attempts to remove binaries from targets when Kansa.ps1 is run with 
-rmbin switch.
ToDo: Fix this so it works even when Admin$ is not a valid share, as
is the case with default Azure VM configuration. Maybe more reliable
to Enter-PSSession for the host and Remove-Item.
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
    $Targets | Foreach-Object { $Target = $_
        if ($Credential) {
            [void] (New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$" -Credential $Credential)
            Remove-Item "KansaDrive:\$Bindep" 
            [void] (Remove-PSDrive -Name "KansaDrive")
        } else {
            [void] (New-PSDrive -PSProvider FileSystem -Name "KansaDrive" -Root "\\$Target\ADMIN$")
            Remove-Item "KansaDrive:\$Bindep"
            [void] (Remove-PSDrive -Name "KansaDrive")
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

    ls $ModulePath | Foreach-Object { $dir = $_
        if ($dir.PSIsContainer -and ($dir.name -ne "bin" -or $dir.name -ne "Private")) {
            ls "${ModulePath}\${dir}\Get-*" | Foreach-Object { $file = $_
                $($dir.Name + "\" + (split-path -leaf $file))
            }
        } else {
            ls "${ModulePath}\Get-*" | Foreach-Object { $file = $_
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
    Write-Debug "Entering $($MyInvocation.MyCommand)"
    $Error.Clear()

    # Update the path to inlcude Kansa analysis script paths, if they aren't already
    $Invocation = (Get-Variable MyInvocation -Scope 1).Value
    $kansapath  = Split-Path $Invocation.MyCommand.Path
    $Paths      = ($env:Path).Split(";")

    if (-not($Paths -match [regex]::Escape("$kansapath\Analysis"))) {
        # We want this one and it's not covered below, so...
        $env:Path = $env:Path + ";$kansapath\Analysis"
    }

    if (-not($Paths -match [regex]::Escape("$kansapath\Shared"))) {
        # We want this one and it's not covered below, so...
        $env:Path = $env:Path + ";$kansapath\Shared"
    }

    $AnalysisPaths = (ls -Recurse "$kansapath\Analysis" | Where-Object { $_.PSIsContainer } | Select-Object -ExpandProperty FullName)
    $AnalysisPaths | ForEach-Object {
        if (-not($Paths -match [regex]::Escape($_))) {
            $env:Path = $env:Path + ";$_"
        }
    }
    
    if ($Error) {
        # Write the $Error to the $Errorlog
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
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
        $AnalysisScripts = Get-Content "$StartingPath\Analysis\Analysis.conf" | Foreach-Object { $_.Trim() } | ? { $_ -gt 0 -and (!($_.StartsWith("#"))) }

        $AnalysisOutPath = $OutputPath + "\AnalysisReports\"
        [void] (New-Item -Path $AnalysisOutPath -ItemType Directory -Force)

        # Get our DATADIR directive
        $DirectivesHash  = @{}
        $AnalysisScripts | Foreach-Object { $AnalysisScript = $_
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


#Possible future implementation to deploy Fire&Forget modules even faster using this code from Ryan Witschger
function RapidMultiThread {
#.Synopsis
#    This is a quick and open-ended script multi-threader searcher
#    
#.Description
#    This script will allow any general, external script to be multithreaded by providing a single
#    argument to that script and opening it in a seperate thread.  It works as a filter in the 
#    pipeline, or as a standalone script.  It will read the argument either from the pipeline
#    or from a filename provided.  It will send the results of the child script down the pipeline,
#    so it is best to use a script that returns some sort of object.
#
#    Authored by Ryan Witschger - http://www.Get-Blog.com
#    
#.PARAMETER Command
#    This is where you provide the PowerShell Cmdlet / Script file that you want to multithread.  
#    You can also choose a built in cmdlet.  Keep in mind that your script.  This script is read into 
#    a scriptblock, so any unforeseen errors are likely caused by the conversion to a script block.
#    
#.PARAMETER ObjectList
#    The objectlist represents the arguments that are provided to the child script.  This is an open ended
#    argument and can take a single object from the pipeline, an array, a collection, or a file name.  The 
#    multithreading script does it's best to find out which you have provided and handle it as such.  
#    If you would like to provide a file, then the file is read with one object on each line and will 
#    be provided as is to the script you are running as a string.  If this is not desired, then use an array.
#    
#.PARAMETER InputParam
#    This allows you to specify the parameter for which your input objects are to be evaluated.  As an example, 
#    if you were to provide a computer name to the Get-Process cmdlet as just an argument, it would attempt to 
#    find all processes where the name was the provided computername and fail.  You need to specify that the 
#    parameter that you are providing is the "ComputerName".
#
#.PARAMETER AddParam
#    This allows you to specify additional parameters to the running command.  For instance, if you are trying
#    to find the status of the "BITS" service on all servers in your list, you will need to specify the "Name"
#    parameter.  This command takes a hash pair formatted as follows:  
#
#    @{"ParameterName" = "Value"}
#    @{"ParameterName" = "Value" ; "ParameterTwo" = "Value2"}
#
#.PARAMETER AddSwitch
#    This allows you to add additional switches to the command you are running.  For instance, you may want 
#    to include "RequiredServices" to the "Get-Service" cmdlet.  This parameter will take a single string, or 
#    an aray of strings as follows:
#
#    "RequiredServices"
#    @("RequiredServices", "DependentServices")
#
#.PARAMETER MaxThreads
#    This is the maximum number of threads to run at any given time.  If resources are too congested try lowering
#    this number.  The default value is 20.
#    
#.PARAMETER SleepTimer
#    This is the time between cycles of the child process detection cycle.  The default value is 200ms.  If CPU 
#    utilization is high then you can consider increasing this delay.  If the child script takes a long time to
#    run, then you might increase this value to around 1000 (or 1 second in the detection cycle).
#
#    
#.EXAMPLE
#    Both of these will execute the script named ServerInfo.ps1 and provide each of the server names in AllServers.txt
#    while providing the results to the screen.  The results will be the output of the child script.
#    
#    gc AllServers.txt | .\Run-CommandMultiThreaded.ps1 -Command .\ServerInfo.ps1
#    .\Run-CommandMultiThreaded.ps1 -Command .\ServerInfo.ps1 -ObjectList (gc .\AllServers.txt)
#
#.EXAMPLE
#    The following demonstrates the use of the AddParam statement
#    
#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -InputParam ComputerName -AddParam @{"Name" = "BITS"}
#    
#.EXAMPLE
#    The following demonstrates the use of the AddSwitch statement
#    
#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -AddSwitch @("RequiredServices", "DependentServices")
#
#.EXAMPLE
#    The following demonstrates the use of the script in the pipeline
#    
#    $ObjectList | .\Run-CommandMultiThreaded.ps1 -Command "Get-Service" -InputParam ComputerName -AddParam @{"Name" = "BITS"} | Select Status, MachineName
#
#.\MultiThreaded.ps1 -Command .\Submit-ChangeMgtEvent.ps1 -InputParam node -ObjectList (gc .\targets.txt) -AddParam @{"source" = "Kansa-Powershell-launcher"; "type" = "ModuleName"; "resource" = "Workstation"; "severity" = 0}
    Param($Command = $(Read-Host "Enter the script file"), 
        [Parameter(ValueFromPipeline=$true,ValueFromPipelineByPropertyName=$true)]$ObjectList,
        $InputParam = $Null,
        $MaxThreads = 20,
        $SleepTimer = 200,
        $MaxResultTime = 120,
        [HashTable]$AddParam = @{},
        [Array]$AddSwitch = @()
    )
 
    Begin{
        $ISS = [system.management.automation.runspaces.initialsessionstate]::CreateDefault()
        $RunspacePool = [runspacefactory]::CreateRunspacePool(1, $MaxThreads, $ISS, $Host)
        $RunspacePool.Open()
        
        If ($(Get-Command | Select-Object Name) -match $Command){
            $Code = $Null
        }Else{
            $OFS = "`r`n"
            $Code = [ScriptBlock]::Create($Command)
            Remove-Variable OFS
        }
        $Jobs = @()
    }
 
    Process{
        #Write-Progress -Activity "Preloading threads" -Status "Starting Job $($jobs.count)"
        ForEach ($Object in $ObjectList){
            If ($Code -eq $Null){
                $PowershellThread = [powershell]::Create().AddCommand($Command)
            }Else{
                $PowershellThread = [powershell]::Create().AddScript($Code)
            }
            If ($InputParam -ne $Null){
                $PowershellThread.AddParameter($InputParam, $Object.ToString()) | out-null
            }Else{
                $PowershellThread.AddArgument($Object.ToString()) | out-null
            }
            ForEach($Key in $AddParam.Keys){
                $PowershellThread.AddParameter($Key, $AddParam.$key) | out-null
            }
            ForEach($Switch in $AddSwitch){
                $Switch
                $PowershellThread.AddParameter($Switch) | out-null
            }
            $PowershellThread.RunspacePool = $RunspacePool
            $Handle = $PowershellThread.BeginInvoke()
            $Job = "" | Select-Object Handle, Thread, object
            $Job.Handle = $Handle
            $Job.Thread = $PowershellThread
            $Job.Object = $Object.ToString()
            $Jobs += $Job
        }        
    }
 
    End{
        $ResultTimer = Get-Date
        While (@($Jobs | Where-Object {$_.Handle -ne $Null}).count -gt 0)  {
    
            $Remaining = "$($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False}).object)"
            If ($Remaining.Length -gt 60){
                $Remaining = $Remaining.Substring(0,60) + "..."
            }
            #Write-Progress `
            #    -Activity "Waiting for Jobs - $($MaxThreads - $($RunspacePool.GetAvailableRunspaces())) of $MaxThreads threads running" `
            #    -PercentComplete (($Jobs.count - $($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False}).count)) / $Jobs.Count * 100) `
            #    -Status "$(@($($Jobs | Where-Object {$_.Handle.IsCompleted -eq $False})).count) remaining - $remaining" 
 
            ForEach ($Job in $($Jobs | Where-Object {$_.Handle.IsCompleted -eq $True})){
                $Job.Thread.EndInvoke($Job.Handle)
                $Job.Thread.Dispose()
                $Job.Thread = $Null
                $Job.Handle = $Null
                $ResultTimer = Get-Date
            }
            If (($(Get-Date) - $ResultTimer).totalseconds -gt $MaxResultTime){
                Write-Error "Child script appears to be frozen, try increasing MaxResultTime"
                Exit
            }
            Start-Sleep -Milliseconds $SleepTimer        
        } 
        $RunspacePool.Close() | Out-Null
        $RunspacePool.Dispose() | Out-Null
    } 
}

function recursiveFFArgParser{
<#
.SYNOPSIS
Takes a Hashtable of Module-specific parameters to pass
thru to a Fire&Forget module during dynamic code-rewrite
and builds a string of variable name/value assignment
operations from the hashtable. This is a recursive
function to allow nested variable values. i.e. 
$var = @{numbers = @(1,2,3); extensions = @("txt", "ini")}
#>
    param(
        [Object]$ffarg
    )
    $str = ""
    #if($ffarg -eq ""){return ""} #termination condition, should not need
    if($ffarg.GetType().Name -like "Object\[\]" -or ($ffarg.GetType().Name -match "Array") -or ($ffarg.GetType().Name -match "\[\]")){
        $str = '[array]@(' + ($ffarg | %{ ''+  (recursiveFFArgParser -ffarg $_) + ','}) + ')'
        $str = $str -replace ",\)$",")"
    }elseif($ffarg.GetType().Name -like "Hashtable"){
        $str = '[hashtable]@{' + ($ffarg.keys | %{ $_ + ' = ' + (recursiveFFArgParser -ffarg $ffarg.$_) + '; ' }) + '}'
    }elseif($ffarg.GetType().Name -like "Boolean"){
        $str = '$' + $ffarg
    }elseif($ffarg.GetType().Name -like "String"){
        $str = '"' + $ffarg + '"'
    }elseif($ffarg.GetType().Name -like "Int32"){
        $str = "[int]$ffarg"
    }else{
        $str = "unable to parse arg $ffarg of type $($ffarg.gettype().Name)"
    }
    return $str
}

function AutoParse {
<#
.SYNOPSIS
This function performs automated parsing of module output for ease of analysis.
Note that this function depends on specific output types for different modules.
The affected modules have been updated with a directive to ensure that they
produce the expected outputs.
#>
[cmdletbinding()]
Param(
    [Parameter(Mandatory=$true,Position=0)]
        $ComputerDir,
    [Parameter(Mandatory=$true,Position=1)]
        $ModuleList,
    [Parameter(Mandatory=$false,Position=2)]
        [Switch]$sendElkAlert
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
        # Get path for Parsers and ElkSender
        $Paths = ($env:Path).Split(";")
        $SharedMatch = $Paths.GetEnumerator() | Select-String -Pattern '.*Shared'
        $SharedPath = $SharedMatch.Matches.Value

        # Test parser path to ensure that it is found:
        if($SharedPath){
            # Load parsing functions and ElkSender functions
            . $SharedPath\Parsers.ps1
            if($sendElkAlert){
                . $SharedPath\ElkSender.ps1
            }

            # Check for group policy output
            if ($ModuleList -contains "GPResult"){
                $filePaths = ls -Path ("$ComputerDir" + "GPResult\*.json")
                $pathStr = @()
                foreach ($f in $filePaths){$pathStr += $f.toString()}
                Write-Verbose "GPResult found in ModuleList, parsing $filePaths"
                Parse-GPResult $pathStr
            }

            # Check for Autoruns output
            if ($ModuleList -contains "Autorunsc"){
                $filePaths = ls -Path ("$ComputerDir" + "Autorunsc\*.csv")
                $pathStr = @()
                foreach ($f in $filePaths){$pathStr += $f.toString()}
                Write-Verbose "Autorunsc found in ModuleList, parsing $filePaths"
                Parse-Autoruns $pathStr
            }

            # Check for AutorunsDeep output
            if ($ModuleList -contains "Autorunscdeep"){
                $filePaths = ls -Path ("$ComputerDir" + "Autorunscdeep\*.csv")
                $pathStr = @()
                foreach ($f in $filePaths){$pathStr += $f.toString()}
                Write-Verbose "Autorunscdeep found in ModuleList, parsing $filePaths"
                Parse-Autoruns $pathStr
            }

            # Check for Get-Prox output
            if ($ModuleList -contains "Prox"){
                $filePaths = ls -Path ("$ComputerDir" + "Prox\*.csv")
                $pathStr = @()
                foreach ($f in $filePaths){$pathStr += $f.toString()}
                Write-Verbose "Prox found in ModuleList, parsing $filePaths"
                Parse-GetProx $pathStr
            }

            # Check for Get-Procdump output
            if ($ModuleList -like "*ProcDump*"){
                $filePaths = ls -Path ("$ComputerDir" + "ProcDump*\*.json")
                $pathStr = @()
                foreach ($f in $filePaths){$pathStr += $f.toString()}
                Write-Verbose "ProcDump found in ModuleList, parsing $filePaths"
                Parse-GetProcdump $pathStr
            }

            # Decompress all JSON files and send Elk alerts (if specified)
            $allJSONPaths = Get-ChildItem -Path $ComputerDir -Filter '*.json' -Recurse
            $hostname = hostname
            if ($allJSONPaths.Count -gt 0){
                Write-Verbose "JSON output found, parsing...`n"

                $JSONPathStr = @()
                foreach ($f in $allJSONPaths){
                    $fullJSONPath = $f.Directory.ToString() + "\" + $f.ToString()

                    # Only add to list of files to be parsed and sent if the file has content
                    $testJSONPath = Get-Item $fullJSONPath
                    if ($testJSONPath.Length -gt 0){
                        $JSONPathStr += $fullJSONPath
                    }
                }
                if ($sendElkAlert){
                    # Open connection to Elk Collector:
                    $IP = Get-Random -InputObject $ElkAlert
                    $port = Get-Random -InputObject $ElkPort
                    $writer = Get-TCPWriter -destIP $IP -port $port
                    $bytesSentOverSocket = 0

                    foreach ($j in $JSONPathStr){
                        $moduleName = $j.Split("\")[-2]
                        $moduleName = "Kansa-$moduleName"
                        [string]$alertContent = Get-Content $j

                        $bytesSent = 0
                        $alertContentJSON = gc -Path $j -Raw | ConvertFrom-Json
                        foreach ($a in $alertContentJSON){
                            $a | Add-Member -NotePropertyName "sourceScript" -NotePropertyValue "kansa.ps1"
                            $a | Add-Member -NotePropertyName "sourceModule" -NotePropertyValue "$moduleName"
                            $a | Add-Member -NotePropertyName "KansaServer" -NotePropertyValue "$hostname"
                            $aJSON = $a | ConvertTo-Json -Compress
                            $sent = Send-ElkAlertTCP -writer $writer -alertContent $aJSON
                            $bytesSent = $bytesSent+$sent
                            $bytesSentOverSocket = $bytesSentOverSocket+$sent
                        }
                    }
                    $bytesMB = $bytesSentOverSocket/1MB
                    $bytesMB = [math]::Round($bytesMB,2)
                    Write-Verbose "Bytes sent to ELK: $bytesSentOverSocket ($bytesMB MB)`n"
                    $writer.flush()
                    $writer.Dispose()
                }
                else{
                    DecompressJSON $JSONPathStr
                }
            }

            # Send Errors into ELK (if specified)
            $errorPath = Get-ChildItem -Path $ComputerDir -Filter 'Error.log'
            if ($errorPath){
                $errorFile = Get-Item -Path $($errorPath.Directory.ToString() + "\" + $errorPath.ToString())
                Write-Verbose "Error log found, $errorFile ($($errorFile.Length) bytes)"
                Write-Verbose "parsing..." 

                if ($errorFile.Length -gt 0){                    
                    $moduleName = "kansa.ps1"
                    $ErrorLogHost = $hostname

                    $errors = Get-Content $errorFile -Delimiter '['
                    $res = @{}
                    for ($i = 1; $i -lt $errors.count; $i++) { 
                        $err=$errors[$i].replace("[","")
                        $res.add(($err.Substring(0,$err.IndexOf("]"))).ToUpper(), ($err.Substring($err.IndexOf(":")+2,$err.Length - $err.IndexOf(":") - 3)).Trim())
                    }
                    $errorFinal = New-Object -TypeName System.Collections.ArrayList

                    
                    $res.getenumerator() | % {
                        $result = New-Object -TypeName psobject
                        $result | Add-member -membertype NoteProperty -Name 'Hostname' -Value $_.Name 
                        $result | Add-member -membertype NoteProperty -Name 'KansaModule' -Value $moduleName
                        $result | Add-member -membertype NoteProperty -Name 'ModuleStatus' -Value 'Error'
                        $result | Add-member -membertype NoteProperty -Name 'Error' -Value $_.Value
                        $result | Add-member -membertype NoteProperty -Name 'ErrorLogFile' -Value $errorFile.Fullname
                        $result | Add-member -membertype NoteProperty -Name 'KansaServer' -Value $ErrorLogHost
                        [void]$errorFinal.add($result)
                    }                    

                    # Open connection to Elk Collector:
                    $IP = Get-Random -InputObject $ElkAlert
                    $port = Get-Random -InputObject $ElkPort
                    $writer = Get-TCPWriter -destIP $IP -port $port
                    $bytesSent = 0
                    foreach ($obj in $errorFinal){
                        $parsedObj = $obj | ConvertTo-Json -Compress
                        $sent = Send-ElkAlertTCP -writer $writer -AlertContent $parsedObj
                        $bytesSent = $bytesSent + $sent
                    }
                    
                    $writer.flush()
                    $writer.Dispose()
                    
                    $bytesMB = $bytesSent/1MB
                    $bytesMB = [math]::Round($bytesMB,2)
                    Write-Verbose "Bytes sent to ELK: $bytesSent ($bytesMB MB)`n"
                }                
            }
        }
        else{
            $Error = "Parser Path not found, please ensure that $ParserPath is a valid directory."
            $Error | Add-Content -Encoding $Encoding $ErrorLog
        }
        
    } Catch [Exception] {
        $Error | Add-Content -Encoding $Encoding $ErrorLog
        $Error.Clear()
    }
    Write-Debug "Exiting $($MyInvocation.MyCommand)"    
}
<# End AutoParse #>

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

# Create an arraylist to store all output folders created during this run #
$OutputPathColl = New-Object System.Collections.ArrayList

# Create output folder on disk and add it to the collection #
[void] (New-Item -Path $OutputPath -ItemType Directory -Force) 
[void]$OutputPathColl.Add($OutputPath)

If ($Transcribe) {
    $TransFile = $OutputPath + ([string] (Get-Date -Format yyyyMMddHHmmss)) + ".log"
    [void] (Start-Transcript -Path $TransFile)
}
Set-Variable -Name ErrorLog -Value ($OutputPath + "Error.Log") -Scope Script

if (Test-Path($ErrorLog)) {
    Remove-Item -Path $ErrorLog
}
# Done setting up output. #


# Set the output encoding #
if ($Encoding) {
    Set-Variable -Name Encoding -Value $Encoding -Scope Script
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

if($FireForget){
    if(!(Test-Path -Path $FFStagePath -PathType Container)){ New-Item -ItemType directory -Path $FFStagePath }
    gci -Recurse -Path $FFStagePath | % { Remove-Item $_ }
    $template = ""
    if(Test-Path $FFwrapper -PathType Leaf){
        $template = gc -Path $FFwrapper
    }else{
        Write-Error "FireForget Wapper path not found. Exiting"
        Exit 
    }
    $RewrittenFFModules = New-Object System.Collections.Specialized.OrderedDictionary
    
    $FFArgStr = ""
    $FFArgs.keys | %{ $FFArgStr += '$' + $_ + '=' + (recursiveFFArgParser -ffarg $FFArgs.$_) + "`r`n" }


    $Modules.Keys | %{
        $ModuleName = ls $_ | Select-Object -ExpandProperty BaseName
        $FFArgStr += '$global:moduleName = "' + $ModuleName + '"' +"`r`n"
        $FFmoduleContents = gc -Raw $_
        #Remove the Dummy Function Stub codeblocks from the FFtemplate...anything between the tags <DummyFunctionStubs> and </DummyFunctionStubs> will be deleted
        $FFmoduleContents = $FFmoduleContents -replace "(?ms)#<DummyFunctionStubs>.*?</DummyFunctionStubs>\s+",'#Removed FF Template Dummy Function Stubs'
        #Remove the Function names that conflict with those defined in the FFwrapper.  This should never happen if the code above works, but if a user deletes the dummyfunction tags 
        #from their template this is a safeguard to remove the functions and save them from themselves.
        $FFmoduleContents = $FFmoduleContents -replace "(?m)function (Add-Result|Get-FileDetails|Get-MagicBytes|enhancedGCI|Get-File|Send-File)\s*\{.*",'#Removed overloaded function definition'
        $FFmoduleContents = $FFmoduleContents -replace "(?m)^\s*#.*",'#Removed comments'
        $tmp = $template.Replace('#<InsertModuleNameHERE>',('$global:moduleName = "' + $ModuleName + '"' +"`r`n" + '$global:SafeWord ="' + $SafeWord + '"' + "`r`n"))
        $tmp = $tmp.Replace('#<InsertFireForgetModuleContentsHERE>',$FFmoduleContents)
        $tmp.Replace('#<InsertFireForgetArgumentsHERE>',$FFArgStr) | Out-File -FilePath "$FFStagePath\$ModuleName.ps1" -Force -Encoding ascii
        $RewrittenFFModules.Add((ls "$FFStagePath\$ModuleName.ps1"),$Modules.$_)
    }
    $Modules = $RewrittenFFModules
}


# This collection stores the relative module output paths
# for each computer in the current run
$ModulePathColl = New-Object System.Collections.ArrayList
# Done getting modules #

# Retrieve logging configuration for Splunk or GL
$LogConf = Get-LoggingConf -OutputFormat $OutputFormat
# Done getting logging config

# Get our analysis scripts #
if ($ListAnalysis) {
    # User provided ListAnalysis switch so exit
    # after returning a list of analysis scripts
    List-Modules ".\Analysis\"
    Exit
}

# Get our targets. #
if ($TargetList) {
    [System.Collections.ArrayList]$Targets = Get-Targets -TargetList $TargetList -TargetCount $TargetCount
} elseif ($Target) {
    $Targets = New-Object System.Collections.ArrayList
    [void]$Targets.Add($Target)
} else {
    Write-Verbose "No Targets specified. Building one requires RAST and will take some time."
    [void] (Load-AD)
    [System.Collections.ArrayList]$Targets  = Get-Targets -TargetCount $TargetCount
}

# Was ElkAlert specified? #
if ($ElkAlert.Count -gt 0){

    # Check OutputFormat to ensure that JSON is specified
    if ($OutputFormat -ne "JSON"){
        Write-Warning "Standard Elk Listeners expect a JSON-formatted string, but your current output format is: $OutputFormat"
        $proceed = Read-Host "Would you like to enable ElkAlert anyway (Y/N)?"
        if($proceed -eq "Y"){
            #$ElkAlert = $True
            $AutoParse = $True
        }
        else{
            $ElkAlert = @()
        }
    }
    else{
        #$ElkAlert = $True
        $AutoParse = $True
    }
}

# Finally, let's gather some data. #
# If you're just logging everything to a file, no need to pass your special logging config
if ($OutputFormat -eq "csv" -or $OutputFormat -eq "json" -or $OutputFormat -eq "tsv" -or $OutputFormat -eq "xml") {
    $index = 0
    $buffer = $ThrottleLimit

    Do{
        if (($index + $buffer) -lt $Targets.Count){
            $percentComplete = $index/$Targets.Count
            $percentComplete = "{0:P1}" -f $percentComplete
            Write-Verbose "Running module on machines $index to $($index + $buffer-1) of $($Targets.Count) ($percentComplete)`n"
            $buffTargets = $Targets[$index..($index + $buffer-1)]
        }
        else{
            $percentComplete = $index/$Targets.Count
            $percentComplete = "{0:P1}" -f $percentComplete
            $diff = ($Targets.Count - $index)
            Write-Verbose "Running module on machines $index to $($index + $diff) of $($Targets.Count) ($percentComplete)`n"
            $buffTargets = $Targets[$index..($index + $diff-1)]
        }
        Get-TargetData -Targets $buffTargets -Modules $Modules -Credential $Credential -ThrottleLimit $ThrottleLimit
    # Done gathering data. #

    # Are we running analysis scripts? #
    if ($Analysis) {
        Get-Analysis $OutputPath $StartingPath
    }
    # Done running analysis #

    $index = $index + $buffer
    }
    While($index -lt $Targets.Count)
}
# However, if you are using a special logging config, you need to send it off to Get-TargetData
elseif ($OutputFormat -eq "gl" -or $OutputFormat -eq "splunk") {
    Get-TargetData -Targets $Targets -Modules $Modules -Credential $Credential -ThrottleLimit $ThrottleLimit -LogConf $LogConf
    # Done gathering data. #
    # Are we running analysis scripts? #
    if ($Analysis) {
        Get-Analysis $OutputPath $StartingPath
    }
    # Done running analysis #
}

# Code to remove binaries from remote hosts
if ($rmbin) {
    Remove-Bindep -Targets $Targets -Modules $Modules -Credential $Credential
}
# Done removing binaries #

# Was AutoParsing requested? #
if ($AutoParse){
    if ($ElkAlert.Count -gt 0){
        AutoParse $OutputPathColl $ModulePathColl -sendElkAlert
    }
    else{
        AutoParse $OutputPathColl $ModulePathColl
    }
}

Write-Verbose "### All Done ###`n"
# Clean up #
Exit
# We're done. #

} Catch {
    ("Caught: {0}" -f $_)
} Finally {
    # Clean up 
    if (Test-Path $PSScriptRoot\IN_USE_BY_*) {
        Remove-Item $PSScriptRoot\IN_USE_BY_*
    }
    Remove-PSSession -Name *
    Remove-Job -Name * -Force
    Exit-Script
}
