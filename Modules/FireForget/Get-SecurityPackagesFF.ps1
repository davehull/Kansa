# This is a simple module to enumerate all Security Service Providers (SSP). Since one mimikatz method of obtaining
# credentials in cleartext is to register a rogue/malicious SSP that hooks into lsass and writes credentials to an
# attacker specified path for collection. 

$path = "REGISTRY::HKLM\System\CurrentControlSet\Control\Lsa\"
$key = "Security Packages"
$data= Get-Item -LiteralPath ($path) | Get-ItemProperty -name $key | Select-Object -ExpandProperty $key;

foreach($d in $data){
    #If the key value is not empty, add it to results.
    if($d -match "[a-z0-9]"){
        
        $text = $d.toString()
        $bytes = [System.Text.Encoding]::Unicode.GetBytes($text)
        $encodedText =[Convert]::ToBase64String($bytes)
        
        $result = @{}
        $result.add("Path", $path)
        $result.add("Name", $key)
        $result.add("Data", $text)
        $result.add("DataBase64", $encodedText)

        Add-Result -hashtbl $result
    }
}
