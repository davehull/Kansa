# This is our largest Fire&forget module - pushing the limits of what can be compressed and spawned remotely.
# The intent is to mimic as much of the functionality of the sysinternals autorunsc.exe tool without needing
# to drop a tool/file to disk. It is all written in native powershell (v2 compliant). The individual autoruns
# are built into separate functions.  Since powershell is not very efficient, running them all can be
# resource-intensive and take a long time. Specify the functions you want in the main function at the end of
# the module. Use a list of the function numbers like the example provided. Due to the size limitations, 
# inline comments were avoided to save precious space. To anyone who seeks to understand/modify this script,
# may the force be with you.

#Helper Function
Function Get-RegValue {
    [CmdletBinding()]
    Param(
        [string]$Path,
        [string[]]$Names,
        [string]$Category
    )
    Begin{
        if ($Path -match 'Wow6432Node') {
            $ClassesPath = Join-Path -Path (Split-Path $Path -Qualifier) -ChildPath 'SOFTWARE\Wow6432Node\Classes\CLSID'
        } else {
            $ClassesPath = Join-Path -Path (Split-Path $Path -Qualifier) -ChildPath 'SOFTWARE\Classes\CLSID'
        }
    }
    Process {
        try {
            $Values = Get-Item -LiteralPath $Path -ErrorAction Stop
            if ($Names -eq '*') {
                $Names = $Values.GetValueNames()
            }
            $Names | ForEach-Object -Process {
                # Need to differentiate between empty string and really non existing values
                if ($null -ne $Values.GetValue($_)) {
                    $Value  = Switch -regex($Values.GetValue($_)) {
                        '^\{[A-Z0-9]{4}([A-Z0-9]{4}-){4}[A-Z0-9]{12}\}$' {
                            (Get-ItemProperty -Path (Join-Path -Path $ClassesPath -ChildPath "$($_)\InprocServer32") -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
                            break
                        }
                        default {
                            $_ 
                        }
                    }
                    if ($Value) {
                        [pscustomobject]@{
                            Path = $Path
                            Item = $_
                            Value = $Value
                            Category = $Category
                        }
                    }
                }
            }
        } catch {
        }
    }
    End {}
}

#Helper Function
Function Get-NormalizedFileSystemPath {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('PSPath', 'FullName')]
        [string[]]
        $Path,

        [switch]
        $IncludeProviderPrefix
    )

    foreach ($_path in $Path)
    {
        $_resolved = $_path

        if ($_resolved -match '^([^:]+)::') {
            $providerName = $matches[1]

            if ($providerName -ne 'FileSystem') {
                Write-Error "Only FileSystem paths may be passed to Get-NormalizedFileSystemPath.  Value '$_path' is for provider '$providerName'."
                continue
            }

            $_resolved = $_resolved.Substring($matches[0].Length)
        }

        if (-not [System.IO.Path]::IsPathRooted($_resolved)) {
            $_resolved = Join-Path -Path $PSCmdlet.SessionState.Path.CurrentFileSystemLocation -ChildPath $_resolved
        }

        try {
            $dirInfo = New-Object System.IO.DirectoryInfo($_resolved)
        } catch {
            $exception = $_.Exception
            while ($null -ne $exception.InnerException) {
                $exception = $exception.InnerException
            }
            Write-Error "Value '$_path' could not be parsed as a FileSystem path: $($exception.Message)"
            continue
        }

        $_resolved = $dirInfo.FullName

        if ($IncludeProviderPrefix) {
            $_resolved = "FileSystem::$_resolved"
        }
        Write-Output $_resolved
    }
} 

#Helper Function
function Get-ShannonEntropy {
    # Kansa code borrowed from https://github.com/davehull/Kansa/blob/ff974fcd15089b44f69c7d26b9448f183231a872/Modules/ASEP/Get-AutorunscDeep.ps1
    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [string]$FilePath
    )
    $fileEntropy = 0.0
    $FrequencyTable = @{}
    $ByteArrayLength = 0
            
    if(Test-Path $FilePath) {
        $file = (Get-ChildItem $FilePath)
        Try {
            $fileBytes = [System.IO.File]::ReadAllBytes($file.FullName)
        } Catch {
            Write-Error -Message ("Caught {0}." -f $_)
        }

        foreach($fileByte in $fileBytes) {
            $FrequencyTable[$fileByte]++
            $ByteArrayLength++
        }

        $byteMax = 255
        for($byte = 0; $byte -le $byteMax; $byte++) {
            $byteProb = ([double]$FrequencyTable[[byte]$byte])/$ByteArrayLength
            if ($byteProb -gt 0) {
                $fileEntropy += -$byteProb * [Math]::Log($byteProb, 2.0)
            }
        }
        $fileEntropy
        
    } else {
        "${FilePath} is locked or could not be found. Could not calculate entropy."
        Write-Error -Category InvalidArgument -Message ("{0} is locked or could not be found." -f $FilePath)
    }
}

#Helper-Function
function Process-Results {
    Param (
        [parameter(Mandatory=$true)]
        [psobject[]]$Results
    )

    #Get File Paths
    foreach ($Entry in $Results) {
        if ($Entry) {
            $Output = @{}
            $Output.add("KansaModule",$moduleName)
            $Output.add("Hostname",$hostname)
            if ($Entry.FilePath -and ($Entry.FilePath -eq [string]::Empty)) {
                $Output.add('FilePath', $null)
            } elseif ($Entry.FilePath) {
                $Entry.FilePath = $Entry.FilePath -replace '"',""
                $Output.add('FilePath', "$($Entry.FilePath)")
            }

            #Extended Info
            $Output.add('AutorunPath', $Entry.Path)
            $Output.add('AutorunItem', $Entry.Item)
            $Output.add('AutorunValue', $Entry.Value)
            $Output.add('AutorunCategory', $Entry.Category)
            $Output.add('FileSize', $null)
            $Output.add('FileLastWriteTime', $null)
            $Output.add('FileCreationTime', $null)
            $Output.add('FileVersion', $null)
            $Output.add('FileManufacturer', $null)
            
            # Get File Properties if file path present
            if ($Output['FilePath']) {
                $ImageProperties = Get-ChildItem -Path $Output['FilePath'] -ErrorAction SilentlyContinue
                if ($ImageProperties) { 
                    #$Output['FileSize'] = ($ImageProperties.Length/1024).ToString().Split('.')[0] + "KB"
                    $Output['FileSize'] = ($ImageProperties.Length)
                    $Output['FileLastWriteTime'] = $ImageProperties.LastWriteTime.ToString()
                    $Output['FileCreationTime'] = $ImageProperties.CreationTime.ToString()
                    if ($ImageProperties.VersionInfo.ProductInfo) {
                        $Output['FileVersion'] = $ImageProperties.VersionInfo.ProductVersion
                    } elseif ($ImageProperties.VersionInfo.FileVersion) {
                        $Output['FileVersion'] = $ImageProperties.VersionInfo.FileVersion
                    }
                    $Output['FileManufacturer'] = $ImageProperties.VersionInfo.CompanyName
                }
            }
            
            # If ShowFileHash is present
            if ($ShowFileHash) {
                $Output.add('MD5', $null)
                if ($ImageProperties -and $Output['FilePath']) {
                    $Output['MD5'] = Get-FileHash -Algorithm 'MD5' -Path $Output['FilePath'] -ErrorAction SilentlyContinue
                }
            }
            
            # If ShowFileEntropy is present
            if ($ShowEntropy) {
                $Output.add('ShannonEntropy', $null)
                if ($ImageProperties) {
                    $Output['ShannonEntropy'] = Get-ShannonEntropy -FilePath $Output['FilePath'] -ErrorAction SilentlyContinue
                }
            }
            
            # If ShowFileSignature is present
            if ($ShowSignature) {
                $Output.add('FileSignature', $null)
                $Output.add('FileIssuer', $null)
                if ($ImageProperties) {
                    $FileSignature = Get-AuthenticodeSignature -FilePath $ImageProperties.FullName -ErrorAction SilentlyContinue
                    if ($FileSignature) {
                        $Output['FileSignature'] = $(
                            if ($FileSignature.SignerCertificate.Thumbprint) {
                                $FileSignature.SignerCertificate.Thumbprint.ToLower()
                        } else {
                            $null
                        })
                        $Output['FileIssuer'] = $(
                            if ($FileSignature.SignerCertificate.Issuer) {
                                $FileSignature.SignerCertificate.Issuer.ToLower()
                        } else {
                            $null
                        })
                    }
                }
            }
            Add-Result -hashtbl $Output
        }
    }
}

function Get-ASEPAppInitDLLs {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'AppInitDLLs'
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )

    Write-Verbose -Message 'Looking for AppInitDLL entries'
    #AppInit
    foreach ($Arch in $Arches) {
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows NT\CurrentVersion\Windows" -Names 'Appinit_Dlls' -Category $Category
        $Results += $Result
    }

    if (Test-Path -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\AppCertDlls' -PathType Container) {
        $Result = Get-RegValue -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager\AppCertDlls' -Names '*' -Category $Category 
        $Results += $Result
    }
    foreach ($Entry in $Results) {
        $tmpVal = $null
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal -ne [string]::Empty) {
                $tmpVal = "$($Entry.FilePath)"
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value "$($Entry.FilePath)"
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPBootExecute {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'Boot Execute'
    $Results = @()

    Write-Verbose -Message 'Looking for Boot Execute entries'
    #region Boot Execute

    # REG_MULTI_SZ
    $Names = (
        'BootExecute',
        'SetupExecute',
        'Execute',
        'S0InitialCommand'
    )
    foreach ($Name in $Names) {
        $Item = $Name
        $Values = $null
        $Values = (Get-RegValue -Path 'HKLM:\System\CurrentControlSet\Control\Session Manager' -Names $Name -Category $Category)
        if ($Values) {
            foreach ($Value in $Values.Value) {
                if ($Value -ne '""') {
                    $Result = New-Object psobject
                    $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value 'HKLM:\System\CurrentControlSet\Control\Session Manager'
                    $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Item
                    $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $Value
                    $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                }
                $Results += $Result
            }
        }
    }

    $Result = Get-RegValue -Path 'HKLM:\System\CurrentControlSet\Control' -Names 'ServiceControlManagerExtension' -Category $Category
    $Results += $Result
    #endregion Boot Execute

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $(
                Switch -Regex ($Entry.Value) {
                    '^autocheck\sautochk\s' {
                        "$($env:SystemRoot)\system32\autochk.exe"
                        break;
                    }
                    default {
                        $Entry.Value
                    }
            })
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPExplorerAddons {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'Explorer'
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )
    $SubNames = (
        'Filter',
        'Handler'
    )

    Write-Verbose -Message 'Looking for Explorer Add-ons entries'
    #region Explorer

    # Filter & Handler
    foreach ($SubName in $SubNames) {
        $Key = "HKLM:\SOFTWARE\Classes\Protocols\$($SubName)"
        if (Test-Path -Path $key -PathType Container) {
            $SubKeys = (Get-Item -Path $key).GetSubKeyNames() 
            foreach ($SubKey in $SubKeys) {
                if ($SubKey -eq 'ms-help') {
                    if ([environment]::Is64BitOperatingSystem) {
                        $ClassesPath = 'HKLM:\SOFTWARE\Wow6432Node\Classes\CLSID'
                    } else {
                        $ClassesPath = 'HKLM:\SOFTWARE\Classes\CLSID'
                    }
                    $Item = (Get-ItemProperty -Path "$Key\ms-help" -Name 'CLSID').CLSID
                    $Result = New-Object psobject
                    $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value "$Key\ms-help"
                    $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Item
                    $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $(
                        (Get-ItemProperty -Path (Join-Path -Path 'HKLM:\SOFTWARE\Wow6432Node\Classes\CLSID' -ChildPath "$($Item)\InprocServer32") -Name '(default)' -ErrorAction SilentlyContinue).'(default)';
                        (Get-ItemProperty -Path (Join-Path -Path 'HKLM:\SOFTWARE\Classes\CLSID' -ChildPath "$($Item)\InprocServer32") -Name '(default)' -ErrorAction SilentlyContinue).'(default)';
                    ) | Where-Object { $null -ne $_ } | Sort-Object -Unique
                    $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                    } else {
                    $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name 'CLSID' -Category $Category
                }
                $Results += $Result
            }
        }
    }

    # SharedTaskScheduler
    foreach ($Arch in $Arches) {
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\SharedTaskScheduler" -Name '*' -Category $Category
        $Results += $Result
    }

    # ShellServiceObjects
    foreach ($Arch in $Arches) {
        $ClassesPath =  "HKLM:\SOFTWARE\$($Arch)\Classes\CLSID"
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\ShellServiceObjects"
        $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $(
                try {
                    (Get-ItemProperty -Path (Join-Path -Path $ClassesPath -ChildPath "$($SubKey)\InprocServer32") -Name '(default)' -ErrorAction Stop).'(default)'
                } catch {
                    $null
                }
            )
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result
        }
    }

    # ShellExecuteHooks
    foreach ($Arch in $Arches) {
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\ShellExecuteHooks"
        if (Test-Path -Path $Key -PathType Container) {
            $ClassesPath =  "HKLM:\SOFTWARE\$($Arch)\Classes\CLSID"
            $SubKeys = (Get-Item -Path $Key).GetValueNames()
            foreach ($SubKey in $SubKeys) {
                $Result = New-Object psobject
                $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
                $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path (Join-Path -Path $ClassesPath -ChildPath "$($SubKey)\InprocServer32") -Name '(default)').'(default)'
                $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                $Results += $Result
            }            
        }
    }

    # ShellServiceObjectDelayLoad
    foreach ($Arch in $Arches) {
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\ShellServiceObjectDelayLoad" -Name '*' -Category $Category
        $Results += $Result
    }

    # Handlers
    $Handlers = @(
        @{
            Name = '*' ; 
            Properties = @(
                'ContextMenuHandlers',
                'PropertySheetHandlers'
            )
        },
        @{
            Name ='Drive'  ; 
            Properties = @(
                'ContextMenuHandlers'
            )
        },
        @{
            Name ='AllFileSystemObjects'  ; 
            Properties = @(
                'ContextMenuHandlers',
                'DragDropHandlers',
                'PropertySheetHandlers'
            )
        },
        @{
            Name ='Directory'  ; 
            Properties = @(
                'ContextMenuHandlers',
                'DragDropHandlers',
                'PropertySheetHandlers', 
                'CopyHookHandlers'
            )
        },
        @{
            Name ='Directory\Background'  ; 
            Properties = @(
                'ContextMenuHandlers'
            )
        },
        @{
            Name ='Folder' ; 
            Properties = @(
                'ColumnHandlers',
                'ContextMenuHandlers',
                'DragDropHandlers',
                'ExtShellFolderViews',
                'PropertySheetHandlers'
            )
        }
    ) 
    foreach ($Handler in $Handlers ){
        $Name = $Handler.Name
        $Properties = $Handler.Properties
        foreach ($Arch in $Arches) { 
            $Key = "HKLM:\Software\$($Arch)\Classes\$($Name)\ShellEx"
            $ClassPath = "HKLM:\Software\$($Arch)\Classes\CLSID"
            $Hive = $Arch
            foreach ($Property in $Properties) {
                $Keys = Join-Path -Path $Key -ChildPath $Property
                try {
                    $SubKeys = (Get-Item -LiteralPath $Keys -ErrorAction SilentlyContinue).GetSubKeyNames()
                    foreach ($SubKey in $SubKeys) {
                        if ($(try {
                                [system.guid]::Parse($SubKey) | Out-Null
                                $true
                            } catch {
                                $false
                            })) {
                            if (Test-Path -Path (Join-Path -Path $ClassPath -ChildPath "$($SubKey)\InprocServer32") -PathType Container) {
                                # don't change anything
                            } else {
                                if ($Hive) {
                                    $ClassPath = 'HKLM:\Software\Classes\CLSID'
                                } else {
                                    $ClassPath = 'HKLM:\Software\Wow6432Node\Classes\CLSID'
                                }
                            }
                            if (Test-PAth -Path (Join-Path -Path $ClassPath -ChildPath "$($SubKey)\InprocServer32") -PathType Container) {
                                $Result = New-Object psobject
                                $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                                $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
                                $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path (Join-Path -Path $ClassPath -ChildPath "$($SubKey)\InprocServer32") -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
                                $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                            }
                        } else {
                            $Result = Get-RegValue -Path "$Keys\$($SubKey)" -Name '*' -Category $Category
                        }
                        $Results += $Result
                    }
                }catch {
                }   
            }
        }
    } 

    # ShellIconOverlayIdentifiers
    foreach ($Arch in $Arches) {
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\ShellIconOverlayIdentifiers"
        if (Test-Path -Path $Key -PathType Container) {
            $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
            foreach ($SubKey in $SubKeys) {
                $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name '*' -Category $Category
            }
            $Results += $Result   
        }
    }

    # LangBarAddin
    $Result = Get-RegValue -Path 'HKLM:\Software\Microsoft\Ctf\LangBarAddin' -Name '*' -Category $Category
    $Results += $Result

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal) {
                if ($tmpVal -match '^[A-Z]:\\') {
                    if ($Entry.Path -match 'Wow6432Node') {
                        $tmpVal -replace 'system32','syswow64' | Get-NormalizedFileSystemPath
                    } else {
                        $tmpVal | Get-NormalizedFileSystemPath
                    }
                } else {
                    if ($Entry.Path -match 'Wow6432Node') {
                        $tmpVal = Join-Path -Path "$($env:systemroot)\syswow64" -ChildPath $tmpVal
                    } else {
                        $tmpVal = Join-Path -Path "$($env:systemroot)\system32" -ChildPath $tmpVal
                    }
                }
            }
        }
        $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPSidebarGadgets {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'SidebarGadgets'
    $Results = @()

    Write-Verbose -Message 'Looking for Sidebar gadgets'
    #region User Sidebar gadgets

    $Path = Join-Path -Path (Split-Path -Path $($env:AppData) -Parent) -ChildPath 'Local\Microsoft\Windows Sidebar\Settings.ini'
    if (Test-Path $Path) {
        $Values = Get-Content -Path $Path | Select-String -Pattern '^PrivateSetting_GadgetName=' 
        foreach ($Value in $Values) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Path
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $[string]::Empty
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value ($Value.Line -split '=' | Select-Object -Last 1).replace('%5C','\').replace('%20',' ')
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
        }
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPImageHijacks {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'ImageHijacks'
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )

    Write-Verbose -Message 'Looking for Image hijacks'
    #region Image Hijacks

    foreach ($Arch in $Arches) {
        $Key = "HKLM:\Software\$($Arch)\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
        $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = Get-RegValue -Path "$key\$($SubKey)" -Name 'Debugger' -Category $Category
            $Results += $Result
        }
    }		

    # Autorun macro	
    foreach ($Arch in $Arches) {
        $Result = Get-RegValue -Path "HKLM:\Software\$($Arch)\Microsoft\Command Processor" -Name 'Autorun' -Category $Category
        $Results += $Result
    }

    # Htmlfile & Exefile
    $FileTypes = (
        'exefile',
        'htmlfile'
    )
    foreach ($FileType in $FileTypes) {
        $Result = New-Object psobject
        $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value "HKLM:\SOFTWARE\Classes\$($FileType)\Shell\Open\Command"
        $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $FileType
        $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$($FileType)\Shell\Open\Command" -Name '(default)').'(default)'
        $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
        $Results += $Result
    }

    $SubNames = (
        '.exe',
        '.cmd'
    )
    foreach ($SubName in $SubNames) {
        $Assoc = (Get-ItemProperty -Path "HKLM:\Software\Classes\$($SubName)" -Name '(default)').'(default)'
        $Result = New-Object psobject
        $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value "HKLM:\Software\Classes\$($Assoc)\Shell\Open\Command"
        $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubName
        $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$Assoc\Shell\Open\Command" -Name '(default)').'(default)'
        $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
        $Results += $Result
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal -match '^[A-Z]:\\') {
                $tmpVal = $Entry.Value[0]
                #$tmpVal = $tmpVal[0]
            } 
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPIEAddons {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'InternetExplorerAddons'
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )

    Write-Verbose -Message 'Looking for Internet Explorer Add-ons entries'
    #region Internet Explorer

    # Browser Helper Objects
        foreach ($Arch in $Arches ) {
        $ClassesPath =  "HKLM:\SOFTWARE\$($Arch)\Classes\CLSID"
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\Explorer\Browser Helper Objects"
        if (Test-Path -Path $key -PathType Container) {
            $SubKeys = (Get-Item -Path $key).GetSubKeyNames() 
            foreach ($SubKey in $SubKeys) {
                $Result = New-Object psobject
                $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
                $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path (Join-Path -Path $ClassesPath -ChildPath "$($SubKey)\InprocServer32") -Name '(default)').'(default)'
                $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                $Results += $Result
            }
        }
    }

    # IE Toolbars
    foreach ($Arch in $Arches) {
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Internet Explorer\Toolbar" -Name '*' -Category $Category
        $Results += $Result
    }

    # Explorer Bars
    foreach ($Arch in $Arches) {
        $ClassesPath = "HKLM:\SOFTWARE\$($Arch)\Classes\CLSID"
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Internet Explorer\Explorer Bars"
        try {
            $SubKeys = (Get-Item -Path $Key -ErrorAction Stop).GetSubKeyNames()
            foreach ($SubKey in $SubKeys) {
                $Result = New-Object psobject
                $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
                $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path (Join-Path -Path $ClassesPath -ChildPath "$($SubKey)\InprocServer32") -Name '(default)').'(default)'
                $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                $Results += $Result
            }
        } catch {
        }
    }

    # IE Extensions
    foreach ($Arch in $Arches) {
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Internet Explorer\Extensions"
        if (Test-Path -Path $Key -PathType Container) {
            $SubKeys = (Get-Item -Path $Key -ErrorAction SilentlyContinue).GetSubKeyNames()
            foreach ($SubKey in $SubKeys) {
                $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name 'ClsidExtension' -Category $Category
                $Results += $Result
            }
        }
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal -ne 'Locked') {
                $tmpVal = $($tmpVal | Get-NormalizedFileSystemPath)
            } else {
                $tmpVal = $null
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPKnownDLLs {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'KnownDLLs'
    $Results = @()

    Write-Verbose -Message 'Looking for Known DLLs entries'
    #region Known Dlls

    $Results = Get-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\KnownDLLs' -Name '*' -Category $Category

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ( (Test-Path -Path $tmpVal -PathType Container) -and ($tmpVal -match 'DllDirectory')) {

            } else {
                if ([System.IntPtr]::Size -eq 4) { 
                    $tmpVal = $(Join-Path -Path "$($env:SystemRoot)\System32" -ChildPath $tmpVal)
                } else { 
                    $tmpVal = $(Join-Path -Path "$($env:SystemRoot)\Syswow64" -ChildPath $tmpVal)
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPLogon {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'Logon'
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )

    Write-Verbose -Message 'Looking for Logon Startup entries'
    #region Logon

    # Winlogon
    $Result = Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -Name 'VmApplet','Userinit','Shell','TaskMan','AppSetup' -Category $Category
    $Results += $Result

    # UserInitMprLogonScript
    if (Test-Path -Path 'HKLM:\Environment' -PathType Container) {
        $Result = Get-RegValue -Path 'HKLM:\Environment' -Name 'UserInitMprLogonScript' -Category $Category
        $Results += $Result
    }

    # GPExtensions
    $Key = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\GPExtensions'
    if (Test-Path -Path $Key -PathType Container) {
        $SubKeys = (Get-Item -Path $Key -ErrorAction Stop).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            try {
                $Result = New-Object psobject
                $Result | Add-Member -MemberType NoteProperty -Name 'Path', $Key
                $Result | Add-Member -MemberType NoteProperty -Name 'Item', $SubKey
                $Result | Add-Member -MemberType NoteProperty -Name 'Value', (Get-ItemProperty -Path (Join-Path -Path $Key -ChildPath $SubKey) -Name 'DllName' ).'DllName'
                $Result | Add-Member -MemberType NoteProperty -Name 'Category', $Category
                $Results += $Result
            } catch {}			
        }			
    }

    # Domain Group Policies scripts
    $DomainGPOs = (
        'Startup',
        'Shutdown',
        'Logon',
        'Logoff'
    )
    foreach ($DomainGPO in $DomainGPOs) {
        $Key = "HKLM:\Software\Policies\Microsoft\Windows\System\Scripts\$($DomainGPO)"
        if (Test-Path -Path $Key) {
            $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
            foreach ($SubKey in $SubKeys) {
                $_SubKey = (Join-Path -Path $Key -ChildPath $SubKey)
                $Sub_SubKeys = (Get-Item -Path $_SubKey).GetSubKeyNames()
                foreach ($Sub_SubKey in $Sub_SubKeys) {
                    $Result = Get-RegValue -Path (Join-Path -Path $_SubKey -ChildPath $Sub_SubKey) -Name 'script' -Category $Category
                    $Results += $Result
                }
            }
        }
    }    

    # Local GPO scripts
    $LocalGPOs = (
        'Startup',
        'Shutdown'
    ) 
    foreach ($LocalGPO in $LocalGPOs) {
        $Key = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\$($LocalGPO)"
        if (Test-Path -Path $Key) {
            $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
            foreach ($SubKey in $SubKeys) {
                $_SubKey = (Join-Path -Path $Key -ChildPath $SubKey)
                $Sub_SubKeys = (Get-Item -Path $_SubKey).GetSubKeyNames()
                foreach ($Sub_SubKey in $Sub_SubKeys) {
                    $Result = Get-RegValue -Path (Join-Path -Path $_SubKey -ChildPath $Sub_SubKey) -Name 'script' -Category $Category
                    $Results += $Result
                }
            }
        }
    }    

    # Shell override by GPO
    $Results += Get-RegValue -Path 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Policies\System' -Name 'Shell' -Category $Category

    # AlternateShell
    $Results += Get-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SafeBoot' -Name 'AlternateShell' -Category $Category

    # AvailableShells
    $Results += Get-RegValue -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon\AlternateShells' -Name 'AvailableShells' -Category $Category

    # Terminal server
    $Results += Get-RegValue -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\Wds\rdpwd' -Name 'StartupPrograms' -Category $Category
    $Results += Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\Runonce' -Name '*' -Category $Category
    $Results += Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\RunonceEx' -Name '*' -Category $Category
    $Results += Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Terminal Server\Install\Software\Microsoft\Windows\CurrentVersion\Run' -Name '*' -Category $Category
    $Results += Get-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\WinStations\RDP-Tcp'  -Name 'InitialProgram' -Category $Category

    # Run
    foreach ($Arch in $Arches) { 
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\Run" -Name '*' -Category $Category
        $Results += $Result
    }

    # RunOnce
    foreach ($Arch in $Arches) { 
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\RunOnce" -Name '*' -Category $Category 
        $Results += $Result
    }

    # RunOnceEx
    foreach ($Arch in $Arches) { 
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows\CurrentVersion\RunOnceEx" -Name '*' -Category $Category
        $Results += $Result
    }

    # LNK files or direct executable
    $KeyPath = "$($env:systemdrive)\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
    if (Test-Path -Path $KeyPath -PathType Container) {
        $Wsh = new-object -comobject 'WScript.Shell'
        $Paths = Get-ChildItem -Path $KeyPath
        foreach ($Path in $Paths) {
            $File = $Path
            try {
                $Header = (Get-Content -Path $($Path.FullName) -Encoding Byte -ReadCount 1 -TotalCount 2) -as [string]
                Switch ($Header) {
                    '77 90' {
                        $Result = New-Object psobject
                        $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $KeyPath
                        $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $File.Name
                        $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $File.FullName
                        $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                        $Results += $Result
                        break
                    }
                    '76 0' {
                        $shortcut = $Wsh.CreateShortcut($File.FullName)
                        $Result = New-Object psobject
                        $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $KeyPath
                        $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $File.Name
                        $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value "$($shortcut.TargetPath) $($shortcut.Arguments)"
                        $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                        $Results += $Result
                        break
                    }
                default {}
                }
            } catch {
            }
        }
    }

    # Run by GPO
    $Results += Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run' -Name '*' -Category $Category

    # Show all subkey that have a StubPath value
    foreach ($Arch in $Arches) { 
        $Key = "HKLM:\SOFTWARE\$($Arch)\Microsoft\Active Setup\Installed Components"
        $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name 'StubPath' -Category $Category
            $Results += $Result
        }

    }

    $Result = Get-RegValue -Path 'HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows' -Name 'IconServiceLib' -Category $Category
    $Results +=

    foreach ($Arch in $Arches) { 
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows CE Services\AutoStartOnConnect" -Name '*' -Category $Category
        $Results += $Result
    }
    foreach ($Arch in $Arches) { 
        $Result = Get-RegValue -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Windows CE Services\AutoStartOnDisconnect" -Name '*' -Category $Category 
        $Results += $Result
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            switch -Regex ($tmpVal) {
                '\\Rundll32\.exe\s' {
                    $tmpVal = (($tmpVal -split '\s')[1] -split ',')[0]
                    break;
                }
                '\\Rundll32\.exe"' {
                    $tmpVal = (($tmpVal -split '\s',2)[1] -split ',')[0] -replace '"',''
                    break;
                }
                '^"[A-Z]:\\Program' {
                    $tmpVal = ($tmpVal -split '"')[1]
                    break;
                }
                '^"[A-Z]:\\Windows' {
                    $tmpVal = ($tmpVal -split '"')[1]
                    break;
                }
                'rdpclip' {
                    $tmpVal = "$($env:SystemRoot)\system32\$($tmpVal).exe"
                    break
                }
                '^Explorer\.exe$' {
                    $tmpVal = "$($env:SystemRoot)\$($tmpVal)"
                    break
                }
                '^regsvr32\.exe\s/s\s/n\s/i:U\sshell32\.dll' {
                    if ($tmpVal -match 'Wow6432Node') {
                        $tmpVal = "$($env:SystemRoot)\syswow64\shell32.dll"
                    } else {
                        $tmpVal = "$($env:SystemRoot)\system32\shell32.dll"
                    }
                    break
                }
                '^C:\\Windows\\system32\\regsvr32\.exe\s/s\s/n\s/i:/UserInstall\sC:\\Windows\\system32\\themeui\.dll' {
                    if ($tmpVal -match 'Wow6432Node') {
                        $tmpVal = "$($env:SystemRoot)\syswow64\themeui.dll"
                    }else {
                        $tmpVal = "$($env:SystemRoot)\system32\themeui.dll"
                    }
                    break
                }
                '^C:\\Windows\\system32\\cmd\.exe\s/D\s/C\sstart\sC:\\Windows\\system32\\ie4uinit\.exe\s\-ClearIconCache' {
                    if ($tmpVal -match 'Wow6432Node') {
                        $tmpVal = "$($env:SystemRoot)\syswow64\ie4uinit.exe"
                    }else {
                        $tmpVal = "$($env:SystemRoot)\system32\ie4uinit.exe"
                    }
                    break
                }
                '^[A-Z]:\\Windows\\' {
                    if ($tmpVal -match 'Wow6432Node') {
                        $tmpVal = (($tmpVal -split '\s')[0] -replace ',','') -replace 'System32','Syswow64'
                    } else {
                        $tmpVal = (($tmpVal -split '\s')[0] -replace ',','')
                    }
                    break
                }
                '^[a-zA-Z0-9]+\.(exe|dll)' {
                    if ($tmpVal -match 'Wow6432Node') {
                        $tmpVal = Join-Path -Path "$($env:SystemRoot)\syswow64" -ChildPath ($tmpVal -split '\s')[0]
                    } else {
                        $tmpVal = Join-Path -Path "$($env:SystemRoot)\system32" -ChildPath ($tmpVal -split '\s')[0]
                    }
                    break
                }
                '^RunDLL32\s' {
                    $tmpVal = Join-Path -Path "$($env:SystemRoot)\system32" -ChildPath (($tmpVal -split '\s')[1] -split ',')[0]
                    break;
                }
                # ProgramFiles
                '^[A-Za-z]:\\Program\sFiles\\' {
                    $tmpVal = Join-Path -Path "$($env:ProgramFiles)" -ChildPath (
                        ([regex]'[A-Za-z]:\\Program\sFiles\\(?<File>.*\.exe)\s?').Matches($tmpVal) | 
                        Select-Object -Expand Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value
                    )                                        
                    break
                }
                # ProgramFilesx86
                '^[A-Za-z]:\\Program\sFiles\s\(x86\)\\' {
                    $tmpVal = Join-Path -Path "$(${env:ProgramFiles(x86)})" -ChildPath (
                        ([regex]'[A-Za-z]:\\Program\sFiles\s\(x86\)\\(?<File>.*\.exe)\s?').Matches($tmpVal) | 
                        Select-Object -Expand Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value
                    )
                    break
                }
                # C:\Users
                '^"[A-Za-z]:\\' {
                    $tmpVal = ($tmpVal -split '"')[1]
                        break;
                }
                default {
                    Write-Verbose -Message "default: $($tmpVal)"
                    [string]::Empty
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPWinsock {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'Winsock'
    $Results = @()
    $Arches = (
        $null,
        '64'
    )

    Write-Verbose -Message 'Looking for Winsock protocol and network providers entries'
    #region Winsock providers

    foreach ($Arch in $Arches) {
        $Key = "HKLM:\System\CurrentControlSet\Services\WinSock2\Parameters\Protocol_Catalog9\Catalog_Entries$($Arch)"
        $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value "$Key\$($SubKey)"
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value 'PackedCatalogItem'
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value ((New-Object -TypeName System.Text.ASCIIEncoding).GetString((Get-ItemProperty -Path "$Key\$($SubKey)" -Name PackedCatalogItem).PackedCatalogItem,0,211) -split ([char][int]0))[0]
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result
        }
    }

    foreach ($Arch in $Arches) {
        $Key = "HKLM:\System\CurrentControlSet\Services\WinSock2\Parameters\NameSpace_Catalog5\Catalog_Entries$($Arch)"
        $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name 'LibraryPath' -Category $Category
            $Results += $Result
        }
    }

    #region Network providers
    $Category = 'NetworkProviders'
    $Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\NetworkProvider\Order'
    $Values = (Get-RegValue -Path $key -Name 'ProviderOrder' -Category $Category).Value -split ','
    foreach ($Value in $Values) {
        $Result = Get-RegValue -Path "HKLM:\SYSTEM\CurrentControlSet\services\$($Value)\NetworkProvider" -Name 'ProviderPath' -Category $Category
        $Results += $Result
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($Entry.Category -eq 'Winsock') {
                if ($tmpVal -match '^%SystemRoot%\\system32\\' ) {
                        $tmpVal = $tmpVal -replace '%SystemRoot%',"$($env:SystemRoot)";
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPCodecs {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'Codecs'
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )

    Write-Verbose -Message 'Looking for Codecs'
    #region Codecs

    # Drivers32
    foreach ($Arch in $Arches) {
        $Result = Get-RegValue -Path "HKLM:\Software\$($Arch)\Microsoft\Windows NT\CurrentVersion\Drivers32" -Name '*' -Category $Category
        $Results += $Result
    }		

    # Filter
    $Key = 'HKLM:\Software\Classes\Filter'
    if (Test-Path -Path $key -PathType Container) {
        $SubKeys = (Get-Item -Path $key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path (Join-Path -Path 'HKLM:\SOFTWARE\Classes\CLSID' -ChildPath "$($SubKey)\InprocServer32") -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result			
        }			
    }

    # Instances
    $Instances = (
        '{083863F1-70DE-11d0-BD40-00A0C911CE86}',
        '{AC757296-3522-4E11-9862-C17BE5A1767E}',
        '{7ED96837-96F0-4812-B211-F13C24117ED3}',
        '{ABE3B9A4-257D-4B97-BD1A-294AF496222E}'
    )
    foreach ($Instance in $Instances) {
        $Item = $Instance
        foreach ($Arch in $Arches) {
            $Key = "HKLM:\Software\$($Arch)\Classes\CLSID\$($Item)\Instance"
            $CLSIDP = "HKLM:\Software\$($Arch)\Classes\CLSID"
            if (Test-Path -Path $Key -PathType Container) {
                $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
                foreach ($SubKey in $SubKeys) {
                    try {
                        $Result = New-Object psobject
                        $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                        $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
                        $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path (Join-Path -Path $CLSIDP -ChildPath "$($SubKey)\InprocServer32") -Name '(default)' -ErrorAction Stop).'(default)'
                        $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                        $Results += $Result	
                    } catch {
                    }		
                }
            }		
        }			
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            Switch -Regex ($tmpVal) {
                '^[A-Z]:\\Windows\\' {
                    if ($Entry.Path -match 'Wow6432Node') {
                        $tmpVal = $tmpVal -replace 'system32','SysWOW64'
                    }
                    break
                }
                # '^[A-Z]:\\Program\sFiles' {
                '^[A-Z]:\\[Pp]rogra' {
                    $tmpVal = $tmpVal  | Get-NormalizedFileSystemPath
                    break
                }
                default {
                    if ($tmpVal -match 'Wow6432Node') {
                        $tmpVal = Join-Path "$($env:systemroot)\Syswow64" -ChildPath $tmpVal
                    } else {
                        $tmpVal = Join-Path "$($env:systemroot)\System32" -ChildPath $tmpVal
                    }
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPOfficeAddins {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = ''
    $Results = @()
    $Arches = (
        $null,
        'Wow6432Node'
    )

    Write-Verbose -Message 'Looking for Office Addins entries'
    #region Office Addins

    $Category = @{ Category = 'Office Addins'}
    foreach ($Arch in $Arches) {
        if (Test-Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Office") {
            $OfficeKeys = (Get-Item "HKLM:\SOFTWARE\$($Arch)\Microsoft\Office").GetSubKeyNames()
            foreach ($OfficeKey in $OfficeKeys) {
                if (Test-Path -Path (Join-Path -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Office" -ChildPath "$($OfficeKey)\Addins") -PathType Container) {
                    $Key = (Join-Path -Path "HKLM:\SOFTWARE\$($Arch)\Microsoft\Office" -ChildPath "$($OfficeKey)\Addins")
                    # Iterate through the Addins names
                    $SubKeys = (Get-item -Path $Key).GetSubKeyNames()
                    foreach ($SubKey in $SubKeys) {
                        try {
                            $Result = New-Object psobject
                            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
                            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $(
                                $CLSID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\$($SubKey)\CLSID" -Name '(default)' -ErrorAction Stop).'(default)';
                                    if ((Get-ItemProperty -Path "HKLM:\SOFTWARE\$Arch\Classes\CLSID\$CLSID\InprocServer32"  -Name '(default)' -ErrorAction SilentlyContinue).'(default)') {
                                        (Get-ItemProperty -Path "HKLM:\SOFTWARE\$Arch\Classes\CLSID\$CLSID\InprocServer32"  -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
                                    } else {
                                        $CLSID
                                    }                                         
                            )
                            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                            $Results += $Result	
                        } catch {
                        }
                    }
                }
            }
        }
    } 

    # Microsoft Office Memory Corruption Vulnerability (CVE-2015-1641)
    $Key = "HKLM:\SOFTWARE\Microsoft\Office test\Special\Perf"
    if (Test-Path $Key) {
        if ((Get-ItemProperty -Path $Key -Name '(default)' -ErrorAction SilentlyContinue).'(default)') {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value '(default)'
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value (Get-ItemProperty -Path $Key -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result	
        }
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($Entry.Path -match 'Wow6432Node' -and $tmpVal -imatch 'system32') {
                $tmpVal = $tmpVal -replace 'system32','syswow64'
            }
            if ($tmpVal) {
                Switch -Regex ($tmpVal) {
                    #GUID
                    '^(\{)?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\})?' { 
                        $tmpVal = ([system.guid]::Parse( ($tmpVal -split '\s')[0])).ToString('B')
                        break
                    }
                    default {
                        $tmpVal = $tmpVal -replace '"','' | Get-NormalizedFileSystemPath
                    }
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPPrintMonitors {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'PrintMonitor'
    $Results = @()

    Write-Verbose -Message 'Looking for Print Monitor DLLs entries'
    #region Print monitors

    $Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors'
    $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
    foreach ($SubKey in $SubKeys) {
        $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name 'Driver' -Category $Category
        $Results += $Result
    }

    $Key = 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Providers'
    $SubKeys = (Get-Item -Path $key).GetSubKeyNames()
    foreach ($SubKey in $SubKeys) {
        $Result = Get-RegValue -Path "$Key\$($SubKey)" -Name 'Name' -Category $Category
        $Results += $Result
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($Entry.Path -match 'Wow6432Node' -and $tmpVal -imatch 'system32') {
                $tmpVal = $tmpVal -replace 'system32','syswow64'
            }
            if ($tmpVal) {
                Switch -Regex ($tmpVal ) {
                    #GUID
                    '^(\{)?[A-Za-z0-9]{4}([A-Za-z0-9]{4}\-?){4}[A-Za-z0-9]{12}(\})?' { 
                        $tmpVal = ([system.guid]::Parse( ($tmpVal -split '\s')[0])).ToString('B')
                        break
                    }
                    default {
                        $tmpVal = $tmpVal -replace '"','' | Get-NormalizedFileSystemPath
                    }
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPLSAProviders {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'LSAProviders'
    $Results = @()

    Write-Verbose -Message 'Looking for LSA Security Providers entries'
    #region LSA providers

    # REG_SZ 
    $Result = Get-RegValue -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\SecurityProviders' -Name 'SecurityProviders' -Category $Category
    $Results += $Result

    # REG_MULTI_SZ
    $Names = (
        'Authentication Packages',
        'Notification Packages',
        'Security Packages'
    )

    foreach ($Name in $Names) {
        $Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
        $Values = (Get-RegValue -Path $Key -Name $Name -Category $Category).Value
        foreach ($Value in $Values) {
            if ($Value -ne '""') {
                $Result = New-Object psobject
                $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
                $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Name
                $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $Value
                $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                $Results += $Result	
            }
        }
    }

    # HKLM\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig\Security Packages
    $Key = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig"
    $Name = 'Security Packages'
    if (Test-Path -Path $Key -PathType Container) {
        $Values = (Get-RegValue -Path $Key -Name $Name -Category $Category).Value
        foreach ($Value in $Values) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Name
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $Value
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result	
        }
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal -match '\.dll$') {
                $tmpVal = Join-Path -Path "$($env:SystemRoot)\system32" -ChildPath $tmpVal
            } else {
                $tmpVal = Join-Path -Path "$($env:SystemRoot)\system32" -ChildPath "$($tmpVal).dll"
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPService {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Results = @()
    
    Write-Verbose -Message 'Looking for Services and Drivers'
    #region Services

    $SubKeys = (Get-Item -Path 'HKLM:\System\CurrentControlSet\Services').GetSubKeyNames()
    foreach ($SubKey in $SubKeys) {
        $Type = $null
        $Key  = "HKLM:\System\CurrentControlSet\Services\$($SubKey)"
        try {
            $Type = Get-ItemProperty -Path $Key -Name Type -ErrorAction Stop
        } catch {
        }
        if ($Type) {
            Switch ($Type.Type) {
                1  {
                    $Result = Get-RegValue -Path $Key -Name 'ImagePath' -Category 'Drivers'
                    $Results += $Result
                    break
                }
                16 {
                    $Result = Get-RegValue -Path $Key -Name 'ImagePath' -Category 'Services'
                    $Results += $Result
                    $Result = Get-RegValue -Path "$Key\Parameters" -Name 'ServiceDll' -Category 'Services'
                    $Results += $Result
                    break
                }
                32 {
                    $Result = Get-RegValue -Path $Key -Name 'ImagePath' -Category 'Services'
                    $Results += $Result
                    $Result = Get-RegValue -Path "$Key\Parameters" -Name 'ServiceDll' -Category 'Services'
                    $Results += $Result
                    break
                }
                default { 
                    # $_ 
                }
            }
        }
    }

    # Font drivers
    $Result = Get-RegValue -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Font Drivers' -Name '*' -Category 'Services'
    $Results += $Result

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {

            $tmpVal = $Entry.Value -replace '"',""
            if ($Entry.Category -eq 'Drivers') {
                switch -Regex ($tmpVal) {
                    #'^\\SystemRoot\\System32\\drivers\\' {
                    '^\\SystemRoot\\System32\\' {
                        $tmpVal = $tmpVal -replace '\\Systemroot',"$($env:systemroot)"
                        break;
                    }
                    '^System32\\[dD][rR][iI][vV][eE][rR][sS]\\' {
                        $tmpVal = Join-Path -Path "$($env:systemroot)" -ChildPath $tmpVal
                        break;
                    }
                    '^\\\?\?\\C:\\Windows\\system32\\drivers' {
                        $tmpVal = $tmpVal -replace '\\\?\?\\',''
                        break;
                    }
                    '^System32\\CLFS\.sys' {
                        $tmpVal = $tmpVal -replace 'System32\\',"$($env:systemroot)\system32\"
                    }
                    '^"?[A-Za-z]\\[Pp]rogram\s[fF]iles.*\\(?<FilePath>.*\\\.exe)\s?' {
                        $tmpVal = Join-Path -Path "$($env:ProgramFiles)" -ChildPath (
                            ([regex]'^"?[A-Za-z]\\[Pp]rogram\s[fF]iles.*\\(?<FilePath>.*\\\.exe)\s?').Matches($tmpVal) | 
                            Select-Object -Expand Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value
                        )                                        
                        break
                    }
                    'SysmonDrv.sys' {
                        $tmpVal = $env:PATH -split ';'| ForEach-Object { 
                            Get-ChildItem -Path $_\*.sys -Include SysmonDrv.sys -Force -EA 0 
                        } | Select-Object -First 1 -ExpandProperty FullName
                        break
                    }
                    default {
                        $tmpVal = $tmpVal
                    }
                }
            } elseif ($Entry.Category -eq 'Services') {
                switch -Regex ($tmpVal) {
                    '^"?[A-Za-z]:\\[Ww][iI][nN][dD][oO][Ww][sS]\\' {
                        $tmpVal = Join-Path -Path "$($env:systemroot)" -ChildPath (
                            ([regex]'^"?[A-Za-z]:\\[Ww][iI][nN][dD][oO][Ww][sS]\\(?<FilePath>.*\.(exe|dll))\s?').Matches($tmpVal) | 
                            Select-Object -Expand Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value
                        )  
                        break
                    }
                    '^"?[A-Za-z]:\\[Pp]rogram\s[fF]iles\\(?<FileName>.*\.[eE][xX][eE])\s?' {
                        $tmpVal = Join-Path -Path "$($env:ProgramFiles)" -ChildPath (
                            ([regex]'^"?[A-Za-z]:\\[Pp]rogram\s[fF]iles\\(?<FileName>.*\.[eE][xX][eE])\s?').Matches($tmpVal) | 
                            Select-Object -Expand Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value
                        )  
                        break
                    }
                    '^"?[A-Za-z]:\\[Pp]rogram\s[fF]iles\s\(x86\)\\(?<FileName>.*\.[eE][xX][eE])\s?' {
                        $tmpVal = Join-Path -Path "$(${env:ProgramFiles(x86)})" -ChildPath (
                            ([regex]'^"?[A-Za-z]:\\[Pp]rogram\s[fF]iles\s\(x86\)\\(?<FileName>.*\.[eE][xX][eE])\s?').Matches($tmpVal) | 
                            Select-Object -Expand Groups | Select-Object -Last 1 | Select-Object -ExpandProperty Value
                        )  
                        break
                    }
                    'winhttp.dll' {
                        $tmpVal = Join-Path -Path "$($env:SystemRoot)\System32" -ChildPath 'winhttp.dll'
                        break
                    }
                    'atmfd.dll' {
                        $tmpVal = Join-Path -Path "$($env:SystemRoot)\System32" -ChildPath 'atmfd.dll'
                        break
                    }
                    default {
                        $tmpVal = $tmpVal
                    }
                }
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPWinLogon {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'WinLogon'
    $Results = @()

    Write-Verbose -Message 'Looking for Winlogon entries'
    #region Winlogon

    $Result = Get-RegValue -Path 'HKLM:\SYSTEM\Setup' -Name 'CmdLine' -Category $Category
    $Results += $Result

    $Names = (
        'Credential Providers',
        'Credential Provider Filters',
        'PLAP Providers'
    )
    foreach ($Name in $Names) {
        $Key = Join-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Authentication' -ChildPath $Name
        $SubKeys = (Get-Item -Path $Key).GetSubKeyNames()
        foreach ($SubKey in $SubKeys) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Key
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $SubKey
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $(Get-ItemProperty -Path (Join-Path -Path 'HKLM:\SOFTWARE\Classes\CLSID' -ChildPath "$($SubKey)\InprocServer32") -Name '(default)' -ErrorAction SilentlyContinue).'(default)'
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result			
        }
    }  

    if (Test-Path -Path 'HKLM:\System\CurrentControlSet\Control\BootVerificationProgram' -PathType Container) {
        $Result = Get-RegValue -Path 'HKLM:\System\CurrentControlSet\Control\BootVerificationProgram' -Name 'ImagePath' -Category $Category
        $Results += $Result
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {
            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal -match '^[a-zA-Z0-9]*\.[dDlL]{3}') {
                $tmpVal = Join-Path -Path "$($env:SystemRoot)\System32" -ChildPath $tmpVal
                break
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

function Get-ASEPWmi {
    [CmdletBinding()]
    Param (
        [switch]$ShowSignature,
        [switch]$ShowFileHash,
        [switch]$ShowEntropy
    )

    $Category = 'WMI'
    $Results = @()

    Write-Verbose -Message 'Looking for WMI Database entries'
    # Region WMI

    # Permanent events
    $ActiveScriptEventConsumers = Get-WMIObject -Namespace root\Subscription -Class __EventConsumer -ErrorAction SilentlyContinue| Where-Object { $_.__CLASS -eq 'ActiveScriptEventConsumer' }
    foreach ($Consumer in $ActiveScriptEventConsumers) {
        if ($Consumer.ScriptFileName) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Consumer.__PATH
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Consumer._Name
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $Consumer._ScriptFileName
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result        
        } elseif ($Consumer.ScriptText) {
            $Result = New-Object psobject
            $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Consumer.__PATH
            $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Consumer._Name
            $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $null
            $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
            $Results += $Result
        } 
    }

    $CLIEventConsumers = Get-WMIObject -Namespace root\Subscription -Class __EventConsumer -ErrorAction SilentlyContinue| Where-Object { $_.__CLASS -eq 'CommandlineEventConsumer' }
    foreach ($Consumer in $CLIEventConsumers) {
        $Result = New-Object psobject
        $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Consumer.__PATH
        $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Consumer._Name
        $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value "$($Consumer.WorkingDirectory)$($Consumer.ExecutablePath)"
        $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
        $Results += $Result
    }

    # List recursiveley registered and resolved WMI providers
    $Providers = Get-WmiObject -Namespace root -Recurse -Class __Provider -List -ErrorAction SilentlyContinue
    foreach ($Provider in $Providers) {
        $ResolvedProviders = Get-WmiObject -Namespace $Provider.__NAMESPACE -Class $Provider.__CLASS -ErrorAction SilentlyContinue
        foreach ($Resolved in $ResolvedProviders) {
            Write-Verbose -Message "Found provider clsid $($Resolved.CLSID) from under the $($Resolved.__NAMESPACE) namespace"
            if (($CLSID = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Classes\CLSID\$($Resolved.CLSID)\InprocServer32" -Name '(default)' -ErrorAction SilentlyContinue).'(default)')) {
                $Result = New-Object psobject
                $Result | Add-Member -MemberType NoteProperty -Name 'Path' -Value $Resolved.__PATH
                $Result | Add-Member -MemberType NoteProperty -Name 'Item' -Value $Resolved._Name
                $Result | Add-Member -MemberType NoteProperty -Name 'Value' -Value $CLSID
                $Result | Add-Member -MemberType NoteProperty -Name 'Category' -Value $Category
                $Results += $Result
            }
        }
    }

    #Get File Path
    foreach ($Entry in $Results) {
        if ($Entry) {

            $tmpVal = $Entry.Value -replace '"',""
            if ($tmpVal) {
                $tmpVal = $tmpVal
                
            } else {
                $tmpVal = $null
            }
            $Entry | Add-Member -MemberType NoteProperty -Name 'FilePath' -Value $tmpVal
        }
    }
    if ($Results) {Process-Results -Results $Results}
}

#Main Function
$functionlist = @(
    "Get-ASEPAppInitDLLs -ShowSignature -ShowFileHash",                    #0 67ms / 114ms  +Sig  +Hash
    "Get-ASEPBootExecute -ShowSignature",                                  #1 194ms / 600ms  +Sig
    "Get-ASEPExplorerAddons -ShowSignature -ShowFileHash -ShowEntropy",    #2 51s902ms / 3m48s668ms #no-go
    "Get-ASEPSidebarGadgets",                                              #3 106ms / 83ms
    "Get-ASEPImageHijacks",                                                #4 798ms / 779ms 
    "Get-ASEPIEAddons -ShowSignature -ShowFileHash -ShowEntropy",          #5 506ms / 7s68ms   #no-go
    "Get-ASEPKnownDLLs -ShowSignature",                                    #6 363ms / 12s707ms  +Sig  ***
    "Get-ASEPLogon -ShowSignature",                                        #7 1s755ms / 38s352ms  +Sig  ###
    "Get-ASEPWinsock",                                                     #8 639ms / 4s368ms
    "Get-ASEPCodecs -ShowSignature -ShowFileHash -ShowEntropy",            #9 4s638ms / 52s164ms   #no-go
    "Get-ASEPOfficeAddins -ShowSignature -ShowFileHash -ShowEntropy",      #10 5s799ms / 13s265ms  #no-go
    "Get-ASEPPrintMonitors",                                               #11 234ms / 206ms ###
    "Get-ASEPLSAProviders",                                                #12 204ms / 1s563ms
    "Get-ASEPService -ShowSignature -ShowFileHash",                        #13 8s957ms / 1m25s657ms  +Sig  +Hash? ###
    "Get-ASEPWinLogon -ShowSignature -ShowFileHash",                       #14 380ms / 8s324ms  +Sig  +Hash?  ###
    "Get-ASEPWmi"                                                          #15 3m55s817ms / no friggin way   #no-go
)

Safe comprehensive spread
0, 1, 3, 4, 6, 7, 8, 11, 12, 13, 14  | foreach {
    iex $functionlist[$_]
}

#boot Logon spread
#1, 7, 14 | foreach { iex $functionlist[$_] }
#
