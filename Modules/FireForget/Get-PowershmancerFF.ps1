# This module was created with the hypothesis that suspicious/malicious powershell scripts might be allowing adversarial
# persistent access in an environment. The module enumerates all powershell scripts and looks for keywords that might
# indicate suspicious activity. The module returns all metadata (name/size/path/MACBtimes/etc.) about all powershell
# scripts found and if a keyword match occurs then the content of the script is included also. The scripts are hashed so
# baseline scripts found throughout the environment can be suppressed based on content rather than just filename/size.
# This can help to identify outliers. If your org has a lot of powershell developers, this hunt can turn up a large
# haystack to sift through.

if(!(Get-Variable -Name regex -ErrorAction SilentlyContinue)){$regex = "memorystream"}
if(!(Get-Variable -Name FilePattern -ErrorAction SilentlyContinue)){$FilePattern = ""} # regex used for DirWalk to focus results. If blank it will match all files that meet the extensions pattern
if(!(Get-Variable -Name FileExtensions -ErrorAction SilentlyContinue)){$FileExtensions = @("*.ps1", "*.psm1")} #used exclusively for DirWalk to focus search on file extensions, 
if(!(Get-Variable -Name FileStartPath -ErrorAction SilentlyContinue)){$FileStartPath = ""} # used exclusively for DirWalk start path for recursive FILE search

$scripts = enhancedGCI -startPath $FileStartPath -extensions $FileExtensions -regex $FilePattern

foreach($s in $scripts){
    $result = @{}
    $content = gc -Force -ErrorAction SilentlyContinue $s
    $found = $false
    if($content -match $regex){
        $found = $true
        $matchingLines = ""
        $content -match $regex | %{$matchingLines += "$_`n"}
        $result.add("KeywordMatches", $matchingLines)
    }
    $result.add("KeywordFound", $found)
    if($found){
        $result = Get-FileDetails -hashtbl $result -filepath $s -computeHash -algorithm SHA256 -getMagicBytes 20 -getContent
    }else{
        $result = Get-FileDetails -hashtbl $result -filepath $s -computeHash -algorithm SHA256 -getMagicBytes 20
    }
    Add-Result -hashtbl $result
}
