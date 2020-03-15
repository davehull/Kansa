<# 
.SYNOPSIS
Get-USBForensics.ps1 retrieves USB artifacts


.EXAMPLE
Get-USBForensics.ps1

.NOTES
To get GUI View for USb artifacts from the output of kansa
    $Data = import-csv [path to the csv]
    $Data | out-gridview

Last Connection time is not accurte 100%

2- The output of the script is an object which stores the content of the retrived file in the content property, to get teh actual file use Decompress-KansaFileOutput to decompress and generate the files for you
    decompression script works only with CSV files

.EXAMPLE
kansa.ps1 -Target <ComputerIP or Name> -ModulePath ".\Modules\Registry\Get-USBForensics.ps1"

#>


###########
## I add this class to be able to use C/C++ functions (P/Invoke)
##
## Add-Type causing jit compilation, triggering csc.exe and cvtres.exe processes, writing temporary files and dlls to disk on the endpoint
###########
Add-Type @"

    using System;

    using System.Text;

    using System.Runtime.InteropServices; 

    namespace USBForensics {

         public class advapi32 {


          [DllImport("advapi32.dll", CharSet = CharSet.Auto)]
            public static extern int RegOpenKeyEx
            (
                UIntPtr hKey,
                string subKey,
                int ulOptions,
                int samDesired,
                out UIntPtr hkResult
            );




            [DllImport("advapi32.dll", CharSet = CharSet.Auto)]

            public static extern Int32 RegQueryInfoKey(


                UIntPtr hKey,

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

                out System.Runtime.InteropServices.ComTypes.FILETIME lpftLastWriteTime

            );


            [StructLayout(LayoutKind.Sequential)]
            public struct SYSTEMTIME 
            {
                  [MarshalAs(UnmanagedType.U2)] public short Year;
                  [MarshalAs(UnmanagedType.U2)] public short Month;
                  [MarshalAs(UnmanagedType.U2)] public short DayOfWeek;
                  [MarshalAs(UnmanagedType.U2)] public short Day;
                  [MarshalAs(UnmanagedType.U2)] public short Hour;
                  [MarshalAs(UnmanagedType.U2)] public short Minute;
                  [MarshalAs(UnmanagedType.U2)] public short Second;
                  [MarshalAs(UnmanagedType.U2)] public short Milliseconds;

                  public SYSTEMTIME( DateTime dt )
                  {
                    dt = dt.ToUniversalTime();  // SetSystemTime expects the SYSTEMTIME in UTC
                    Year = (short)dt.Year;
                    Month = (short)dt.Month;
                    DayOfWeek = (short)dt.DayOfWeek;
                    Day = (short)dt.Day;
                    Hour = (short)dt.Hour;
                    Minute = (short)dt.Minute;
                    Second = (short)dt.Second;
                    Milliseconds = (short)dt.Millisecond;
                  }

            }



            [DllImport("kernel32.dll",CallingConvention=CallingConvention.Winapi,SetLastError=true)]
            public static extern bool FileTimeToSystemTime
            (
            [In] ref System.Runtime.InteropServices.ComTypes.FILETIME lpFileTime,
            out SYSTEMTIME lpSystemTime
            );


        }

    }

"@


# Store the type in a variable:

$RegTools = ("USBForensics.advapi32") -as [type]


###########
# Call for RegkeyInfo C function
###########
function Get-RegKeyInfo{

    Param(
        [Parameter(Mandatory=$True,Position=0)]
            [String]$RegRoot,
        [Parameter(Mandatory=$True,Position=1)]
            [String]$RegSubKey
    )
    # this HashTable ($RootKeys) contains the predefined numbers for various Key Hives

    $RootKeys = @{ HKLM = 2147483650; HKCU = 2147483649; HKCR = 2147483648; HKU = 2147483651; HKCC = 2147483653 }
    $hkeyRes = [UIntPtr]::new(0) #Handle to the opened key (Returned by RegOpenKeyEx)
    $HKEY = [UIntPtr]::new($RootKeys[$RegRoot])
    $res = $RegTools::RegOpenKeyEx($HKEY,$RegSubKey,0,1,[ref]$hkeyRes)
    if(-not($res -eq 0))
    {
        Write-Error (("Couldn't open {0}//{1}" -f $RegRoot , $RegSubKey))
        break;
    }

    $SubKeyCount = $ValueCount = $null

    $LastWrite = New-Object System.Runtime.InteropServices.ComTypes.FILETIME

    #Call the function

    $res = $RegTools::RegQueryInfoKey($hkeyRes, $null, [ref]$null, $null, [ref] $SubKeyCount, [ref] $null, [ref] $null, [ref] $ValueCount, [ref] $null, [ref] $null, [ref] $null, [ref] $LastWrite)
    if(-not($res -eq 0))
    {
        Write-Error (("Couldn't Query info about {0}//{1}" -f $RegRoot , $RegSubKey))
        break;
    }

    #Convert FILETIME to SYSTEMTIME

    $SYSTEMTIME = New-Object USBForensics.advapi32+SYSTEMTIME

    $res = $RegTools::FileTimeToSystemTime([ref]$LastWrite,[ref]$SYSTEMTIME)
    if($res -eq 0)
    {
        Write-Error ("Couldn't convert FILETIME to SYSTEMTIME")
        break;
    }


    #SYSTEMTIME will be in UTC+0 so you have to query TimeZone and add it to the hours

    $LastWriteTime = $SYSTEMTIME.year.tostring() + "/" + $SYSTEMTIME.month.tostring() + "/" + $SYSTEMTIME.day.tostring() + "  " + $SYSTEMTIME.Hour.tostring() + ":" + $SYSTEMTIME.Minute.tostring() + ":" + $SYSTEMTIME.Second.tostring() 
   
   
   # Return results:

    $RegKey = $RegRoot + ":\" + $RegSubKey

    $obj = "" | Select-Object Key,SubKeyCount,ValueCount,LastWriteTime
    $obj.Key = $RegKey
    $obj.SubKeyCount = $SubKeyCount
    $obj.ValueCount = $ValueCount
    $obj.LastWriteTime = $LastWriteTime

    $obj

}


$Hive = 'HKLM:\'
$USBSTROKEY = 'SYSTEM\CurrentControlSet\Enum\USBSTOR\'
$USBKEY = 'SYSTEM\CurrentControlSet\Enum\USB\'
$Devices = Get-ChildItem -Path "$Hive$USBSTROKEY" | Select-Object -ExpandProperty Name | foreach {($_ -split 'USBSTOR\\')[1]}


foreach($Device in $Devices)
{
    
    $SerialNumbers = Get-ChildItem -Path "$Hive$USBSTROKEY$Device" | Select-Object -ExpandProperty Name | foreach {($_ -split "$Device\\")[1]}
    foreach($SerialNumber in $SerialNumbers)
    {
        $obj =  "" | Select-Object 'Serial #','Friendly Name','Mounted Name','First time connection','Last Time Connection',VID,PID,'Connected Now','User Name run it',DiskID,ClassGUID,volumeGUID
       
        $FriendlyName = $ClassGUID = [string]$Connected = $Accurate = $DiskId = "-"

        if((Get-ItemProperty -Path "$Hive$USBSTROKEY$Device\$SerialNumber" | Get-Member | Select-Object -ExpandProperty Name) -contains "FriendlyName")
        {
            $FriendlyName = Get-ItemProperty -Path "$Hive$USBSTROKEY$Device\$SerialNumber" -Name FriendlyName | Select-Object -ExpandProperty FriendlyName
        }
    
         if((Get-ItemProperty -Path "$Hive$USBSTROKEY$Device\$SerialNumber" | Get-Member | Select-Object -ExpandProperty Name) -contains "ClassGUID")
         {
            $ClassGUID = Get-ItemProperty -Path "$Hive$USBSTROKEY$Device\$SerialNumber" -Name ClassGUID | Select-Object -ExpandProperty ClassGUID
         }
         if(Test-Path -Path "$Hive$USBSTROKEY$Device\$SerialNumber\Device Parameters\Partmgr")
         {
            if((Get-ItemProperty -Path "$Hive$USBSTROKEY$Device\$SerialNumber\Device Parameters\Partmgr" | Get-Member | Select-Object -ExpandProperty Name) -contains "DiskId")
            {
                 $DiskId = Get-ItemProperty -Path "$Hive$USBSTROKEY$Device\$SerialNumber\Device Parameters\Partmgr" -Name DiskId | Select-Object -ExpandProperty DiskId
            }
        }

        ############
        # Start of checking if the USB is connected or not
        ###########

        if(GET-WMIOBJECT win32_diskdrive | Where { $_.InterfaceType -eq 'USB'} | where{$_.PnpDeviceID -match $SerialNumber}){$Connected = "True"}

        ############
        # End of checking if the USB is connected or not
        ###########



        #############
        #Start of getting Mounted Name
        #############
        $MountedName = ""
        $MountedNames =  Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Windows Portable Devices\Devices' | Select-Object -ExpandProperty Name | foreach {($_ -split '\\Devices\\')[1]}
        foreach($m in $MountedNames)
        {

            if ($m -match $SerialNumber)
            {     
                $MountedName = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Portable Devices\Devices\$m" -Name FriendlyName | Select-Object -ExpandProperty FriendlyName 
                $MountedNameRegKey = $m 
                break;      
            } 
            elseif($m -match $DiskId)
            {
                $MountedName = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows Portable Devices\Devices\$m" -Name FriendlyName | Select-Object -ExpandProperty FriendlyName 
                $MountedNameRegKey = $m 
                break;
            }


        }
        #############
        #End of getting Mounted Name
        #############




        #########
        #Start of getting First time connection
        #########
        if($MountedNameRegKey -match "SWD#WPDBUSENUM#")
        {
            $MountedNameRegKey_ = $MountedNameRegKey.Replace("SWD#WPDBUSENUM#","")
        }
        $LineNumber = (Get-Content -Path C:\Windows\INF\setupapi.dev.log | Select-String -Pattern "\(Hardware initiated\).*$MountedNameRegKey_").linenumber
        $FirstTimeConnection = if($LineNumber){(Get-Content -Path 'C:\Windows\INF\setupapi.dev.log' |select -Index $LineNumber).replace(">>>  Section start ","")}else{"-"} 

        #########
        #End of getting First time connection
        #########



        ##########
        #Start of Getting VID and PID
        ##########
        $USBKeyItems = Get-ChildItem -Path "$Hive$USBKEY" | Select-Object -ExpandProperty Name | foreach {($_ -split 'USB\\')[1]}
        foreach($USBKEYItem in $USBKeyItems)
        {
        
                if(Get-ChildItem -Path "$Hive$USBKEY$USBKeyItem" | Select-Object -ExpandProperty Name | foreach {($_ -split "$USBKeyItem\\")[1]} | where {$_ -match $SerialNumber.Substring(0,$SerialNumber.Length -2) })
                {
          
                    $matches = $USBKeyItem | Select-String -Pattern "VID_(\w+)&PID_(\w+)" -CaseSensitive
                    if($matches)
                    {
                        $obj.VID = $matches.matches.Groups[1].Value
                        $obj.PID = $matches.matches.Groups[2].Value
                        break
                    }

                } 

        }
        ##########
        #End of Getting VID and PID
        ##########




        ##########
        #Start of getting Volume GUID
        ##########
        $Mounted2Properties = Get-Item -Path HKLM:\SYSTEM\MountedDevices | select -ExpandProperty property 
        $Ascii = [System.Text.Encoding]::ASCII
        foreach($Mounted2Property in $Mounted2Properties)
        {
       
            $r = Get-ItemProperty -Path HKLM:\SYSTEM\MountedDevices -Name $Mounted2Property
            
            [byte[]]$u = @()

            for($i=0; $i -lt $r."$Mounted2Property".Length ; $i++)
            {
                 if($i % 2 -eq 0)
                     {
                        $u += $r."$Mounted2Property"[$i]
                     }
            }
           $tttt = $Ascii.GetString($u)
           if($tttt -match $SerialNumber)
           {
                if(($Mounted2Property | Select-String -Pattern "Volume(.*)").Matches.groups.Count -ge 2)
                {
                     $obj.volumeGUID = ($Mounted2Property | Select-String -Pattern "Volume(.*)").Matches.groups[1].Value
                }
           }
        }
        ##########
        #End of getting Volume GUID
        ##########




        ##########
        #Start of User who run it
        ##########
        $SIDs = @()
        $SIDs += Get-ChildItem -Path registry::HKEY_USERS -ErrorAction SilentlyContinue | where{$_.name.length -gt 20 -and $_.name -notmatch "classes"}|select -ExpandProperty Name | foreach {$_ -replace "HKEY_USERS\\",""}
        if($SIDs.count -eq 1)
        {
            $username = Get-WmiObject -Class win32_useraccount | where{$_.SID -eq $SIDs[0]} |select -ExpandProperty Name

                $obj.'User Name run it' = $username

        }
        else
        {
            
            foreach($SID in $SIDs)
            {
            
              $GUIDs =  Get-ChildItem -Path registry::HKEY_USERS\$SID\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2 | select -ExpandProperty Name | foreach {$_ -replace ".*MountPoints2\\",""}
              foreach($GUID in $GUIDs)
                {
                    if($GUID -eq $obj.volumeGUID)
                    {

                        $obj.'User Name run it' = Get-WmiObject -Class win32_useraccount | where{$_.SID -eq $SID} |select -ExpandProperty Name
                        break;

                    }

                }

            }

        }

        ##########
        #End of User who run it
        ##########


        

        $obj.'Serial #' = $SerialNumber
        $obj.'Connected Now' = $Connected
        $obj.'Friendly Name' = $FriendlyName
        $obj.DiskID = $DiskId
        $obj.ClassGUID = $ClassGUID
        $obj.'Mounted Name' = $MountedName
        $TimeZone = (Get-TimeZone).Displayname.split(" ")[0] 
        $obj.'First time connection' = $FirstTimeConnection + $TimeZone
        $temp = Get-RegKeyInfo -RegRoot "HKLM" -RegSubKey "$USBSTROKEY$Device\$SerialNumber"
        $obj.'Last Time Connection' = $temp.LastWriteTime + "(UTC+00:00)"
        $obj
        
        
    }

}



  Write-Host 'To get GUI View for USb artifacts from the output of kansa do the following:
    $Data = import-csv [path to the csv]
    $Data | out-gridview' -ForegroundColor Green
  