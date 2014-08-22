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

Refrences: 
  - http://en.wikipedia.org/wiki/Entropy_(information_theory)
  - http://en.wiktionary.org/wiki/Shannon_entropy
.PARAMETER BasePath
Optional base path to start the listing. Uses IIS's default of C:\inetpub\wwwroot
if this isn't provided.
.NOTES
Next line is required by kansa.ps1 for proper handling of script output
OUTPUT tsv
#>

Param(
    [Parameter(Mandatory=$False,Position=0)]
        [string]$BasePath="C:\inetpub\wwwroot"
)

if (Test-Path $BasePath -PathType Container) {
        foreach ($childItem in (Get-ChildItem $BasePath -Recurse)) {
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
