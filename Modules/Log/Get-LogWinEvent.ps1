<# 
.SYNOPSIS
    Get-LogWinEvent
.PARAMETER Params
    A required parameter. I'll call this a pseudo parameter. This is due to the fact that you, the user, is really providing 3 parameters
    worth of information that later gets parsed out in to separate parameters.

    The format for this parameter follows this syntax: log name(s) [separated by a pipe if you want to specify more than one]-days ago-event IDs [separated
    by a pipe if you want to specify more than one].
        
    Note: when used with Kansa.ps1, parameters must be positional. Named params are not supported.

.EXAMPLE
    Single log, no additional filtering:
    Get-LogWinEvent.ps1 Security

.EXAMPLE
    Multiple logs, over the past 7 days, with specified Event IDs
    Get-LogWinEvent.ps1 Security|System-7-4625|4634|4798|267|507
.EX
.NOTES
    When passing specific modules with parameters via Kansa.ps1's -ModulePath parameter, be sure to quote the entire string, like shown
    here:
    .\kansa.ps1 -Target localhost -ModulePath ".\Modules\Log\Get-LogWinEvent.ps1 Security"
    
    Thanks to Jeff Hicks for providng the Convert-EventLogRecord function, which allows for enhanced event log collections!
    Original blog post found here: https://jdhitsolutions.com/blog/powershell/7193/better-event-logs-with-powershell/

Next line is required by Kansa for proper handling of this script's
output.
OUTPUT TSV
#>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True,Position=0)]
        [String]$Params
    )

    $unparsedLogSelection = ($params -split "-")[0]
    $daysAgo = ($params -split "-")[1]
    $unparsedEventIDs = ($params -split "-")[2]

    # At a minimum, the user needs to specify at least one log name. If a valid log name is not specified,
    # The script fails.
    [String[]]$LogName = $unparsedLogSelection -split "\|"

    # Add a check to see if $daysAgo is populated - technically, it is an optional parameter.
    # If the user declined to specify, set $daysAgo to $null and search through all the logs.
    if ($daysAgo -eq $null) {
        $daysAgo = $null
    }
    else {
        [int]$daysAgo = $daysAgo
    }

    # Add a check to see if we need to populate $EventIDs. It too is an optional patameter.
    # If the user declined to specify a list of event ids, set the parameter to $null and get all of the
    # event ids for the specified log(s).
    if ($unparsedEventIDs -eq $null) {
        $EventIDs = $null
    }
    else {
        [String[]]$EventIDs = $unparsedEventIDs -split "\|"
    }

    Function Convert-EventLogRecord {

        [cmdletbinding()]
        [alias("clr")]

        Param(
            [Parameter(Position = 0, Mandatory, ValueFromPipeline)]
            [ValidateNotNullorEmpty()]
            [System.Diagnostics.Eventing.Reader.EventLogRecord[]]$LogRecord
        )

        Begin {
            Write-Verbose "[BEGIN  ] Starting: $($MyInvocation.Mycommand)"
        } #begin

        Process {
            foreach ($record in $LogRecord) {
                Write-Verbose "[PROCESS] Processing event id $($record.ID) from $($record.logname) log on $($record.machinename)"
                Write-Verbose "[PROCESS] Creating XML data"
                [xml]$r = $record.ToXml()

                $h = [ordered]@{
                    LogName     = $record.LogName
                    RecordType  = $record.LevelDisplayName
                    TimeCreated = $record.TimeCreated
                    ID          = $record.Id
                }

                if ($r.Event.EventData.Data.Count -gt 0) {
                    Write-Verbose "[PROCESS] Parsing event data"
                    if ($r.Event.EventData.Data -is [array]) {
                    <#
                     I only want to enumerate with the For loop if the data is an array of objects
                     If the data is just a single string like Foo, then when using the For loop,
                     the data value will be the F and not the complete string, Foo.
                     #>
                    for ($i = 0; $i -lt $r.Event.EventData.Data.count; $i++) {

                        $data = $r.Event.EventData.data[$i]
                        #test if there is structured data or just text
                        if ($data.name) {
                            $Name = $data.name
                            $Value = $data.'#text'
                        }
                        else {
                            Write-Verbose "[PROCESS] No data property name detected"
                            $Name = "RawProperties"
                            #data will likely be an array of strings
                            [string[]]$Value = $data
                        }

                        if ($h.Contains("RawProperties")) {
                            Write-Verbose "[PROCESS] Appending to RawProperties"
                            $h.RawProperties += $value
                        }
                        else {
                            Write-Verbose "[PROCESS] Adding $name"
                            $h.add($name, $Value)
                        }
                    } #for data
                    } #data is an array
                    else {
                        $data = $r.Event.EventData.data
                        if ($data.name) {
                            $Name = $data.name
                            $Value = $data.'#text'
                        }
                        else {
                            Write-Verbose "[PROCESS] No data property name detected"
                            $Name = "RawProperties"
                            #data will likely be an array of strings
                            [string[]]$Value = $data
                        }

                        if ($h.Contains("RawProperties")) {
                            Write-Verbose "[PROCESS] Appending to RawProperties"
                            $h.RawProperties += $value
                        }
                        else {
                            Write-Verbose "[PROCESS] Adding $name"
                            $h.add($name, $Value)
                        }
                    }
                } #if data
                else {
                    Write-Verbose "[PROCESS] No event data to process"
                }

                $h.Add("Message", $record.Message)
                $h.Add("Keywords", $record.KeywordsDisplayNames)
                $h.Add("Source", $record.ProviderName)
                $h.Add("Computername", $record.MachineName)

                Write-Verbose "[PROCESS] Creating custom object"
                New-Object -TypeName PSObject -Property $h
            } #foreach record
        } #process

        End {
            Write-Verbose "[END    ] Ending: $($MyInvocation.Mycommand)"
        } #end
    } #end Convert-EventLogRecord

    If ($DaysAgo -eq $null) {
        $StartDate = $($(Get-WinEvent -LogName Security -Oldest -MaxEvents 1).TimeCreated)
        $EndDate = Get-Date
        $Span = $(New-TimeSpan -Start $StartDate -End $EndDate).Days
    } # end If
    Else {$Span = $DaysAgo} # end else

    $StartTime = (Get-Date).AddDays(-$Span)

    if ($EventIDs.Count -eq 0) {
        ForEach ($log in $LogName) {
            Get-WinEvent -FilterHashtable @{ Logname=$LogName; StartTime=$StartTime} -EA SilentlyContinue  | Convert-EventLogRecord
        } # end ForEach ($log in LogName)
    } # end If
    else {
        ForEach ($log in $LogName) {
            ForEach ($id in $EventIDs) {
                Get-WinEvent -FilterHashtable @{ Logname=$LogName; StartTime=$StartTime; ID=$id} -EA SilentlyContinue  | Convert-EventLogRecord
            } # end inner ForEach ($id in $EventIDs)
        } # end outter ForEach ($log in LogName)
    } # end else
