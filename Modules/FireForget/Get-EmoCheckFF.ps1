# In 2020 the Japanese CERT released an opensource tool to check for common IOCs related
# to emotet infections.  This is a powershell variant of their tool to check for those
# IOCs.
# https://github.com/JPCERTCC/EmoCheck

$wordlist = "(duck|mfidl|targets|ptr|khmer|purge|metrics|acc|inet|msra|symbol|driver|sidebar|restore|msg|volume|cards|shext|query|roam|etw|mexico|basic|url|createa|blb|pal|cors|send|devices|radio|bid|format|thrd|taskmgr|timeout|vmd|ctl|bta|shlp|avi|exce|dbt|pfx|rtp|edge|mult|clr|wmistr|ellipse|vol|cyan|ses|guid|wce|wmp|dvb|elem|channel|space|digital|pdeft|violet|thunk){2}"
$match = $false

function enhancedGCIFolders{
    Param([String]$startPath,[String]$regex,[String[]]$extensions,[switch]$folder)
    if ($startPath -like '*\AppData\Local\Box*'){
        Return
    }
    try{
        if($folder){
            $firstPass = [IO.Directory]::EnumerateDirectories($startPath)
            if($regex){
                $firstPass | where-object {$_ -Match $regex}
            }else{
                $firstPass
            } 
            
            $firstPass | % {
                if ([IO.File]::GetAttributes($_) -NotLike '*ReparsePoint*'){
                    enhancedGCIFolders -startPath $_ -regex $regex -folder
                }
            }
        }else{
            foreach ($extension in $extensions){
                $firstPass = [IO.Directory]::EnumerateFiles($startPath, $extension)
                if($regex){
                    $firstPass | where-object {$_ -Match $regex}
                }else{
                    $firstPass
                } 
            }
            [IO.Directory]::EnumerateDirectories($startPath) | % { 
                if ([IO.File]::GetAttributes($_) -NotLike '*ReparsePoint*'){
                    enhancedGCIFolders -startPath $_ -regex $regex -extensions $extensions
                }
            }
        }
    } catch {
    }
}

$folders = enhancedGCIFolders -startPath $env:systemdrive\Users\ -regex $wordlist -folder
$folders |%{
    $match = $false
    if($_ -match $wordlist){
        $match = $true
        $result = @{}
        $result.add("EmotetMatch",$match)
        $result.add("EmotetMatchFolder",$_)
        Add-Result -hashtbl $result
        $files = gci -force -File -ErrorAction SilentlyContinue $_
        foreach ($f in $files){
            $r = @{}
            $r = Get-FileDetails -hashtbl $r -filepath $f.FullName -computeHash -algorithm @("MD5","SHA256") -getMagicBytes 4
            Add-Result -hashtbl $r
        }
    }
}
if(!$match){
    $result = @{}
    $result.add("EmotetMatch",$match)
    Add-Result -hashtbl $result
}
