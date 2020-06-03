# One common adversarial persistence tactic is to create local user accounts in order to maintain backdoor access if the initial 
# Infection vector is remediated. In a large enterprise environment, local users should be rare and local admin accounts should
# be more rare. This module is intended to enumerate all local groups and local users in an enterprise and should make outliers
# stand out. More often than not it just finds policy violations where someone has added their domain account to the local
# admins group on a system for ease of installing software. This list of violations can be provided to Identity/Access-mgt teams
# for remediation and also used as a pivot point to further investigate esaclation paths on systems that might have been targets
# of phishing or other drive-by attacks that led to privesc due to policy violations.

$profiles = gci 'C:\Users' | where Attributes -EQ 'Directory' | select Name
$groups = Get-WmiObject Win32_Group -Filter 'LocalAccount=True' | select Caption | % { $_.Caption.ToString().Trim(($hostname+'\')) } 
foreach($group in $groups){
    if ($group -match '\\') { 
        $group = $group.Substring( ($group.IndexOf('\') + 1) , ($group.Length - $group.IndexOf('\') - 1 ))
    } else {
        $group = $group
    }   
    
    $users = net localgroup "$group" | Select-Object -Skip 6 | ? { $_ -and $_ -notmatch 'The command completed successfully' -and $_ -notmatch 'The command completed with one or more errors' } 
    foreach($u in $users){
        $ProfileCreated = ''
        $userinfo = $null
        $LastLogon = ''
        $PasswordChanged = ''
        $AccountActive = ''
        
        if ($u -match '\\') { 
            $username = $u.substring($u.indexof('\') +1, $u.Length - $u.indexof('\') - 1)
        } else {
            $username = $u
        }
        if (@($profiles).Name.Contains($username)){ $ProfileCreated = (Get-Item ('C:\Users\' + $username)).CreationTime.ToString()}


        $userinfo = net user "$username" | Select-String 'Last Logon', 'Password Last Set', 'Account Active', 'Local Group' | sort
        if ($userinfo -ne $null -and $userinfo.GetValue(1) -ne $null) { $LastLogon = $userinfo.GetValue(1) | % {$_ -split '\s\s',2} | % {$_.trim()} | Select-Object -skip 1 }
        if ($userinfo -ne $null -and $userinfo.GetValue(3) -ne $null) { $PasswordChanged = $userinfo.GetValue(3) | % {$_ -split '\s\s',2} | % {$_.trim()} | Select-Object -skip 1 }
        if ($userinfo -ne $null -and $userinfo.GetValue(0) -ne $null) { $AccountActive = $userinfo.GetValue(0) | % {$_ -split '\s\s',2} | % {$_.trim()} | Select-Object -skip 1 }
        $result = @{}        
        $result.Add("Username","$u")
        $result.Add("LocalGroup","$group")
        $result.Add("ProfileCreated","$ProfileCreated")
        $result.Add("PasswordChanged", "$PasswordChanged")
        $result.Add("AccountActive", "$AccountActive")
        $result.Add("LastLogon", "$LastLogon")
        Add-Result -hashtbl $result
    }
}

$localusers = net users | Select-Object -skip 4 | ? { $_ -and $_ -notmatch 'The command completed' } | % {$_.trim() -split '\s\s'} | ? {$_}
foreach ($user in $localusers) {
    $ProfileCreated = ''
    $userinfo = $null
    $LastLogon = ''
    $PasswordChanged = ''
    $AccountActive = ''

    $AccountActive = ''
    if (-not $RESULTS_FINAL.ToArray().Username.Contains($User)) {
        $username = $user
        if ($username -notmatch '\\' -and @($profiles).Name.Contains($username)){ $ProfileCreated = (Get-Item ('C:\Users\'+$username)).CreationTime.ToString()}
        $userinfo = net user $username | Select-String 'Last Logon', 'Password Last Set', 'Account Active', 'Local Group' | sort
        $LastLogon = $userinfo.GetValue(1) | % {$_ -split '\s\s',2} | % {$_.trim()} | Select-Object -skip 1
        $PasswordChanged = $userinfo.GetValue(3) | % {$_ -split '\s\s',2} | % {$_.trim()} | Select-Object -skip 1
        $AccountActive = $userinfo.GetValue(0) | % {$_ -split '\s\s',2} | % {$_.trim()} | Select-Object -skip 1
        $result = @{}
        $result.Add("Username", "$username")
        $result.Add("LocalGroup", "None")
        $result.Add("ProfileCreated", "$ProfileCreated")
        $result.Add("PasswordChanged", "$PasswordChanged")
        $result.Add("AccountActive", "$AccountActive")
        $result.Add("LastLogon", "$LastLogon")
        Add-Result -hashtbl $result
    }
}
