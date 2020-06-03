# This module is used to enumerate system certificate stores to look for suspicious certificates
# that may be present and intercepting user traffic or misrepresenting the validity of sites
# they are visiting. For now, the module is not capable of inspecting user-specific cert-stores
# just the global/machine cert-store.  Parsing certificates into a valid json format is painful
# and so is the code you see here that parses ceritifcate info. Sorry not sorry.

Function Get-CertificateStore {
    [CmdletBinding()]
    Param (        
        [switch]$All,
        [switch]$Windows,
        [switch]$Java
    )

    if (($PSBoundParameters.Keys).Count -eq 0) {
        $All = [switch]::Present
    }
    $CurrentLocation = Get-Location

    # Windows CertStore
    if ($All -or $Windows) {

        try {
            Write-Verbose "Enumerating Windows Certificate Store"
            $WindowsCertStore = Get-ChildItem Cert:\LocalMachine -Recurse | Where-Object {$_.PSIsContainer -eq $false}

            foreach ($WindowsCert in $WindowsCertStore) {
                $result = @{}
                $result.add("KansaModule",$moduleName)
                $result.add("Hostname",$hostname)
                $result.add('CertName', $WindowsCert.PSChildName)
                $result.add('CertPath', "\\$env:COMPUTERNAME\$(($WindowsCert.PSPath).split('::')[2])")
                $result.add('CertParentPath', "\\$env:COMPUTERNAME\$(($WindowsCert.PSParentPath).split('::')[2])")
                $result.add('FriendlyName', $WindowsCert.FriendlyName)
                $result.add('NotBefore', $WindowsCert.NotBefore.ToString())
                $result.add('NotAfter', $WindowsCert.NotAfter.ToString())
                $result.add('SerialNumber', $WindowsCert.SerialNumber)
                $result.add('SignatureAlgorithm', $WindowsCert.SignatureAlgorithm.FriendlyName)
                $result.add('SignatureAlgorithmVersion', $WindowsCert.SignatureAlgorithm.Value)
                $result.add('Version', $WindowsCert.Version)
                $result.add('Issuer', $WindowsCert.Issuer)
                $obj = $WindowsCert.Issuer -Split ',(?=(?:[^"]*"[^"]*")*[^"]*$)' | %{ $_ | ConvertFrom-StringData} | sort Keys
                $i = 2
                $pad = ''
                foreach ($element in $obj) {
                    $theName = $('Issuer-'+($element.Keys).Trim())
                    $theValue = ($element.Values).Trim()
                    if ([bool]($result.ContainsKey($theName))){
                        $theName = $theName + [String]$i
                        $i++
                    } else {
                        $i = 2
                    }
                    $result.add($theName, $theValue)
                }

                $result.add('Subject', $WindowsCert.Subject)
                $obj = $WindowsCert.Subject -Split ',(?=(?:[^"]*"[^"]*")*[^"]*$)' | %{ $_ | ConvertFrom-StringData} | sort Keys
                $i = 2
                $pad = ''
                foreach ($element in $obj) {
                    $theName = $('Subject-'+($element.Keys).Trim())
                    $theValue = ($element.Values).Trim()
                    if ([bool]($result.ContainsKey($theName))){
                        $theName = $theName + [String]$i
                        $i++
                    } else {
                        $i = 2
                    }
                    $result.add($theName, $theValue)
                }

                $result.add('Thumbprint', $WindowsCert.Thumbprint)
                $result.add('CertCategory', "Windows")
                Add-Result -hashtbl $result
            }
        } catch {
            Write-Verbose "Could Not Enumerate Windows Certificate Store"
        }
    }

    # Java CertStore
    if ($All -or $Java) {

        try {
            Write-Verbose "Enumerating Java Certificate Store"

            if ([System.IntPtr]::Size -eq 4) {
                $JavaPath = "$($Env:SystemDrive)\Program Files\Java"
            } else {
                $JavaPath = (
                    "$($Env:SystemDrive)\Program Files\Java",
                    "$($Env:SystemDrive)\Program Files (x86)\Java"
                )
            }
            foreach ($Path in $JavaPath) {
                $JavaFolder = Get-ChildItem $Path -ErrorAction SilentlyContinue
                if ($JavaFolder) {
                    foreach ($Folder in $JavaFolder) {
                        if ($Folder.FullName -match "x86") {
                            $Arch ="_x86"
                        } else {
                            $Arch = "_x64"
                        }
                        $JavaVersion = (($Folder.FullName).split('\')[-1]).ToString() + $Arch
                        $KeyTool = "$($Folder.FullName)\bin"
            
                        Set-Location $KeyTool
            
                        $JavaCertStore = Write-Output "" | .\keytool.exe -list -v -keystore ..\lib\security\cacerts 2>&1
            
                        $JavaCertStore = $JavaCertStore -Split([System.Environment]::NewLine,[System.StringSplitOptions]::RemoveEmptyEntries)
                        $JavaCertStore = (($JavaCertStore -replace "^","|")-join "")
                        $JavaCertStore = $JavaCertStore.split(([string[]]@("*******************************************|*******************************************")),[System.StringSplitOptions]::RemoveEmptyEntries)
            
                        foreach ($JavaCert in $JavaCertStore) {
                            $JavaCert = $JavaCert.split("|",[System.StringSplitOptions]::RemoveEmptyEntries) -replace "^\s.",""
            
                            if ($JavaCert) { 
                                $result = @{}
                                $result.add('CertName', $null)
                                $result.add('Hostname', $hostname)
                                $result.add("KansaModule",$moduleName)
                                $result.add('CreationDate', $null)
                                $result.add('EntryType', $null)
                                $result.add('Owner', $null)
                                $result.add('Issuer', $null)
                                $result.add('SerialNumber', $null)
                                $result.add('NotBefore', $null)
                                $result.add('NotAfter', $null)
                                $result.add('MD5', $null)
                                $result.add('SHA1', $null)
                                $result.add('SHA256', $null)
                                $result.add('CertCategory', "Java")
                                $result.add('JavaVersion', $JavaVersion)
                                foreach ($entry in $JavaCert) {
            
                                    if ($entry) {
                                        Switch -Regex ($entry) {
                                            '^Alias name: ' {
                                                $result.Item('CertName') = $entry.Split(':')[1] -replace '^\s',''
                                                break
                                            }
                                            'Creation date: ' {
                                                $result.Item('CreationDate') = $entry.Split(':')[1] -replace '^\s',''
                                                break
                                            }
                                            'Entry type: ' {
                                                $result.Item('EntryType') = $entry.Split(':')[1] -replace '^\s',''
                                                break
                                            }
                                            'Owner: ' {
                                                $theOwner = $entry.Split(':')[1] -replace '^\s',''
                                                $result.Item('Owner') = $theOwner
                                                $obj = $theOwner -Split ',(?=(?:[^"]*"[^"]*")*[^"]*$)' | %{ $_ | ConvertFrom-StringData} | sort Keys
                                                $i = 2
                                                $pad = ''
                                                foreach ($element in $obj) {
                                                    $theName = $('Owner-'+($element.Keys).Trim())
                                                    $theValue = ($element.Values).Trim()
                                                    if ([bool]($result.ContainsKey($theName))){
                                                        $theName = $theName + [String]$i
                                                        $i++
                                                    } else {
                                                        $i = 2
                                                    }
                                                    $result.add($theName, $theValue)
                                                }
                                                break
                                            }
                                            'Issuer: ' {
                                                $theIssuer = $entry.Split(':')[1] -replace '^\s',''
                                                $properties.Issuer = $theIssuer
                                                $obj = $theIssuer -Split ',(?=(?:[^"]*"[^"]*")*[^"]*$)' | %{ $_ | ConvertFrom-StringData} | sort Keys
                                                $i = 2
                                                $pad = ''
                                                foreach ($element in $obj) {
                                                    $theName = $('Issuer-'+($element.Keys).Trim())
                                                    $theValue = ($element.Values).Trim()
                                                    if ([bool]($result.ContainsKey($theName))){
                                                        $theName = $theName + [String]$i
                                                        $i++
                                                    } else {
                                                        $i = 2
                                                    }
                                                    $result.add($theName, $theValue)
                                                }
                                                break
                                            }
                                            'Serial number: ' {
                                                $result.Item('SerialNumber') = $entry.Split(':')[1] -replace '^\s',''
                                                break
                                            }
                                            'Valid from: ' {
                                                $result.Item('NotBefore') = (($entry -split 'from:')[1] -split 'until:')[0] -replace '^\s',''
                                                $result.Item('NotAfter') = (($entry -split 'from:')[1] -split 'until:')[1] -replace '^\s',''
                                                break
                                            }
                                            'MD5: ' {
                                                $result.Item('MD5') = ($entry -split 'MD5:'  -replace '^\s*','')[1] -replace ':',''
                                                break
                                            }
                                            'SHA1: ' {
                                                $result.Item('SHA1') = ($entry -split 'SHA1:' -replace '^\s*','')[1] -replace ':',''
                                                break
                                            }
                                            'SHA256: ' {
                                                $result.Item('SHA256') = ($entry -split 'SHA256:' -replace '^\s*','')[1] -replace ':',''
                                                break
                                            }
                                            default {
                                            }
                                        }
                                    }
                                }
                            Add-Result -hashtbl $result
                            }   
                        }
                    }
                }
            }
        } catch {
            Write-Verbose "Could Not Enumerate Java Certificate Store"
        }
    Set-Location $CurrentLocation.Path
    }
}

Get-CertificateStore
