# OUTPUT txt
<#
tlistv acquires tasklist /v (verbose output includes process owner) and formats as csv
#>
& $env:windir\system32\tasklist.exe /v /fo csv