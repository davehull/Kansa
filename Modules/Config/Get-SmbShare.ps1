# OUTPUT TSV
# Returns share info for this host
if (Get-Command Get-SmbShare -ErrorAction SilentlyContinue) {
    Get-SmbShare
}