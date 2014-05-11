# OUTPUT tsv
<#
tlistm acquires tasklist /m (includes process modules) and formats as csv
#>
& $env:windir\system32\tasklist.exe /m /fo csv | Select-Object -Skip 1 | % {
    $o = "" | Select-Object ImageName, PID, Modules
    $row = $_ -replace '(,)(?=(?:[^"]|"[^"]*")*$)', "`t" -replace "`""
    $o.ImageName,
    $o.PID,
    $o.Modules = ( $row -split "`t" )
    $o
}