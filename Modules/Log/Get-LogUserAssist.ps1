# OUTPUT TXT
# Get-UserAssist.ps1 retrieves UserAssist data from ntuser.dat hives
# Doesn't current retrieve the count, but I'm working on that
# Doesn't currently work against locked hives, but there may be a work-around for this

foreach($userpath in (Get-WmiObject win32_userprofile | Select-Object -ExpandProperty localpath)) { 
    $sb = {
Param(
[Parameter(Mandatory=$True,Position=0)]
    [String]$userpath
)

<#
The next section of code was found in Microsoft's TechNet Gallery at:
http://gallery.technet.microsoft.com/scriptcenter/Get-Last-Write-Time-and-06dcf3fb#content
Contributed by Rohn Edwards

MICROSOFT LIMITED PUBLIC LICENSE
This license governs use of code marked as “sample” or “example” available on this web site without a license agreement, as provided under the section above titled “NOTICE SPECIFIC TO SOFTWARE AVAILABLE ON THIS WEB SITE.” If you use such code (the “software”), you accept this license. If you do not accept the license, do not use the software. 
 1. Definitions 
 The terms “reproduce,” “reproduction,” “derivative works,” and “distribution” have the same meaning here as under U.S. copyright law. 
 A “contribution” is the original software, or any additions or changes to the software. 
 A “contributor” is any person that distributes its contribution under this license. 
“Licensed patents” are a contributor’s patent claims that read directly on its contribution. 
 2. Grant of Rights 
 (A) Copyright Grant - Subject to the terms of this license, including the license conditions and limitations in section 3, each contributor grants you a non-exclusive, worldwide, royalty-free copyright license to reproduce its contribution, prepare derivative works of its contribution, and distribute its contribution or any derivative works that you create. 
 (B) Patent Grant - Subject to the terms of this license, including the license conditions and limitations in section 3, each contributor grants you a non-exclusive, worldwide, royalty-free license under its licensed patents to make, have made, use, sell, offer for sale, import, and/or otherwise dispose of its contribution in the software or derivative works of the contribution in the software. 
 3. Conditions and Limitations 
 (A) No Trademark License- This license does not grant you rights to use any contributors’ name, logo, or trademarks. 
 (B) If you bring a patent claim against any contributor over patents that you claim are infringed by the software, your patent license from such contributor to the software ends automatically. 
 (C) If you distribute any portion of the software, you must retain all copyright, patent, trademark, and attribution notices that are present in the software. 
 (D) If you distribute any portion of the software in source code form, you may do so only under this license by including a complete copy of this license with your distribution. If you distribute any portion of the software in compiled or object code form, you may only do so under a license that complies with this license. 
 (E) The software is licensed “as-is.” You bear the risk of using it. The contributors give no express warranties, guarantees or conditions. You may have additional consumer rights under your local laws which this license cannot change. To the extent permitted under your local laws, the contributors exclude the implied warranties of merchantability, fitness for a particular purpose and non-infringement. 
 (F) Platform Limitation - The licenses granted in sections 2(A) and 2(B) extend only to the software or derivative works that you create that run on a Microsoft Windows operating system product.
#>
Add-Type @"
    using System; 
    using System.Text;
    using System.Runtime.InteropServices; 

    namespace CustomNameSpace {
        public class advapi32 {
            [DllImport("advapi32.dll", CharSet = CharSet.Auto)]
            public static extern Int32 RegQueryInfoKey(
                Microsoft.Win32.SafeHandles.SafeRegistryHandle hKey,
                StringBuilder lpClass,
                [In, Out] ref UInt32 lpcbClass,
                UInt32 lpReserved,
                out UInt32 lpcSubKeys,
                out UInt32 lpcbMaxSubKeyLen,
                out UInt32 lpcbMaxClassLen,
                out UInt32 lpcValues,
                out UInt32 lpcbMaxValueNameLen,
                out UInt32 lpcbMaxValueLen,
                out UInt32 lpcbSecurityDescriptor,
                out Int64 lpftLastWriteTime
            );
        }
    }
"@

Update-TypeData -TypeName Microsoft.Win32.RegistryKey -MemberType ScriptProperty -MemberName LastWriteTime -Value {

    $LastWriteTime = $null
            
    $Return = [CustomNameSpace.advapi32]::RegQueryInfoKey(
        $this.Handle,
        $null,       # ClassName
        [ref] 0,     # ClassNameLength
        $null,  # Reserved
        [ref] $null, # SubKeyCount
        [ref] $null, # MaxSubKeyNameLength
        [ref] $null, # MaxClassLength
        [ref] $null, # ValueCount
        [ref] $null, # MaxValueNameLength 
        [ref] $null, # MaxValueValueLength 
        [ref] $null, # SecurityDescriptorSize
        [ref] $LastWriteTime
    )

    if ($Return -ne 0) {
        "[ERROR]"
    }
    else {
        # Return datetime object:
        [datetime]::FromFileTime($LastWriteTime)
    }
}
<# End MS Limited Public Licensed code #>

function rot13 {
# Returns a Rot13 string of the input $value
# May not be the most efficient way to do this
Param(
[Parameter(Mandatory=$True,Position=0)]
    [string]$value
)
    $newvalue = @()
    for ($i = 0; $i -lt $value.length; $i++) {
        $charnum = [int]$value[$i]
        if ($charnum -ge [int][char]'a' -and $charnum -le [int][char]'z') {
            if ($charnum -gt [int][char]'m') {
                $charnum -= 13
            } else {
                $charnum += 13
            }
        } elseif ($charnum -ge [int][char]'A' -and $charnum -le [int][char]'Z') {
            if ($charnum -gt [int][char]'M') {
                $charnum -= 13
            } else {
                $charnum += 13
            }
        }
        $newvalue += [char]$charnum
    }
    $newvalue -join ""
}

if (Get-Command Reg.exe -ErrorAction SilentlyContinue ) { 
	$regexe = Reg.exe | Select-Object -ExpandProperty path
    if (Test-Path($userpath + "\ntuser.dat")) {
        "$userpath has an ntuser.dat file... attempting to load"
        $regload = & $regexe load "hku\KansaTempHive" "$userpath\ntuser.dat"
        if ($regload -notmatch "ERROR") {
            "$userpath loaded."
            Set-Location "Registry::HKEY_USERS\KansaTempHive\Software\Microsoft\Windows\CurrentVersion\Explorer\"
            if (Test-Path("UserAssist")) {
                "UserAssist found."
                foreach ($line in (ls "UserAssist" -Recurse)) {
                    $uavalue = ($line | select -ExpandProperty property | out-string)
                    $lastwrt = $line | select -ExpandProperty LastWriteTime
                    if (!($uavalue -match "Version")) {
                        $rot13uav = rot13 $uavalue
                    }
                    $lastwrt
                    $rot13uav
                }
            } else {
                "No UserAssist found for $userpath."
            }
        } else {
            "Could not load $userpath."
        }
    }
}
}

    $Job = Start-Job -ScriptBlock $sb -ArgumentList $userpath
    $suppress = Wait-Job $Job 
    $Recpt = Receive-Job $Job
    $Recpt
    $ErrorActionPreference = "SilentlyContinue"
    & reg.exe unload "hku\KansaTempHive" 2>&1 
}