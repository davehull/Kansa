# OUTPUT TSV
# Returns Smb sessions to this host
if (Get-Command Get-SmbSession -ErrorAction SilentlyContinue) {
    Get-SmbSession
}