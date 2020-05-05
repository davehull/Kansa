param(
    [Parameter(Mandatory=$false,Position=0)]
        [string]$HostnameRegex=".*",
    [Parameter(Mandatory=$False,Position=1)]
        [int]$LastLogonLessThanDaysAgo = 90,
    [Parameter(Mandatory=$False,Position=2)]
        [string]$ActiveDirectorySearchBase="",
    [Parameter(Mandatory=$False,Position=3)]
        [switch]$Randomize,
    [Parameter(Mandatory=$False,Position=4)]
        [string]$outfile=""

)

Write-Host "Retrieving Targets, please be patient..."

if($LastLogonLessThanDaysAgo -gt 0){
    $today = Get-Date
    $cutoffdate = $today.AddDays(0 - $LastLogonLessThanDaysAgo)
    $targets = Get-ADComputer -Filter {(LastLogonDate -gt $cutoffdate)} -Properties Name -SearchBase $ActiveDirectorySearchBase
}else{
    $targets = Get-ADComputer -Filter {(LastLogonDate -gt 0)} -Properties Name -SearchBase $ActiveDirectorySearchBase
}

$real_targets = New-Object System.Collections.ArrayList

foreach ($tgt in $targets){
    if ($tgt.Name -match $HostnameRegex){
        [void]$real_targets.Add($tgt.Name)
    }
}

if($Randomize){ $real_targets = $real_targets | Sort-Object {Get-Random} }

if($outfile){
    $real_targets | out-file "$PSScriptRoot\$outfile" 
    Write-Host "$($real_targets.Count) Targets found"
    Write-Host "List saved to: $PSScriptRoot\$outfile"
    Write-Host "All Done!"
}else{
    Write-Host "$($real_targets.Count) Targets found"
    return $real_targets
}
