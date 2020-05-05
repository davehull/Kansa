# For enterprises that may not have the executive support or logging infrastructure to support enabling 
# Powershell scriptblock/module logging via GPO, this is a great alternative.  It will collect powershell
# history from all users and send them all to the threat hunting ELK cluster for on-demand analysis

$users = Get-ChildItem C:\Users

foreach($user in $users){
    if(Test-Path -Path  C:\Users\$user\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt){
        $psHistory = Get-Content C:\Users\$user\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadline\ConsoleHost_history.txt
        $line = 0
        foreach($cmd in $psHistory){
            $result = @{}
            $result.add("CommandLine", $cmd)

            $sha256 = Get-StringHash -stringData $cmd -Algorithm "SHA256"
            $result.add("SHA256", $sha256)

            $md5 = Get-StringHash -stringData $cmd -Algorithm "MD5"
            $result.add("MD5", $md5)

            $prefix = $cmd.split()[0]
            $result.add("Prefix", $prefix)
            
            $result.add("User", $user.Name.toString()) 
            $result.add("Line", $line++)
            
            Add-Result -hashtbl $result
        }
    }
}
