<#
.SYNOPSIS
Get-DNSCache.ps1 acquires DNS cache entries from the target host.
#>

# Convert function from https://xaegr.wordpress.com/2007/01/24/decoder/
# If you try to use old cmd commands such as net, schtask etc.
# and remote OS is other than English you will ran into problem
# with gibberish encoding output with no easy fix
# This is the ONLY way i was able to find to fix this
# Example:
# ipconfig | ConvertTo-Encoding cp866 windows-1251
# Function expect a string, pass Out-String before if needed.
function ConvertTo-Encoding ([string]$From, [string]$To){  
        Begin{  
            $encFrom = [System.Text.Encoding]::GetEncoding($from)  
            $encTo = [System.Text.Encoding]::GetEncoding($to)  
        }  
        Process{  
            $bytes = $encTo.GetBytes($_)  
            $bytes = [System.Text.Encoding]::Convert($encFrom, $encTo, $bytes)  
            $encTo.GetString($bytes)  
        }  
    }  

if (Get-Command Get-DnsClientCache -ErrorAction SilentlyContinue) {
    Get-DnsClientCache | Select-Object TimeToLIve, Caption, Description, 
        ElementName, InstanceId, Data, DataLength, Entry, Name, Section, 
        Status, Type
} else {
	$current_lang = Get-Culture
	if ($current_lang.TwoLetterISOLanguageName -eq "en") {
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
	if ($current_lang.TwoLetterISOLanguageName -eq "ru") {
		$o = "" | Select-Object TimeToLive, Caption, Description, ElementName,
			InstanceID, Data, DataLength, Entry, Name, Section, Status, Type
		
		$(& ipconfig /displaydns | ConvertTo-Encoding cp866 windows-1251 | Select-Object -Skip 3 | % { $_.Trim() }) | % { 
			switch -Regex ($_) {
				"-----------" {
				}
				"Имя записи[\s|\.]+:\s(?<RecordName>.*$)" {
					$Name = ($matches['RecordName'])
				} 
				"Тип записи[\s|\.]+:\s(?<RecordType>.*$)" {
					$RecordType = ($matches['RecordType'])
				}
				"Срок жизни[\s|\.]+:\s(?<TTL>.*$)" {
					$TTL = ($matches['TTL'])
				}
				"Длина данных[\s|\.]+:\s(?<DataLength>.*$)" {
					$DataLength = ($matches['DataLength'])
				}
				"Раздел[\s|\.]+:\s(?<Section>.*$)" {
					$Section = ($matches['Section'])
				}
				"(?<Type>[^\s]+\s+\([^\)]+\))[\s\.]+:\s(?<Data>.*$)" {
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
}


<# From what I've seen root\standardcimv2 is not available on older Windows OSes so below is not
# a good substitute for ipconfig /displaydns

    Get-WmiObject -query "Select * from MSFT_DNSClientCache" -Namespace "root\standardcimv2" | Select-Object TimeToLive,
        PSComputerName, Caption, Description, ElementName, InstanceId, Data, 
        DataLength, Entry, Name, Section, Status, Type
#>