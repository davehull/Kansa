# This module has the capability to read a local endpoint file index to search for indexed files by
# SHA256 hash or file/path name. The file index resides in a SQLite DB. The module uses a well-known
# dll to gain native powershell SQLite capabilties. If the DLLs are not available for this OS
# processor architecture it can download them from a necromancer stating server using REST API calls
# To be considerate of endpoint resources (especially RAM for large databases or many queries, the
# function can load the entire DB into memory or query from disk row by row. Tradeoffs in RAM/DiskIO
# will occur with various methods of operation. User can also designate an abort action if the DB is
# too large to query safely.

if(!(Get-Variable -Name necroSvr -ErrorAction SilentlyContinue)){$necroSvr = @("127.0.0.1")}
if(!(Get-Variable -Name necroPort -ErrorAction SilentlyContinue)){$necroPort = @(80)}
if(!(Get-Variable -Name huntFolder -ErrorAction SilentlyContinue)){$huntFolder = "$env:SystemDrive\Temp\"}
if(!(Get-Variable -Name SQLfilter -ErrorAction SilentlyContinue)){$SQLfilter = '%'} # '%.exe' filter to use in SQL query to restrict records returned to minimum necessary
if(!(Get-Variable -Name SQLFilePattern -ErrorAction SilentlyContinue)){$SQLFilePattern = ""} # regex used for SQL query to focus results
if(!(Get-Variable -Name SHA256hashes -ErrorAction SilentlyContinue)){$SHA256hashes = @()} # array of SHA256 hashes passed in at runtime to query against the DB
if(!(Get-Variable -Name downloadHashes -ErrorAction SilentlyContinue)){$downloadHashes = ""} # if present specifies the name of a line-delimited SHA256 hashlist to download from the REST-API server. This is necessary when passing in LARGE lists of hashes
if(!(Get-Variable -Name DBPath -ErrorAction SilentlyContinue)){$DBpath = ""} # path to endpoint file index DB
if(!(Get-Variable -Name DBTable -ErrorAction SilentlyContinue)){$DBTable = ""} # DB table that contains the data we want, filenames, SHA256 hashes, etc...
if(!(Get-Variable -Name DBMaxSize -ErrorAction SilentlyContinue)){$DBMaxSize = [long]40000000} # Tipping point size of DB that causes module to throttle/change query strategy to conserve resources
if(!(Get-Variable -Name DBMaxAction -ErrorAction SilentlyContinue)){$DBMaxAction = "QueryEachRow"} #QueryEachRow #Abort #Normal
if(!(Get-Variable -Name DBQueryMethod -ErrorAction SilentlyContinue)){$DBQueryMethod = "Normal"} # QueryEachRow #Abort #Normal #None #NoFilter?
if(!(Get-Variable -Name Algorithms -ErrorAction SilentlyContinue)){$Algorithms = @("MD5","SHA256")} #Hash algorithms to use if the file still exists
if(!(Get-Variable -Name GetContent -ErrorAction SilentlyContinue)){$GetContent = $false} # Try to collect full file contents if the target file is found (avoid binary or unicode filetypes if possible)
if(!(Get-Variable -Name GetMagicBytes -ErrorAction SilentlyContinue)){$GetMagicBytes = 4} # Number of header bytes to sample for files that still exist

if(!(Get-Variable -Name DirWalk -ErrorAction SilentlyContinue)){$DirWalk = $False} # Flag to indicate module should ALSO crawl filesystem to look for files
if(!(Get-Variable -Name DirWalkFolder -ErrorAction SilentlyContinue)){$DirWalkFolder = $False} # Starting folder for recursive filesystem search for folders
if(!(Get-Variable -Name FolderPattern -ErrorAction SilentlyContinue)){$FolderPattern = ""} # regex to refine search parameters when looking for folders
if(!(Get-Variable -Name FilePattern -ErrorAction SilentlyContinue)){$FilePattern = ""} # "\.exe" regex used for DirWalk to focus results
if(!(Get-Variable -Name FileExtensions -ErrorAction SilentlyContinue)){$FileExtensions = @("*.exe")} #used exclusively for DirWalk to focus search on file extensions, 
if(!(Get-Variable -Name FileStartPath -ErrorAction SilentlyContinue)){$FileStartPath = "$env:SystemDrive\Users\"} # used exclusively for DirWalk start path for recursive FILE search

# Select a Necromancer REST API server to pull down requisite SQLite DLLs if necessary
$rndSvr = Get-Random -InputObject $necroSvr
$rndPort = Get-Random -InputObject $necroPort
$killDelayMin = [Int](($killDelay + 600) / 60) # add 10min wiggleroom
$urlFileDownload = "http://$rndSvr"+':'+"$rndPort/stage/dl/"
$urlFinFlag = "http://$rndSvr"+':'+"$rndPort/fin" #REST endpoint to signal scan completion for temp suppressions
$dlls = @("SQLite.Interop.32.dll", "SQLite.Interop.64.dll", "System.Data.SQLite.32.dll", "System.Data.SQLite.64.dll")

if($downloadHashes){
    $hashlist = [char[]](Invoke-WebRequest $($urlFileDownload+$downloadHashes) | Select-Object -ExpandProperty Content) -join ""
    $SHA256hashes += $hashlist.ToString() -replace "`r`n","`n" -split "`n"
}

if((Test-Path $huntFolder) -eq $false){ New-Item -ItemType directory -Path $huntFolder | Out-Null }
If(Test-Path -PathType Leaf "$huntFolder\System.Data.SQLite.dll"){Remove-Item -Force "$huntFolder\System.Data.SQLite.dll"}
If(Test-Path -PathType Leaf "$huntFolder\SQLite.Interop.dll"){Remove-Item -Force "$huntFolder\SQLite.Interop.dll"}
foreach ($d in $dlls){
    if((Test-Path "$huntFolder\$d") -eq $false){
        Invoke-WebRequest $($urlFileDownload+$d) -OutFile $("$huntFolder\"+$d)
    }
    
}


if ($procBitness -eq 64){
    rename-item "$huntFolder\System.Data.SQLite.64.dll" "$huntFolder\System.Data.SQLite.dll"
    rename-item "$huntFolder\SQLite.Interop.64.dll" "$huntFolder\SQLite.Interop.dll"
} else {    
    rename-item "$huntFolder\System.Data.SQLite.32.dll" "$huntFolder\System.Data.SQLite.dll"
    rename-item "$huntFolder\SQLite.Interop.32.dll" "$huntFolder\SQLite.Interop.dll"
}

$endresult = @{}
$endresult.add("KansaModule",$moduleName)
$endresult.add("Hostname",$hostname)
$endresult.add("SQLDBpath",$DBpath)
$endresult.add("SQLDBtable",$DBTable)
$endresult.add("SQLDBMaxSize",[long]$DBMaxSize)
$endresult.add("DBQueryMethod",$DBQueryMethod)
$endresult.add("ModuleProcessBitness", $procBitness)
$endresult.add("SQLFilter", $SQLfilter)
$endresult.add("FilePattern", $FilePattern)
$endresult.add("SQLFilePattern", $SQLFilePattern)
$endresult.add("SHA256HashCount", $SHA256hashes.Count)
$endresult.add("DownloadedHashFile", $downloadHashes)
$endresult.add("Algorithms", $Algorithms)
$endresult.add("GetFileContent", $GetContent)
$endresult.add("DirWalk", $DirWalk)
$endresult.add("GetMagicBytes", $GetMagicBytes)
$endresult.add("FileExtensions", $FileExtensions)
$endresult.add("FileStartPath", $FileStartPath)
$endresult.add("DirWalkFolder", $DirWalkFolder)
[long]$SQLDBSize = 0

$tmp = $null
if($DBQueryMethod -notmatch "None"){
    if(Test-Path -LiteralPath $DBpath){
        $tmp1 = @()
        $tmp2 = @()
        $data = $null
        $SQLDBSize = [long]((gi -LiteralPath $DBpath).Length)
        if(($SQLDBSize -gt $DBMaxSize) -or ($SQLfilter -match "^\%$")){
            $DBQueryMethod = $DBMaxAction
        }

        if($DBQueryMethod -match "Normal"){ 
            Add-Type -Path "$huntFolder\System.Data.SQLite.dll"
            $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
            $con.ConnectionString = "Data Source=$DBpath"
            $con.Open()
            $sql = $con.CreateCommand()

            $sql.CommandText = "SELECT * FROM $DBTable WHERE path LIKE '$SQLfilter' ESCAPE '\'"
            $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
            $data = New-Object System.Data.DataSet
            [void]$adapter.Fill($data)

            if($SQLFilePattern -and ($data.tables.rows -ne $null)){
                $tmp1 = $data.tables.rows | where path -Match $SQLFilePattern
            }
            if($SHA256hashes -and ($data.tables.rows -ne $null)){
                $tmp2 = $data.tables.rows | where sha256 -Contains $SHA256hashes
            }
            $tmp = $tmp1 + $tmp2
            $tmp = $tmp | ?{($_ -ne $null) -and ($_.path -ne "")}
        }elseif($DBQueryMethod -match "QueryEachRow"){
            Add-Type -Path "$huntFolder\System.Data.SQLite.dll"
            $con = New-Object -TypeName System.Data.SQLite.SQLiteConnection
            $con.ConnectionString = "Data Source=$DBpath"
            $con.Open()

            if($SQLFilePattern){
                if($SQLfilter -eq '%'){
                    #crude attempt to convert a regex filter to a SQL query filter - best effort here.  Analyst should be cognizant of limitations
                    $tmpFilter = $SQLFilePattern -replace '\.\*','%' -replace '\.','_' -replace '\*','%' -replace '\\d','[0-9]' -replace '\+','%' -replace "\{.\}",'%' -replace '\{.+\}','%' -replace "'","''" -replace '(^\^|\$$|\(|\))','' -replace '\|',"%' OR path LIKE '%"
                    $SQLfilter = "%$tmpFilter%"
                }
                $sql = $con.CreateCommand()
                $sql.CommandText = "SELECT * FROM $DBTable WHERE path LIKE '$SQLfilter' ESCAPE '\'"
                $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
                $data = New-Object System.Data.DataSet
                [void]$adapter.Fill($data)
                if($data.tables.rows -ne $null){$tmp1 = $data.tables.rows | where path -Match $SQLFilePattern}
            }

            if($SHA256hashes){
                foreach($hash in $SHA256hashes){
                    $sql = $con.CreateCommand()
                    $sql.CommandText = "SELECT * FROM $DBTable WHERE sha256 LIKE '$hash'"
                    $adapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter $sql
                    $data = New-Object System.Data.DataSet
                    [void]$adapter.Fill($data)
                    if($data.tables.rows -ne $null){$tmp2 += $data.tables.rows}
                }
            }
            $tmp = $tmp1 + $tmp2
            $tmp = $tmp | ?{($_ -ne $null) -and ($_.path -ne "")}
        }
        $tmp1 = $null
        $tmp2 = $null
        $data = $null
        [System.GC]::Collect()
    } else {
        $endresult.SQLDBpath = "NotFound"
    }
}else{
    $endresult.SQLDBpath = "NotQueried"
}
$endresult.Add("DBHitCount", $tmp.Table.Rows.Count)

# Iterate through all hits from the SQLite DB and check to see if the file is still present on disk
foreach ($t in $tmp){
    if(($t -ne "") -and ($t -ne $null)){
        $result = @{}
        $result.add("SQLDBpath",$DBpath)
        $result.add("DBQueryMethod",$DBQueryMethod)
        $result.add("Path", $t.path)
        $result.add("SHA256", $t.sha256)
        $result.add("ModuleProcessBitness", $procBitness)
        $present = $false
        if( $(test-path -LiteralPath $t.path) ) {
            $present = $true
            if($GetContent){
                $result = Get-FileDetails -hashtbl $result -filepath $t.path -computeHash -algorithm $Algorithms -getMagicBytes $GetMagicBytes -getContent
            }else{
                $result = Get-FileDetails -hashtbl $result -filepath $t.path -computeHash -algorithm $Algorithms -getMagicBytes $GetMagicBytes
            }        
        }
        $result.add("StillPresent", $present)
        Add-Result -hashtbl $result
    }
}




$folders = ""
if($DirWalkFolder){
    If($FileStartPath -eq ""){
        foreach($drive in $(gdr -PSProvider 'FileSystem' | select Name).Name){
            $folders += enhancedGCI -startPath "$drive`:\" -regex $FolderPattern -folder
        }
    }else{
        $folders = enhancedGCI -startPath $FileStartPath -regex $FolderPattern -folder
    }
    
    $folders | %{
        $result = @{}
        $result.Add("FoundFolder", $_)
        Add-Result -hashtbl $result
    }
}

[string[]]$files = @()
if($DirWalk){
    if($DirWalkFolder){
        $files = $folders | %{enhancedGCI -startPath $_ -extensions $FileExtensions -regex $FilePattern}
    }else{
        $files = enhancedGCI -startPath $FileStartPath -extensions $FileExtensions -regex $FilePattern
    }
    $files | %{
        $result = @{}
        if($GetContent){
            $result = Get-FileDetails -hashtbl $result -filepath $_ -computeHash -algorithm $Algorithms -getMagicBytes $GetMagicBytes -getContent
        }else{
            $result = Get-FileDetails -hashtbl $result -filepath $_ -computeHash -algorithm $Algorithms -getMagicBytes $GetMagicBytes
        } 
        Add-Result -hashtbl $result
    }
}

$endresult.Add("SQLDBSize",[long]$SQLDBSize)
$endresult.DBQueryMethod = $DBQueryMethod  
$endresult.Add("DirWalkFolderCount",$folders.Count)
$endresult.Add("DirWalkFileCount",$files.Count)
Add-Result -hashtbl $endresult

if ($procBitness -eq 64){
    rename-item "$huntFolder\System.Data.SQLite.dll" "$huntFolder\System.Data.SQLite.64.dll"
    rename-item "$huntFolder\SQLite.Interop.dll" "$huntFolder\SQLite.Interop.64.dll"
} else {    
    rename-item "$huntFolder\System.Data.SQLite.dll" "$huntFolder\System.Data.SQLite.32.dll"
    rename-item "$huntFolder\SQLite.Interop.dll" "$huntFolder\SQLite.Interop.32.dll"
}
