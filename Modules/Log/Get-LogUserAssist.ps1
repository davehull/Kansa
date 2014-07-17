<#
.SYNOPSIS
Get-LogUserAssist.ps1 retrieves UserAssist data from ntuser.dat hives
Retrieves "count" from value data, but on my Win8.1 system count does 
not appear to be incremented consistently.
Retrieves data from locked hives for logged on users, by finding their
hives in HKEY_USERS

.NOTES
Next line is required by kansa.ps1 for handling this scripts output.
OUTPUT TSV
#>

[CmdletBinding()]
Param()
foreach($user in (Get-WmiObject win32_userprofile)) { 
    $userpath = $user.localpath
    $usersid  = $user.SID
    Write-Verbose "`$userpath : $userpath"
    Write-Verbose "`$usersid  : $usersid"

    # Begin massive ScriptBlock
    # In order to unload loaded hives using reg.exe, we have to spin up a separate process for reg load
    # do our processing and then exit that process, then the calling process, this script, can call 
    # reg unload successfully
    $sb = {
Param(
[Parameter(Mandatory=$True,Position=0)]
    [String]$userpath,
[Parameter(Mandatory=$True,Position=1)]
    [String]$usersid
)


<#
The next section of code makes Key LastWriteTime property accessible to Powershell and 
was found in Microsoft's TechNet Gallery at:
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
        $null,       # Reserved
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
        # modified by Dave Hull to return ISO formatted timestamp
        Get-Date([datetime]::FromFileTimeUtc($LastWriteTime)) -Format yyyyMMddThh:mm:ss
    }
}
<# End MS Limited Public Licensed code #>

function rot13 {
# Returns a Rot13 string of the input $value
# UserAssist keys are Rot13 encoded
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

function Get-RegKeyValueNData {
# Returns values and data for Registry keys
# http://blogs.technet.com/b/heyscriptingguy/archive/2012/05/11/use-powershell-to-enumerate-registry-property-values.aspx
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Path
)
    Push-Location
    Set-Location -Path "Registry::$Path"
    Get-Item . | Select-Object -ExpandProperty Property | 
    Foreach-Object {
        New-Object psobject -Property @{"property" = $_;
            "value" = (Get-ItemProperty -Path . -Name $_).$_
        }
    }
    Pop-Location
}

function Get-RegKeyLastWriteTime {
Param(
    [Parameter(Mandatory=$True,Position=0)]
        [String]$Path
)
    Get-ChildItem "Registry::$Path" | Select-Object -ExpandProperty LastWriteTime
}

function Get-UserAssist {
Param(
[Parameter(Mandatory=$True,Position=0)]
    [String]$regpath,
[Parameter(Mandatory=$True,Position=1)]
    [String]$userpath,
[Parameter(Mandatory=$True,Position=2)]
    [String]$useracct
)
    Set-Location $regpath
    if (Test-Path("UserAssist")) {
        foreach ($key in (Get-ChildItem "UserAssist")) {
            $o = "" | Select-Object UserAcct, UserPath, Subkey, KeyLastWriteTime, Value, Count
            $o.UserAcct = $useracct
            $o.UserPath = $userpath
            $o.KeyLastWriteTime = Get-RegKeyLastWriteTime $key
            $subkey = ($key.Name + "\Count")
            $o.Subkey = ("SOFTWARE" + ($subkey -split "SOFTWARE")[1])
            foreach($item in (Get-RegKeyValueNData -Path $subkey)) {
                # Run count, little endian bytes 4-7
                [byte[]] $bytearray = (($item.value)[4..4])
                [System.Array]::Reverse($bytearray)
                $o.Count = $($bytearray)
                $o.Value = (rot13 $item.property)
                if ($o.Value.StartsWith("UEME_")) {
                    # Don't return the UEME values
                    continue
                } else {
                    $o
                }
            }
        }
    }
}

if ($regexe = Get-Command Reg.exe -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Path) {
    if (Test-Path($userpath + "\ntuser.dat") -ErrorAction SilentlyContinue) {
        # Get the account name
        $objSID   = New-Object System.Security.Principal.SecurityIdentifier($usersid)
        $useracct = $objSID.Translate([System.Security.Principal.NTAccount])

        $regload = & $regexe load "hku\KansaTempHive" "$userpath\ntuser.dat"
        if ($regload -notmatch "ERROR") {
            Get-UserAssist "Registry::HKEY_USERS\KansaTempHive\Software\Microsoft\Windows\CurrentVersion\Explorer\" $userpath $useracct
        } else {
            # Could not load $userpath, probably because the user is logged in.
            # There's more than one way to skin the cat, cat doesn't like any of them.
            $uapath  = "Registry::HKEY_USERS\$usersid\Software\Microsoft\Windows\CurrentVersion\Explorer\"
            Get-UserAssist $uapath $userpath $useracct

<# Leaving this code in, as it may come in handy one day for something else, it was made obsolete by pulling $usersid
            foreach($SID in (ls Registry::HKU | Select-Object -ExpandProperty Name)) {
                if ($SID -match "_Classes") {
                    $SID = (($SID -split "HKEY_USERS\\") -split "_Classes") | ? { $_ }
                    $objSID = New-Object System.Security.Principal.SecurityIdentifier($SID)
                    $objUser = $objSID.Translate([System.Security.Principal.NTAccount])
                    if ($objUser -match $user) {
                        $uapath = "Registry::HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\"
                        Get-UserAssist $uapath $user
                    }
                }
            }
#>
        }
    }
}
} # End big ScriptBlock

    $Job = Start-Job -ScriptBlock $sb -ArgumentList $userpath, $usersid
    $suppress = Wait-Job $Job  
    $Recpt = Receive-Job $Job -ErrorAction SilentlyContinue
    $Recpt
    $ErrorActionPreference = "SilentlyContinue"
    $suppress = & reg.exe unload "hku\KansaTempHive" 2>&1 
}