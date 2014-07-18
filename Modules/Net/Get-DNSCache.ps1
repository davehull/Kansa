<#
.SYNOPSIS
Get-DNSCache.ps1 acquires DNS cache entries from the target host.
.NOTES
Next line tells Kansa.ps1 how to format this script's output.
OUTPUT tsv
#>

if (Get-Command Get-DnsClientCache -ErrorAction SilentlyContinue) {
    Get-DnsClientCache | Select-Object TimeToLIve, Caption, Description, 
        ElementName, InstanceId, Data, DataLength, Entry, Name, Section, 
        Status, Type
} else {
    $o = "" | Select-Object TimeToLive, Caption, Description, ElementName,
        InstanceID, Data, DataLength, Entry, Name, Section, Status, Type
    
    $(& ipconfig /displaydns | Select-Object -Skip 3 | % { $_.Trim() }) | % { 
        switch -Regex ($_) {
            "-----------" {
            }
            "Record Name[\s|\.]+:\s(?<RecordName>.*$)" {
                $Name = ($matches['RecordName'])
            } 
            "Record Type[\s|\.]+:\s(?<RecordType>.*$)" {
                $RecordType = ($matches['RecordType'])
            }
            "Time To Live[\s|\.]+:\s(?<TTL>.*$)" {
                $TTL = ($matches['TTL'])
            }
            "Data Length[\s|\.]+:\s(?<DataLength>.*$)" {
                $DataLength = ($matches['DataLength'])
            }
            "Section[\s|\.]+:\s(?<Section>.*$)" {
                $Section = ($matches['Section'])
            }
            "(?<Type>[A-Za-z()\s]+)\s.*Record[\s|\.]+:\s(?<Data>.*$)" {
                $Type,$Data = ($matches['Type'],$matches['Data'])
                $o.TimeToLive  = $TTL
                $o.Caption     = ""
                $o.Description = ""
                $o.ElementName = ""
                $o.InstanceId  = ""
                $o.Data        = $Data
                $o.DataLength  = $DataLength
                $o.Entry       = $Entry
                $o.Name        = $Name
                $o.Section     = $Section
                $o.Status      = ""
                $o.Type        = $Type
                $o
            }
            "^$" {
                $o = "" | Select-Object TimeToLive, Caption, Description, ElementName,
                InstanceID, Data, DataLength, Entry, Name, Section, Status, Type
            }
            default {
                $Entry = $_
            }
        }
    }
}

<# From what I've seen root\standardcimv2 is not available on older Windows OSes so below is not
# a good substitute for ipconfig /displaydns

    Get-WmiObject -query "Select * from MSFT_DNSClientCache" -Namespace "root\standardcimv2" | Select-Object TimeToLive,
        PSComputerName, Caption, Description, ElementName, InstanceId, Data, 
        DataLength, Entry, Name, Section, Status, Type
#>