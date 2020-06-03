# WMI can be used for many tasks - both good and evil. This module will enumerate all WMI filters/consumers/bindings
# and send the data to ELK for aggregated analysis. A filter is like a "condition", a consumer is like an "action"
# and the binding ties conditions to actions. By inspecting the 3 separate components for deviations we can detect
# an adversary creating a new persistence mechanism using WMI or altering existing WMI filters/consumers/bindings to
# repurpose them for evil.

function CreatorSID2str {            
    param ([byte[]]$sid)            
    
    #old way of handling SIDs
    #$sb = New-Object -TypeName System.Text.StringBuilder            
    #for ($i=0; $i -lt $sid.Length; $i++){            
    #    $sb.AppendFormat("\{0}",  $sid[$i].ToString("X2")) | Out-Null            
    #}            
    #return $sb.ToString() 
    $si = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $sid, 0             
    return $si.ToString()
}

$filters = Get-WmiObject -Namespace root\Subscription -Class __EventFilter
foreach($f in $filters) { 
    $result = @{}
    $f.psobject.Properties | where Name -Match "^(name|query)" | %{
        $result.add($_.Name,$_.Value.ToString())
    }
    if($result.Count -gt 0){
        $result.add("WMItype","Filter")
        Add-Result -hashtbl $result 
    }
}

$consumers = Get-WmiObject -Namespace root\Subscription -Class __EventConsumer
foreach($c in $consumers){ 
    $result = @{}
    $c.psobject.Properties | Sort-Object -Property Name | % {
    #$c.psobject.Properties | Where Name -match "script" | % {  #first verison of this module only looked at WMI script consumers. Now we inspect them all
        if(($_.value) -and !$_.Name.tostring().StartsWith("_")){ #if value is not null and does not start with underscore (unimportant class definitions)
            if(($_.value.tostring().length -gt 4096)){
                $result.add($_.Name,$_.Value.ToString().Substring(0,4096)) #set max limit on content of this consumer to truncate and avoid lost data
                $result.add("$($_.Name)MD5", $(Get-StringHash -Algorithm MD5 -stringData $_.Value.ToString())) #hash the long script for easy de-duplication and filtering in kibana
            } elseif($_.Name -match "CreatorSID" ) {
                $result.add($_.Name,$(CreatorSID2str -sid $_.Value))
            } elseif($_.Name -notmatch "Properties|Scope|Options|Qualifiers"){ # discard some housekeeping properties
                $result.add($_.Name,$_.Value.ToString())
                # if a working directory is specified, check to see if that directory exists. Attacker may place evil callback in that location
                if($_.Name -match "WorkingDirectory"){ 
                    $workingDir = $_.Value
                    $pathExists = $(Test-path -PathType Container -Path $workingDir)
                    $result.Add("WorkingDirectoryExists",$pathExists) 
                    if($result.ContainsKey("CommandLineTemplate")){
                        $result.CommandLineTemplate -split " " | %{
                            # attempt to validate presence of specified target binary at working directory location
                            $fileExists = Test-Path -PathType Leaf -Path "$workingDir\$_"
                            if($fileExists){
                                $basename = (gi -Path "$workingDir\$_").BaseName
                                $result.Add("WorkingDirectory$($basename)Exists", "$workingDir\$_")
                                $result = Get-FileDetails -hashtbl $result -filepath "$workingDir\$_" -computeHash -algorithm @("MD5","SHA256") -getMagicBytes 6
                            }
                        }
                    }
                }
            }
        }
    }
    #Only add the result if it contains records/keys
    if($result.Count -gt 0){ 
        $result.add("WMItype","Consumer")
        Add-Result -hashtbl $result 
    }
}

$bindings = Get-WmiObject -Namespace root\Subscription -Class __FilterToConsumerBinding
foreach($b in $bindings){ 
    $result = @{}
    $b.psobject.Properties | where Name -match "^(Consumer|Filter)" | % { 
        $result.add($_.Name,$_.Value.ToString())
    }
    if($result.Count -gt 0){ 
        $result.add("WMItype","Binding") 
        Add-Result -hashtbl $result 
    }
}
