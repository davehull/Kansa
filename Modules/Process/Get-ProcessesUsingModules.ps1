<# 
.SYNOPSIS
Get-ProcessesUsingModules.ps1 returns process id and process name for processes
using the modules passed as an argument.
.PARAMETER ModuleList
Required. List of modules.
.NOTES
When passing specific modules with parameters via Kansa.ps1's -ModulePath 
parameter, be sure to quote the entire string, like shown here:
.\kansa.ps1 -ModulePath ".\Modules\Disk\Get-ProcessesUsingModules.ps1 $Module_List"

A $Module_List like the one below may be interesting as these modules are loaded
when a meterpreter agent is migrated into a process like spoolsv.exe.

$Module_List = ('wininet.dll','iertutil.dll','winhttp.dll','dhcpcsvc6.dll',
'dhcpcsvc.dll','webio.dll','psapi.dll','winmm.dll','winmmbase.dll','ole32.dll',
'mpr.dll','netapi32.dll','wkscli.dll')

As with all modules that take command line parameters, you should not put
quotes around the entry in the Modules.conf file.
#>

if ($args.Count -gt 0)
{
    $ModuleList = $args
}
else 
{
    # Set the list to dlls inserted by meterpreter http reverse shell inject
    $ModuleList=('wininet.dll','iertutil.dll','winhttp.dll','dhcpcsvc6.dll',`
        'dhcpcsvc.dll','webio.dll','psapi.dll','winmm.dll','winmmbase.dll','ole32.dll',`
        'mpr.dll','netapi32.dll','wkscli.dll')
}

$ErrorActionPreference = "Continue"

:Process_Loop foreach($process in Get-Process) 
{
    $proc_id   = $process.Id
    $proc_name = $process.Name
    $mod_array = @()
    $mod_array += $process.Modules | Select-Object -ExpandProperty "ModuleName"
    $process_matches = $False
    :Mod_Loop foreach($Module in $ModuleList)
    {
        if ($Module -in $mod_array)
        {
            $process_matches = $True
        }
        else 
        {
            $process_matches = $False
            break Mod_Loop    
        }
    }

    $o = "" | Select-Object ProcessId, ProcessName
    if ($process_matches)
    {
        $o.ProcessId = $proc_id
        $o.ProcessName = $proc_name
        $o
    }
}