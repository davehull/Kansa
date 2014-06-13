# OUTPUT tsv
<#
.SYNOPSIS
Get-DNSCache.ps1 acquires DNS cache entries from the target host.
#>

<#
if (Get-Command Get-DnsClientCache) {
    Get-DnsClientCache
} else {
#>
    $(& ipconfig /displaydns | % {
        $_ = $_.Trim()
        if ($_ -and $_ -notmatch "-------") { 
            $_ 
        }
    }) | Select-Object -Skip 1 | % { 
        $o = "" | Select-Object TTL, Caption, Description, ElementName,
        InstanceID, Data, DataLength, Entry, Name, Section, Status, 
        TimeToLive, Type
        switch -Regex ($_) {
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
            "(?<Type>[A-Za-z]+)\s.*Record[\s|\.]+:\s(?<Data>.*$)" {
                $Type,$Data = ($matches['Type'],$matches['Data'])
            }
            default {
                $Entry = $_
            }
        }
        $o.TTL         = $TTL
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
        $o.TimeToLive  = $TTL
        $o.Type        = $Type
        $o
    }
<#    }
}


        $_.ToString().Split(' ')[-1] } | `
      Select-Object -Unique | sort | % {
        $o = "" | Select-Object FQDN
        $o.FQDN = $_
        $o
    }
}
#>