# OUTPUT tsv
# Returns a list of local administrators
& net localgroup administrators | Select-Object -Skip 6 | ? {
    $_ -and $_ -notmatch "The command completed successfully" 
} | % {
    $o = "" | Select-Object Account
    $o.Account = $_
    $o
}