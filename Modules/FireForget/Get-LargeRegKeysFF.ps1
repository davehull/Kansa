# This module is designed to enumerate large registry keys to look for "fileless malware" or other persistence techniques by
# encoding/storing malicious code/instructions in the registry. It pulls down a copy of the registryExplorer Cmdline utility
# RECmd.exe developed by Eric Zimmerman to quickly/efficiently traverse the registry and identify registry key/values longer
# than $minRegKeySize bytes. https://github.com/EricZimmerman/RECmd
# The key/values that meet the criteria are sent back to ELK for aggregation and also hashed to allow for easier whitelisting

if(!(Get-Variable -Name necroSvr -ErrorAction SilentlyContinue)){$necroSvr = @("127.0.0.1")}
if(!(Get-Variable -Name necroPort -ErrorAction SilentlyContinue)){$necroPort = @(80)}
if(!(Get-Variable -Name huntFolder -ErrorAction SilentlyContinue)){$huntFolder = "$env:SystemDrive\Temp\"}
if(!(Get-Variable -Name minRegKeySize -ErrorAction SilentlyContinue)){$minRegKeySize = 10000}

#If the Hunt folder does not exist create it
if(!(Test-Path -PathType Container "$huntFolder")){ New-Item -ItemType directory -Path $huntFolder | Out-Null }
[String]$necroSvr= Get-Random -InputObject $necroSvr
[int]$necroPort = Get-Random -InputObject $necroPort

$urlFileDownload = "http://$necroSvr"+':'+"$necroPort/stage/dl/RECmd.exe"

#If the file is not already in the path, download it to the path.
if(!(Test-Path -PathType Leaf "$huntFolder\RECmd.exe")){
    Invoke-WebRequest $urlFileDownload -OutFile "$huntFolder\RECmd.exe"
}

#Collect the registry keys with RECmd                           You shall not pass
$pinfo = New-Object System.Diagnostics.ProcessStartInfo
$pinfo.FileName = "$huntFolder\RECmd.exe"
$pinfo.RedirectStandardError = $true
$pinfo.RedirectStandardOutput = $true
$pinfo.UseShellExecute = $false
$pinfo.Arguments = '-d "C:\Windows\System32\Config" --MinSize '+$minRegKeySize
$p = New-Object System.Diagnostics.Process
$p.StartInfo = $pinfo
[void]$p.Start()
$stdout = $p.StandardOutput.ReadToEnd()
$stderr = $p.StandardError.ReadToEnd()
$p.WaitForExit()
$keys = $stdout

#Parse the output and send
#Example Output: "Key: ControlSet001\Control\Session Manager\AppCompatCache, Value: AppCompatCache, Size: 185,608"
foreach($line in $keys){
	 Write-Output $line
    if($line.StartsWith("Processing hive")){
        $hive = $line.split("\")[-1].Replace("'", "");
    }
    if($line.StartsWith("Key:")){
            $result = @{}

            $key = $line.split(",")[0].Replace("Key: ", "")
            $result.add("Key", $key);

            $value = $line.split(",")[1].Replace(" Value: ", "")
            $result.add("Value", $value);

            #The numbers have commas ugh, split by space and grab the last element.
            $size = $line.split(" ")[-1]
            $result.add("Size", $size);

            $result.add("Hive", $hive);

            $TypeNameOfValue = (Get-ItemProperty -LiteralPath ("REGISTRY::HKLM\$hive\$key") -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $value).GetType();
            $result.add("Type", $TypeNameOfValue.toString())
            
            $data = (Get-ItemProperty -LiteralPath "REGISTRY::HKLM\$hive\$key" -ErrorAction SilentlyContinue -Name $value).$value

            #If the data type is not a string get Base64 encoding, else send it up!
            if($TypeNameOfValue -eq [string]){
                $result.add("Data", $data);
            }else{
                $result.add("Data",  [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($data)));   
            }
            
            $SHA256 = Get-StringHash -stringData $data; -Algorithm "SHA256"
            $result.add("SHA256", $SHA256);

            Add-Result -hashtbl $result
    }
}

#Remove the file once we are done
if(Test-Path -PathType Leaf "$huntFolder\RECmd.exe"){ Remove-Item -Force -Path "$huntFolder\RECmd.exe" | Out-Null }
