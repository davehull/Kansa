<#
.SYNOPSIS
Get-WebrootListing.ps1 returns a recursive listing of files in a web server's 
document root and their Shannon entropy. Comparing these items may allow you 
identify web shells left behind by attackers to enable re-compromise after 
remediation. Files with high entropy are likely compressed or encrypted, so
may contain exfiltration or obfuscated code.

Bits of entropy for a file is calculated using the standard Shannon Entropy 
algorithm where the total entropy equals the sum of the probability of each
byte multiplied by the natural log of the probability of that byte. The sign
is flipped by multiplying the result by -1 since the natural log of a number
between 0 and 1 is always negative.

More clearly:
  H = SUM(-1 * Pi * LOG2(Pi))

.PARAMETER BasePath
Optional base path to start the listing. Uses IIS's default of C:\inetpub\wwwroot
if this isn't provided.
.PARAMETER extRegex
Optional. Files must match the regex to be included in output. Defaults to all
files ("\..*$").
.PARAMETER MinB
Optional. Minimum size of files to check in bytes. Defaults to 0.
.PARAMETER MaxB
Optional. Maximum size of files to check in bytes. Defaults to 281474976645120
(the maximum possible file size on Windows 8.1/Server 2012 R2 systems using the
default cluster size).
.NOTES
Next line is required by kansa.ps1 for proper handling of script output
OUTPUT tsv
.LINK
http://en.wikipedia.org/wiki/Entropy_(information_theory)
http://en.wiktionary.org/wiki/Shannon_entropy
#>

Param(
    [Parameter(Mandatory=$False,Position=0)]
        [string]$BasePath="C:\inetpub\wwwroot",
    [Parameter(Mandatory=$False,Position=1)]
        [string]$extRegex="\..*$",
    [Parameter(Mandatory=$False,Position=2)]
        [long]$MinB=0,
    [Parameter(Mandatory=$False,Position=3)]
        [long]$MaxB=281474976645120
)

if (Test-Path $BasePath -PathType Container) {

        $files = (
            Get-ChildItem -Force -Path $BasePath -Recurse -ErrorAction SilentlyContinue |
            ? -FilterScript {
                ($_.Extension -match $extRegex) -and
                ($_.Length -ge $MinB -and $_.Length -le $MaxB)
            }
        )

        foreach ($childItem in $files) {
            $fileEntropy = 0.0
            $byteCounts = @{}
            $byteTotal = 0
            
            # Folders don't really have entropy, so we'll skip calculating it for them.
            if(Test-Path $childItem.FullName -PathType Leaf) {
                $fileName = $childItem.FullName
                $fileBytes = [System.IO.File]::ReadAllBytes($fileName)

                foreach ($fileByte in $fileBytes) {
                    $byteCounts[$fileByte]++
                    $byteTotal++
                }

                foreach($byte in 0..255) {
                    $byteProb = ([double]$byteCounts[[byte]$byte])/$byteTotal
                    if ($byteProb -gt 0) {
                        $fileEntropy += (-1 * $byteProb) * [Math]::Log($byteProb, 2.0)
                    }
                }
            }
        
            $o = "" | Select-Object FullName, Length, CreationTimeUtc, LastAccessTimeUtc, LastWriteTimeUtc, Entropy
            $o.FullName = $childItem.FullName
            $o.Length   = $childItem.Length
            $o.CreationTimeUtc = $childItem.CreationTimeUtc
            $o.LastAccesstimeUtc = $childItem.LastAccessTimeUtc
            $o.LastWriteTimeUtc = $childItem.LastWriteTimeUtc
            $o.Entropy = $fileEntropy

            $o
        }
}
else {
    Write-Error -Message "Invalid path specified: $BasePath"
}
