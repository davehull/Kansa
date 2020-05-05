# This module is designed to enumerate the configured group-policy scripts. Since a local admin user can add custom GP scripts
# to execute at logon using the local gp editor, this is a possible persistence mechanism.  Enumerating these scripts across
# an enterprise environment will highlight deviations from the baseline as outliers to focus additional investigation and 
# threat hunting.  https://github.com/LOLBAS-Project/LOLBAS/blob/master/yml/OSBinaries/Gpscript.yml
# https://oddvar.moe/2018/04/27/gpscript-exe-another-lolbin-to-the-list/

# Iterate through GP scripts using the applicable registry keys for each user
gci REGISTRY::HKU\ | %{
    $path = "REGISTRY::$($_.Name)\Software\Microsoft\Windows\CurrentVersion\Group Policy\Scripts"; 
    if (Test-Path -PathType Container -literalpath $path) { 
        foreach ($p in (gci -Recurse $path)){
            if(test-path "REGISTRY::$p"){
                $tmp = Get-ItemProperty -ErrorAction SilentlyContinue "REGISTRY::$p" @('Script','Parameters')
                foreach($t in $tmp){
                    $r = @{}
                    $r.add("Script", $t.Script)
                    $r.add("Parameters", $t.Parameters)
                    if(Test-Path $t.Script){
                        $r = Get-FileDetails -hashtbl $r -filepath $t.Script -computeHash -algorithm @("MD5","SHA256") -getContent                   
                    }
                    Add-Result -hashtbl $r
                }
            }
        }
    }
}

# look for additional GP script persistence in this GP script INI file
if(test-path "C:\Windows\System32\GroupPolicy\User\Scripts\scripts.ini"){
    $r = @{}
    $r = Get-FileDetails -hashtbl $r -filepath $t.Script -computeHash -algorithm @("MD5","SHA256") -getContent  
    Add-Result -hashtbl $r
}

# look for additional GP script persistence in this GP script INI file
if(test-path "C:\Windows\System32\GroupPolicy\gpt.ini"){
    $r = @{}
    $r = Get-FileDetails -hashtbl $r -filepath $t.Script -computeHash -algorithm @("MD5","SHA256") -getContent  
    Add-Result -hashtbl $r
}
