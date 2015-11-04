<#
.SYNOPSIS
Resolves many Windows GUIDs to human friendly values.

.DESCRIPTION
Resolve-WindowsGUID.ps1 takes a GUID from a Windows system and attempts
to return a human friendly value from either a static list or from a 
dynamically generated list of LogProvider GUIDs. There are undoubtedly 
other GUIDs in use throughout Windows that will not fall into either of 
these sets. If you encounter a GUID that you can't resolve via this 
script and find the human friendly value elsewhere, let me know and
I'll add it to the static list.

This script draws from four sources:
1) Shell32.dll
2) Microsoft public documentation
3) Logman.exe for LogProvider GUIDS
4) @EricRZimmerman's shared list

.PARAMETER GUID
A mandatory string representing a Windows GUID. GUIDs may be passed via
pipeline.

.INPUTS
System.String

You can pipe GUIDs to Resolve-WindowsGUID.ps1
.OUTPUTS
System.Management.Automation.PSCustomObject

Resolve-WindowsGUID.ps1 returns a human friendly string value that maps
to the provided GUID.

.EXAMPLE
.\Resolve-WindowsGUID.ps1 -GUID "1F3427C8-5C10-4210-AA03-2EE45287D668" | fl
GUID                 : 1F3427C8-5C10-4210-AA03-2EE45287D668
Shell32              : Not found.
Microsoft Documented : Not found.
LogProvider          : Not found.
EricRZimmerman       : User Pinned

.EXAMPLE
$GUID = @("D9DC8A3B-B784-432E-A781-5A1130A75963","F1B32785-6FBA-4FCF-9D55-7B8E7F157091","52FC89F8-995E-434C-A91E-199986449890")
$GUID | .\Resolve-WindowsGUID.ps1
GUID                 : D9DC8A3B-B784-432E-A781-5A1130A75963
Shell32              : C:\Users\foo\AppData\Local\Microsoft\Windows\History
Microsoft Documented : History
LogProvider          : Not found.
EricRZimmerman       : History

GUID                 : F1B32785-6FBA-4FCF-9D55-7B8E7F157091
Shell32              : C:\Users\foo\AppData\Local
Microsoft Documented : LocalAppData
LogProvider          : Not found.
EricRZimmerman       : Local

GUID                 : 52FC89F8-995E-434C-A91E-199986449890
Shell32              : Not found.
Microsoft Documented : Not found.
LogProvider          : Hypervisor Trace
EricRZimmerman       : Not found.

.EXAMPLE
.\Resolve-WindowsGUID.ps1 -GUID $GUID[0]
GUID                 : D9DC8A3B-B784-432E-A781-5A1130A75963
Shell32              : C:\Users\foo\AppData\Local\Microsoft\Windows\History
Microsoft Documented : History
LogProvider          : Not found.
EricRZimmerman       : History
#>

[CmdletBinding()]
Param(
[Parameter(Mandatory=$True,ValueFromPipeLine=$True,Position=0)]
    [String]$GUID
)

    Begin {
        $GUIDPattern = New-Object System.Text.RegularExpressions.Regex "([A-Fa-f0-9]{8}(?:-[A-Fa-f0-9]{4}){3}-[A-Fa-f0-9]{12})"
        # Static entries availabe on the web from Microsoft as of this writing here: 
        # https://msdn.microsoft.com/en-us/library/vstudio/bb882665(v=vs.100).aspx
        $MSWinGUIDHT = @{
            "DE61D971-5EBC-4F02-A3A9-6C82895E5C04" = "AddNewPrograms"
            "724EF170-A42D-4FEF-9F26-B60E846FBA4F" = "AdminTools"
            "A520A1A4-1780-4FF6-BD18-167343C5AF16" = "AppDataLow"
            "A305CE99-F527-492B-8B1A-7E76FA98D6E4" = "AppUpdates"
            "9E52AB10-F80D-49DF-ACB8-4330F5687855" = "CDBurning"
            "DF7266AC-9274-4867-8D55-3BD661DE872D" = "ChangeRemovePrograms"
            "D0384E7D-BAC3-4797-8F14-CBA229B392B5" = "CommonAdminTools"
            "C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D" = "CommonOEMLinks"
            "0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8" = "CommonPrograms"
            "A4115719-D62E-491D-AA7C-E74B8BE3B067" = "CommonStartMenu"
            "82A5EA35-D9CD-47C5-9629-E15D2F714E6E" = "CommonStartup"
            "B94237E7-57AC-4347-9151-B08C6C32D1F7" = "CommonTemplates"
            "0AC0837C-BBF8-452A-850D-79D08E667CA7" = "Computer"
            "4BFEFB45-347D-4006-A5BE-AC0CB0567192" = "Conflict"
            "6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD" = "Connections"
            "56784854-C6CB-462B-8169-88E350ACB882" = "Contacts"
            "82A74AEB-AEB4-465C-A014-D097EE346D63" = "ControlPanel"
            "2B0F765D-C0E9-4171-908E-08A611B84FF6" = "Cookies"
            "B4BFCC3A-DB2C-424C-B029-7FE99A87C641" = "Desktop"
            "FDD39AD0-238F-46AF-ADB4-6C85480369C7" = "Documents"
            "374DE290-123F-4565-9164-39C4925E467B" = "Downloads"
            "1777F761-68AD-4D8A-87BD-30B759FA33DD" = "Favorites"
            "FD228CB7-AE11-4AE3-864C-16F3910AB8FE" = "Fonts"
            "CAC52C1A-B53D-4EDC-92D7-6B2E8AC19434" = "Games"
            "054FAE61-4DD8-4787-80B6-090220C4B700" = "GameTasks"
            "D9DC8A3B-B784-432E-A781-5A1130A75963" = "History"
            "4D9F7874-4E0C-4904-967B-40B0D20C3E4B" = "Internet"
            "352481E8-33BE-4251-BA85-6007CAEDCF9D" = "InternetCache"
            "BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968" = "Links"
            "F1B32785-6FBA-4FCF-9D55-7B8E7F157091" = "LocalAppData"
            "2A00375E-224C-49DE-B8D1-440DF7EF3DDC" = "LocalizedResourcesDir"
            "4BD8D571-6D19-48D3-BE97-422220080E43" = "Music"
            "C5ABBF53-E17F-4121-8900-86626FC2C973" = "NetHood"
            "D20BEEC4-5CA8-4905-AE3B-BF251EA09B53" = "Network"
            "2C36C0AA-5812-4B87-BFD0-4CD0DFB19B39" = "OriginalImages"
            "69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C" = "PhotoAlbums"
            "33E28130-4E1E-4676-835A-98395C3BC3BB" = "Pictures"
            "DE92C1C7-837F-4F69-A3BB-86E631204A23" = "Playlists"
            "76FC4E2D-D6AD-4519-A663-37BD56068185" = "Printers"
            "9274BD8D-CFD1-41C3-B35E-B13F55A758F4" = "PrintHood"
            "5E6C858F-0E22-4760-9AFE-EA3317B67173" = "Profile"
            "62AB5D82-FDC1-4DC3-A9DD-070D1D495D97" = "ProgramData"
            "905E63B6-C1BF-494E-B29C-65B732D3D21A" = "ProgramFiles"
            "F7F1ED05-9F6D-47A2-AAAE-29D317C6F066" = "ProgramFilesCommon"
            "6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D" = "ProgramFilesCommonX64"
            "DE974D24-D9C6-4D3E-BF91-F4455120B917" = "ProgramFilesCommonX86"
            "6D809377-6AF0-444B-8957-A3773F02200E" = "ProgramFilesX64"
            "7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E" = "ProgramFilesX86"
            "A77F5D77-2E2B-44C3-A6A2-ABA601054A51" = "Programs"
            "DFDF76A2-C82A-4D63-906A-5644AC457385" = "Public"
            "C4AA340D-F20F-4863-AFEF-F87EF2E6BA25" = "PublicDesktop"
            "ED4824AF-DCE4-45A8-81E2-FC7965083634" = "PublicDocuments"
            "3D644C9B-1FB8-4F30-9B45-F670235F79C0" = "PublicDownloads"
            "DEBF2536-E1A8-4C59-B6A2-414586476AEA" = "PublicGameTasks"
            "3214FAB5-9757-4298-BB61-92A9DEAA44FF" = "PublicMusic"
            "B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5" = "PublicPictures"
            "2400183A-6185-49FB-A2D8-4A392A602BA3" = "PublicVideos"
            "52A4F021-7B75-48A9-9F6B-4B87A210BC8F" = "QuickLaunch"
            "AE50C081-EBD2-438A-8655-8A092E34987A" = "Recent"
            "BD85E001-112E-431E-983B-7B15AC09FFF1" = "RecordedTV"
            "B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC" = "RecycleBin"
            "8AD10C31-2ADB-4296-A8F7-E4701232C972" = "ResourceDir"
            "3EB685DB-65F9-4CF6-A03A-E3EF65729F3D" = "RoamingAppData"
            "B250C668-F57D-4EE1-A63C-290EE7D1AA1F" = "SampleMusic"
            "C4900540-2379-4C75-844B-64E6FAF8716B" = "SamplePictures"
            "15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5" = "SamplePlaylists"
            "859EAD94-2E85-48AD-A71A-0969CB56A6CD" = "SampleVideos"
            "4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4" = "SavedGames"
            "7D1D3A04-DEBB-4115-95CF-2F29DA2920DA" = "SavedSearches"
            "EE32E446-31CA-4ABA-814F-A5EBD2FD6D5E" = "SEARCH_CSC"
            "98EC0E18-2098-4D44-8644-66979315A281" = "SEARCH_MAPI"
            "190337D1-B8CA-4121-A639-6D472D16972A" = "SearchHome"
            "8983036C-27C0-404B-8F08-102D10DCFD74" = "SendTo"
            "7B396E54-9EC5-4300-BE0A-2482EBAE1A26" = "SidebarDefaultParts"
            "A75D362E-50FC-4FB7-AC2C-A8BEAA314493" = "SidebarParts"
            "625B53C3-AB48-4EC1-BA1F-A1EF4146FC19" = "StartMenu"
            "B97D20BB-F46A-4C97-BA10-5E3608430854" = "Startup"
            "43668BF8-C14E-49B2-97C9-747784D784B7" = "SyncManager"
            "289A9A43-BE44-4057-A41B-587A76D7E7F9" = "SyncResults"
            "0F214138-B1D3-4A90-BBA9-27CBC0C5389A" = "SyncSetup"
            "1AC14E77-02E7-4E5D-B744-2EB1AE5198B7" = "System"
            "D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27" = "SystemX86"
            "A63293E8-664E-48DB-A079-DF759E0509F7" = "Templates"
            "5B3749AD-B49F-49C1-83EB-15370FBD4882" = "TreeProperties"
            "0762D272-C50A-4BB0-A382-697DCD729B80" = "UserProfiles"
            "F3CE0F7C-4901-4ACC-8648-D5D44B04EF8F" = "UsersFiles"
            "18989B1D-99B5-455B-841C-AB7C74E4DDFC" = "Videos"
            "F38BF404-1D43-42F2-9305-67DE0B28FC23" = "Windows"
        }

        # Netsh show helper GUIDs
        $NetshShowHelperGUIDHT = @{
            "00770721-44EA-11D5-93BA-00B0D022DD1F" = "HNETMON.DLL bridge"
            "02BC1F81-D927-4EC5-8CBC-8DD65E3E38E8" = "AUTHFWCFG.DLL advfirewall"
            "0705ECA1-7AAC-11D2-89DC-006008B0E5B9" = "IFMON.DLL interface, ras"
            "0BFDC146-56A3-4311-A7D5-7D9953F8326E" = "WHHELPER.DLL winhttp"
            "13D12A78-D0FB-11D2-9B76-00104BCA495B" = "RASMONTR.DLL ip"
            "1C151866-F35B-4780-8CD2-E1924E9F03E1" = "NETIOHLP.DLL 6to4, isatap, portproxy, teredo"
            "1D8240C7-48B9-47CC-9E40-4F7A0A390E71" = "DOT3CFG.DLL lan"
            "1DD4935A-E587-4D16-AE27-14E40385AB12" = "P2PNETSH.DLL cloud"
            "35342B49-83B4-4FCC-A90D-278533D5BEA2" = "AUTHFWCFG.DLL firewall"
            "36B3EF76-94C1-460F-BD6F-DF0178D90EAC" = "RASMONTR.DLL ipv6"
            "3BB6DA1D-AC0C-4972-AC05-B22F49DEA9B6" = "NSHWFP.DLL wfp"
            "42E3CC21-098C-11D3-8C4D-00104BCA495B" = "RASMONTR.DLL aaaa"
            "44F3288B-DBFF-4B31-A86E-633F50D706B3" = "NSHHTTP.DLL http"
            "4BD827F7-1E83-462D-B893-F33A80C5DE1D" = "AUTHFWCFG.DLL mainmode"
            "4D0FEFCB-8C3E-4CDE-B39B-325933727297" = "AUTHFWCFG.DLL monitor"
            "500F32FD-7064-476B-8FD6-2171EA46428F" = "NETIOHLP.DLL ipv6"
            "555EA58E-72B1-4F0A-9055-779D0F5400B2" = "PEERDISTSH.DLL smb"
            "592852F7-5F6F-470B-9097-C5D33B612975" = "RPCNSH.DLL rpc"
            "6DC31EC5-3583-4901-9E28-37C28113656A" = "DHCPCMONITOR.DLL dhcpclient"
            "6EC05238-F6A3-4801-967A-5C9D6F6CAC50" = "P2PNETSH.DLL peer"
            "725588AC-7A11-4220-A121-C92C915E8B73" = "NETIOHLP.DLL ipv4"
            "78197B47-2BEF-49CA-ACEB-D8816371BAA8" = "NETIOHLP.DLL tcp"
            "8A6D23B3-0AF2-4101-BC6E-8114B325FE17" = "NETIOHLP.DLL dnsclient"
            "8B3A0D7F-1F30-4402-B753-C4B2C7607C97" = "FWCFG.DLL firewall"
            "90E1CBE1-01D9-4174-BB4D-EB97F3F6150D" = "NETIOHLP.DLL 6to4, isatap"
            "90FE6CFC-B6A2-463B-AA12-25E615EC3C66" = "RASMONTR.DLL diagnostics"
            "931852E2-597D-40B9-B927-55FFC81A6104" = "NETIOHLP.DLL netio"
            "97C192DB-A774-43E6-BE78-1FABD795EEAB" = "NETIOHLP.DLL httpstunnel"
            "9AA625FC-7E31-4679-B5B5-DFC67A3510AB" = "P2PNETSH.DLL database"
            "9E0D63D6-4644-476B-9DAC-D64F96E01376" = "P2PNETSH.DLL pnrp"
            "A31CB05A-1213-4F4E-B420-0EE908B896CB" = "PEERDISTSH.DLL branchcache"
            "AD1D76C9-434B-48E0-9D2C-31FA93D9635A" = "P2PNETSH.DLL diagnostics"
            "B2C0EEF4-CCE5-4F55-934E-ABF60F3DCF56" = "WSHELPER.DLL winsock"
            "B341E8BA-13AA-4E08-8CF1-A6F2D8B0C229" = "NETIOHLP.DLL namespace"
            "B7BE4347-E851-4EEC-BC65-B0C0E87B86E3" = "P2PNETSH.DLL p2p"
            "C07E293F-9531-4426-8E5C-D7EBBA50F693" = "RPCNSH.DLL filter"
            "D424E730-1DB7-4287-8C9B-0774F5AD0576" = "WLANCFG.DLL wlan"
            "E35A9D1F-61E8-4CF5-A46C-0F715A9303B8" = "P2PNETSH.DLL group"
            "F7E0BC27-BA6E-4145-A123-012F1922F3F1" = "NSHIPSEC.DLL ipsec, static, dynamic"
            "FB10CBCA-5430-46CE-B732-079B4E23BE24" = "AUTHFWCFG.DLL consec"
            "FBFC037E-D455-4B8D-80A5-B379002DBCAD" = "P2PNETSH.DLL idmgr"
        }

        # @EricRZimmerman's GUIDs shared here:
        # https://gist.github.com/davehull/50c09b5160dfceb5bb13#comment-1439249
        $EZGuidHT = @{
            "008CA0B1-55B4-4C56-B8A8-4DE4B299D3BE" = "Account Pictures"
            "BB64F8A7-BEE7-4E1A-AB8D-7D8273F7FDB6" = "Action Center"
            "88C6C381-2E85-11D0-94DE-444553540000" = "ActiveX Cache Folder"
            "7A979262-40CE-46FF-AEEE-7884AC3B6136" = "Add Hardware"
            "D4480A50-BA28-11D1-8E75-00C04FA31A86" = "Add Network Place"
            "D0384E7D-BAC3-4797-8F14-CBA229B392B5" = "Administrative Tools"
            "724EF170-A42D-4FEF-9F26-B60E846FBA4F" = "Administrative tools"
            "D20EA4E1-3957-11D2-A40B-0C5020524153" = "Administrative Tools"
            "F90C627B-7280-45DB-BC26-CCE7BDD620A4" = "All Tasks"
            "ED7BA470-8E54-465E-825C-99712043E01C" = "All Tasks"
            "64693913-1C21-4F30-A98F-4E52906D3B56" = "App Instance Folder"
            "A3918781-E5F2-4890-B3D9-A7E54332328C" = "Application Shortcuts"
            "C57A6066-66A3-4D91-9EB9-41532179F0A5" = "Application Suggested Locations"
            "1E87508D-89C2-42F0-8A7E-645A0F50CA58" = "Applications"
            "4234D49B-0245-4DF3-B780-3893943456E1" = "Applications"
            "9C60DE1E-E5FC-40F4-A487-460851A8D915" = "Auto Play"
            "B98A2BEA-7D42-4558-8BD1-832F41BAC6FD" = "Backup And Restore (Backup and Restore Center)"
            "335A31DD-F04B-4D76-A925-D6B47CF360DF" = "Backup and Restore Center"
            "0142E4D0-FB7A-11DC-BA4A-000FFE7AB428" = "Biometric Devices(Biometrics)"
            "28803F59-3A75-4058-995F-4EE5503B023C" = "Bluetooth Devices"
            "85BBD920-42A0-1069-A2E4-08002B30309D" = "Briefcase"
            "0CD7A5C0-9F37-11CE-AE65-08002B2E1262" = "Cabinet File"
            "AB5FB87B-7CE2-4F83-915D-550846C9537B" = "Camera Roll"
            "767E6811-49CB-4273-87C2-20F355E1085B" = "Camera Roll"
            "BD7A2E7B-21CB-41B2-A086-B309680C6B7E" = "Client Side Cache Folder"
            "B2C761C6-29BC-4F19-9251-E6195265BAF1" = "Color Management"
            "437FF9C0-A07F-4FA0-AF80-84B6C6440A16" = "Command Folder"
            "DE974D24-D9C6-4D3E-BF91-F4455120B917" = "Common Files"
            "F7F1ED05-9F6D-47A2-AAAE-29D317C6F066" = "Common Files"
            "6365D5A7-0F0D-45E5-87F6-0DA56B6A4F7D" = "Common Files"
            "323CA680-C24D-4099-B94D-446DD2D7249E" = "Common Places"
            "D34A6CA6-62C2-4C34-8A7C-14709C1AD938" = "Common Places FS Folder"
            "E88DCCE0-B7B3-11D1-A9F0-00AA0060FA31" = "Compressed Folder"
            "80213E82-BCFD-4C4F-8817-BB27601267A9" = "Compressed Folder (zip folder)"
            "0AC0837C-BBF8-452A-850D-79D08E667CA7" = "Computer"
            "F02C1A0D-BE21-4350-88B0-7367FC96EF3C" = "Computers and Devices"
            "3C5C43A3-9CE9-4A9B-9699-2AC0CF6CC4BF" = "Configure Wireless Network"
            "4BFEFB45-347D-4006-A5BE-AC0CB0567192" = "Conflicts"
            "38A98528-6CBF-4CA9-8DC0-B1E1D10F7B1B" = "Connect To"
            "DE2B70EC-9BF7-4A93-BD3D-243F7881D492" = "Contacts"
            "56784854-C6CB-462B-8169-88E350ACB882" = "Contacts"
            "26EE0668-A00A-44D7-9371-BEB064C98683" = "Control Panel"
            "82A74AEB-AEB4-465C-A014-D097EE346D63" = "Control Panel"
            "21EC2020-3AEA-1069-A2DD-08002B30309D" = "Control Panel"
            "5399E694-6CE5-4D6C-8FCE-1D8870FDCBA0" = "Control Panel command object for Start menu and desktop"
            "2B0F765D-C0E9-4171-908E-08A611B84FF6" = "Cookies"
            "1206F5F1-0569-412C-8FEC-3204630DFB70" = "Credential Manager"
            "E2E7934B-DCE5-43C4-9576-7FE4F75E7480" = "Date and Time"
            "B2952B16-0E07-4E5A-B993-58C52CB94CAE" = "DB Folder"
            "00C6D95F-329C-409A-81D7-C46C66EA7F33" = "Default Location"
            "17CD9488-1228-4B2F-88CE-4298E93E0966" = "Default Programs"
            "B155BDF8-02F0-451E-9A26-AE317CFD7779" = "Delegate folder that appears in Computer"
            "DFFACDC5-679F-4156-8947-C5C76BC0B67F" = "Delegate folder that appears in Users Files Folder"
            "B4BFCC3A-DB2C-424C-B029-7FE99A87C641" = "Desktop"
            "37EFD44D-EF8D-41B1-940D-96973A50E9E0" = "Desktop Gadgets"
            "C2B136E2-D50E-405C-8784-363C582BF43E" = "Device Center Initialization"
            "A8A91A66-3A7D-4424-8D24-04E180695C7A" = "Device Center(Devices and Printers)"
            "74246BFC-4C96-11D0-ABEF-0020AF6B0B7A" = "Device Manager"
            "AEE2420F-D50E-405C-8784-363C582BF45A" = "Device Pairing Folder"
            "5CE4A5E9-E4EB-479D-B89F-130C02886155" = "DeviceMetadataStore"
            "FE1290F0-CFBD-11CF-A330-00AA00C16E65" = "Directory"
            "C555438B-3C23-4769-A71F-B6D3D9B6053A" = "Display"
            "D2035EDF-75CB-4EF1-95A7-410D9EE17170" = "DLNA Content Directory Data Source"
            "289AF617-1CC3-42A6-926C-E6A863F0E3BA" = "DLNA Media Servers Data Source"
            "A8CDFF1C-4878-43BE-B5FD-F8091C1C60D0" = "Documents"
            "FDD39AD0-238F-46AF-ADB4-6C85480369C7" = "Documents"
            "7B0DB17D-9CD2-4A93-9733-46CC89022E7C" = "Documents"
            "24D89E24-2F19-4534-9DDE-6A6671FBB8FE" = "Documents"
            "7D49D726-3C21-4F05-99AA-FDC2C9474656" = "Documents folder"
            "3F98A740-839C-4AF7-8C36-5BADFB33D5FD" = "Documents library"
            "FBB3477E-C9E4-4B3B-A2BA-D3F5D3CD46F9" = "Documents Library"
            "36011842-DCCC-40FE-AA3D-6177EA401788" = "Documents Search Results"
            "374DE290-123F-4565-9164-39C4925E467B" = "Downloads"
            "8FD8B88D-30E1-4F25-AC2B-553D3D65F0EA" = "DXP"
            "D555645E-D4F8-4C29-A827-D93C859C4F2A" = "Ease of Access"
            "2559A1F5-21D7-11D4-BDAF-00C04F60B9F0" = "E-mail"
            "9113A02D-00A3-46B9-BC5F-9C04DADDD5D7" = "Enhanced Storage Data Source"
            "418C8B64-5463-461D-88E0-75E2AFA3C6FA" = "Explorer Browser Results Folder"
            "692F0339-CBAA-47E6-B5B5-3B84DB604E87" = "Extensions Manager Folder"
            "1777F761-68AD-4D8A-87BD-30B759FA33DD" = "Favorites"
            "8343457C-8703-410F-BA8B-8B026E431743" = "Feedback Tool"
            "877CA5AC-CB41-4842-9C69-9136E42D47E2" = "File Backup Index"
            "2F6CE85C-F9EE-43CA-90C7-8A9BD53A2467" = "File History Data Source"
            "6DFD7C5C-2451-11D3-A299-00C04F8EF6AF" = "Folder Options"
            "0AFACED1-E828-11D1-9187-B532F1E9575D" = "Folder Shortcut"
            "93412589-74D4-4E4E-AD0E-E0CB621440FD" = "Font Settings"
            "FD228CB7-AE11-4AE3-864C-16F3910AB8FE" = "Fonts"
            "D20EA4E1-3957-11D2-A40B-0C5020524152" = "Fonts"
            "1D2680C9-0E2A-469D-B787-065558BC7D43" = "Fusion Cache"
            "A75D362E-50FC-4FB7-AC2C-A8BEAA314493" = "Gadgets"
            "7B396E54-9EC5-4300-BE0A-2482EBAE1A26" = "Gadgets"
            "259EF4B1-E6C9-4176-B574-481532C9BCE8" = "Game Controllers"
            "DEBF2536-E1A8-4C59-B6A2-414586476AEA" = "GameExplorer"
            "054FAE61-4DD8-4787-80B6-090220C4B700" = "GameExplorer"
            "CAC52C1A-B53D-4EDC-92D7-6B2E8AC19434" = "Games"
            "B689B0D0-76D3-4CBB-87F7-585D0E0CE070" = "Games folder"
            "DA3F6866-35FE-4229-821A-26553A67FC18" = "General (Generic) library"
            "5C4F28B5-F869-4E84-8E60-F11DB97C5CC7" = "Generic (All folder items)"
            "5F4EAB9A-6833-4F61-899D-31CF46979D49" = "Generic library"
            "7FDE1A1E-8B31-49A5-93B8-6BE14CFA4943" = "Generic Search Results"
            "DE61D971-5EBC-4F02-A3A9-6C82895E5C04" = "Get Programs"
            "2559A1F1-21D7-11D4-BDAF-00C04F60B9F0" = "Help and Support"
            "5FCD4425-CA3A-48F4-A57C-B8A75C32ACB1" = "Hewlett-Packard Recovery (Protect.dll)"
            "FF393560-C2A7-11CF-BFF4-444553540000" = "History"
            "0D4C3DB6-03A3-462F-A0E6-08924C41B5D4" = "History"
            "D9DC8A3B-B784-432E-A781-5A1130A75963" = "History"
            "F6B6E965-E9B2-444B-9286-10C9152EDBC5" = "History Vault"
            "679F85CB-0220-4080-B29B-5540CC05AAB6" = "Home Folder"
            "67CA7650-96E6-4FDD-BB43-A8E774F73A57" = "Home Group Control Panel (Home Group)"
            "52528A6B-B9E3-4ADD-B60D-588C2DBA842D" = "Homegroup"
            "0907616E-F5E6-48D8-9D61-A91C3D28106D" = "Hyper-V Remote File Browsing"
            "BCB5256F-79F6-4CEE-B725-DC34E402FD46" = "ImplicitAppShortcuts"
            "87D66A43-7B11-4A28-9811-C86EE395ACF7" = "Indexing Options"
            "A0275511-0E86-4ECA-97C2-ECD8F1221D08" = "Infrared"
            "15EAE92E-F17A-4431-9F28-805E482DAFD4" = "Install New Programs"
            "A305CE99-F527-492B-8B1A-7E76FA98D6E4" = "Installed updates"
            "D450A8A1-9568-45C7-9C0E-B4F9FB4537BD" = "Installed Updates"
            "2559A1F4-21D7-11D4-BDAF-00C04F60B9F0" = "Internet"
            "871C5380-42A0-1069-A2EA-08002B30309D" = "Internet Explorer (Homepage)"
            "11016101-E366-4D22-BC06-4ADA335C892B" = "Internet Explorer History and Feeds Shell Data Source for Windows Search"
            "9A096BB5-9DC3-4D1C-8526-C3CBF991EA4E" = "Internet Explorer RSS Feeds Folder"
            "A304259D-52B8-4526-8B1A-A1D6CECC8243" = "iSCSI Initiator"
            "725BE8F7-668E-4C7B-8F90-46BDB0936430" = "Keyboard"
            "BF782CC9-5A52-4A17-806C-2A894FFEEAC5" = "Language Settings"
            "328B0346-7EAF-4BBE-A479-7CB88A095F5B" = "Layout Folder"
            "A302545D-DEFF-464B-ABE8-61C8648D939B" = "Libraries"
            "48DAF80B-E6CF-4F4E-B800-0E69D84EE384" = "Libraries"
            "1B3EA5DC-B587-4786-B4EF-BD1DC332AEAE" = "Libraries"
            "896664F7-12E1-490F-8782-C0835AFD98FC" = "Libraries delegate folder that appears in Users Files Folder"
            "A5A3563A-5755-4A6F-854E-AFA3230B199F" = "Library Folder"
            "BFB9D5E0-C6A9-404C-B2B2-AE6DB6AF4968" = "Links"
            "F1B32785-6FBA-4FCF-9D55-7B8E7F157091" = "Local"
            "A520A1A4-1780-4FF6-BD18-167343C5AF16" = "LocalLow"
            "267CF8A9-F4E3-41E6-95B1-AF881BE130FF" = "Location Folder"
            "1FA9085F-25A2-489B-85D4-86326EEDCD87" = "Manage Wireless Networks"
            "89D83576-6BD1-4C86-9454-BEB04E94C819" = "MAPI Folder"
            "BC476F4C-D9D7-4100-8D4E-E043F6DEC409" = "Microsoft Browser Architecture"
            "A5E46E3A-8849-11D1-9D8C-00C04FC99D61" = "Microsoft Browser Architecture"
            "63DA6EC0-2E98-11CF-8D82-444553540000" = "Microsoft FTP Folder"
            "98EC0E18-2098-4D44-8644-66979315A281" = "Microsoft Office Outlook"
            "BD84B380-8CA2-1069-AB1D-08000948F534" = "Microsoft Windows Font Folder"
            "87630419-6216-4FF8-A1F0-143562D16D5C" = "Mobile Broadband Profile Settings Editor"
            "5EA4F148-308C-46D7-98A9-49041B1DD468" = "Mobility Center Control Panel"
            "6C8EEC18-8D75-41B2-A177-8831D59D2D50" = "Mouse"
            "4BD8D571-6D19-48D3-BE97-422220080E43" = "Music"
            "1CF1260C-4DD0-4EBB-811F-33C572699FDE" = "Music"
            "2112AB0A-C86A-4FFE-A368-0DE96E47012E" = "Music"
            "94D6DDCC-4A68-4175-A374-BD584A510B78" = "Music"
            "3F2A72A7-99FA-4DDB-A5A8-C604EDF61D6B" = "Music Library"
            "978E0ED7-92D6-4CEC-9B59-3135B9C49CCF" = "Music library"
            "71689AC1-CC88-45D0-8A22-2943C3E7DFB3" = "Music Search Results"
            "20D04FE0-3AEA-1069-A2D8-08002B30309D" = "My Computer"
            "450D8FBA-AD25-11D0-98A8-0800361B1103" = "My Documents"
            "ED228FDF-9EA8-4870-83B1-96B02CFE0D52" = "My Games"
            "208D2C60-3AEA-1069-A2D7-08002B30309D" = "My Network Places"
            "FC9FB64A-1EB2-4CCF-AF5E-1A497A9B5C2D" = "My sharing folders"
            "D20BEEC4-5CA8-4905-AE3B-BF251EA09B53" = "Network"
            "8E908FC9-BECC-40F6-915B-F4CA0E70D03D" = "Network and Sharing Center"
            "7007ACC7-3202-11D1-AAD2-00805FC1270E" = "Network Connections"
            "992CFFA0-F557-101A-88EC-00DD010CCC48" = "Network Connections"
            "6F0CD92B-2E97-45D1-88FF-B0D186B8DEDD" = "Network Connections"
            "E7DE9B1A-7533-4556-9484-B26FB486475E" = "Network Map"
            "46137B78-0EC3-426D-8B89-FF7C3A458B5E" = "Network Neighborhood"
            "2728520D-1EC8-4C68-A551-316B684C4EA7" = "Network Setup Wizard"
            "C5ABBF53-E17F-4121-8900-86626FC2C973" = "Network Shortcuts"
            "2A00375E-224C-49DE-B8D1-440DF7EF3DDC" = "None"
            "2559A1F6-21D7-11D4-BDAF-00C04F60B9F0" = "OEM link"
            "C1BAE2D0-10DF-4334-BEDD-7AA20B227A9D" = "OEM Links"
            "EE32E446-31CA-4ABA-814F-A5EBD2FD6D5E" = "Offline Files"
            "D24F75AA-4F2B-4D07-A3C4-469B3D9030C4" = "Offline Files"
            "AFDB1F70-2A4C-11D2-9039-00C04F8EEB3E" = "Offline Files Folder"
            "A52BBA46-E9E1-435F-B3D9-28DAA648C0F6" = "OneDrive"
            "8E74D236-7F35-4720-B138-1FED0B85EA75" = "OneDrive"
            "018D5C66-4533-4307-9B53-224DE2ED1FE6" = "OneDrive"
            "5FA947B5-650A-4374-8A9A-5EFA4F126834" = "OpenDrive"
            "2C36C0AA-5812-4B87-BFD0-4CD0DFB19B39" = "Original Images"
            "B4FB3F98-C1EA-428D-A78A-D1F5659CBA93" = "Other Users Folder"
            "6785BFAC-9D2D-4BE5-B7E2-59937E8FB80A" = "Other Users Folder"
            "96AE8D84-A250-4520-95A5-A47A7E3C548B" = "Parental Controls"
            "5224F545-A443-4859-BA23-7B5A95BDC8EF" = "People Near Me"
            "78F3955E-3B90-4184-BD14-5397C15F1EFC" = "Performance Information and Tools"
            "ED834ED6-4B5A-4BFE-8F11-A626DCB6A921" = "Personalization Control Panel"
            "40419485-C444-4567-851A-2DD7BFA1684D" = "Phone and Modem"
            "F0D63F85-37EC-4097-B30D-61B4A8917118" = "Photo Stream"
            "3ADD1653-EB32-4CB0-BBD7-DFA0ABB5ACCA" = "Pictures"
            "339719B5-8C47-4894-94C2-D8F77ADD44A6" = "Pictures"
            "A990AE9F-A03B-4E80-94BC-9912D7504104" = "Pictures"
            "33E28130-4E1E-4676-835A-98395C3BC3BB" = "Pictures"
            "B3690E58-E961-423B-B687-386EBFD83239" = "Pictures folder"
            "C1F8339F-F312-4C97-B1C6-ECDF5910C5C0" = "Pictures library"
            "0B2BAAEB-0042-4DCA-AA4D-3EE8648D03E5" = "Pictures Library"
            "4DCAFE13-E6A7-4C28-BE02-CA8C2126280D" = "Pictures Search Results"
            "DE92C1C7-837F-4F69-A3BB-86E631204A23" = "Playlists"
            "0C15D503-D017-47CE-9016-7B3F978721CC" = "Portable Device Values"
            "35786D3C-B075-49B9-88DD-029876E11C01" = "Portable Devices"
            "640167B4-59B0-47A6-B335-A6B3C0695AEA" = "Portable Media Devices"
            "025A5937-A6BE-4686-A844-36FE4BEC8B6D" = "Power Options"
            "9DB7A13C-F208-4981-8353-73CC61AE2783" = "Previous Versions"
            "1723D66A-7A12-443E-88C7-05E1BFE79983" = "Previous Versions Delegate Folder"
            "A3C3D402-E56C-4033-95F7-4885E80B0111" = "Previous Versions Results Delegate Folder"
            "F8C2AB3B-17BC-41DA-9758-339D7DBF2D88" = "Previous Versions Results Folder"
            "9274BD8D-CFD1-41C3-B35E-B13F55A758F4" = "Printer Shortcuts"
            "2227A280-3AEA-1069-A2DE-08002B30309D" = "Printers"
            "76FC4E2D-D6AD-4519-A663-37BD56068185" = "Printers"
            "ED50FC29-B964-48A9-AFB3-15EBB9B97F36" = "PrintHood delegate folder"
            "FCFEECAE-EE1B-4849-AE50-685DCF7717EC" = "Problem Reports and Solutions"
            "7C5A40EF-A0FB-4BFC-874A-C0F2E0B9FA8E" = "Program Files"
            "6D809377-6AF0-444B-8957-A3773F02200E" = "Program Files"
            "905E63B6-C1BF-494E-B29C-65B732D3D21A" = "Program Files"
            "62AB5D82-FDC1-4DC3-A9DD-070D1D495D97" = "ProgramData"
            "0139D44E-6AFE-49F2-8690-3DAFCAE6FFB8" = "Programs"
            "5CD7AEE2-2219-4A67-B85D-6C9CE15660CB" = "Programs"
            "A77F5D77-2E2B-44C3-A6A2-ABA601054A51" = "Programs"
            "BCBD3057-CA5C-4622-B42D-BC56DB0AE516" = "Programs"
            "DF7266AC-9274-4867-8D55-3BD661DE872D" = "Programs and Features"
            "7B81BE6A-CE2B-4676-A29E-EB907A5126C5" = "Programs and Features"
            "7BE9D83C-A729-4D97-B5A7-1B7313C39E0A" = "Programs Folder"
            "865E5E76-AD83-4DCA-A109-50DC2113CE9A" = "Programs Folder and Fast Items"
            "8060B2E3-C9D7-4A5D-8C6B-CE8EBA111328" = "Proximity CPL"
            "DFDF76A2-C82A-4D63-906A-5644AC457385" = "Public"
            "0482AF6C-08F1-4C34-8C90-E17EC98B1E17" = "Public Account Pictures"
            "C4AA340D-F20F-4863-AFEF-F87EF2E6BA25" = "Public Desktop"
            "ED4824AF-DCE4-45A8-81E2-FC7965083634" = "Public Documents"
            "3D644C9B-1FB8-4F30-9B45-F670235F79C0" = "Public Downloads"
            "3214FAB5-9757-4298-BB61-92A9DEAA44FF" = "Public Music"
            "B6EBFB86-6907-413C-9AF7-4FC2ABF07CC5" = "Public Pictures"
            "2400183A-6185-49FB-A2D8-4A392A602BA3" = "Public Videos"
            "52A4F021-7B75-48A9-9F6B-4B87A210BC8F" = "Quick Launch"
            "5E8FC967-829A-475C-93EA-51FCE6D9FFCE" = "RealPlayer Cloud"
            "0C39A5CF-1A7A-40C8-BA74-8900E6DF5FCD" = "Recent Items"
            "AE50C081-EBD2-438A-8655-8A092E34987A" = "Recent Items"
            "4564B25E-30CD-4787-82BA-39E73A750B14" = "Recent Items Instance Folder"
            "22877A6D-37A1-461A-91B0-DBDA5AAEBC99" = "Recent Places"
            "1A6FDBA2-F42D-4358-A798-B74D745926C5" = "Recorded TV"
            "B7534046-3ECB-4C18-BE4E-64CD4CB7D6AC" = "Recycle Bin"
            "645FF040-5081-101B-9F08-00AA002F954E" = "Recycle bin"
            "62D8ED13-C9D0-4CE8-A914-47DD628FB1B0" = "Regional and Language Options"
            "863AA9FD-42DF-457B-8E4D-0DE1B8015C60" = "Remote Printers"
            "A6482830-08EB-41E2-84C1-73920C2BADB9" = "Removable Storage Devices"
            "8AD10C31-2ADB-4296-A8F7-E4701232C972" = "Resources"
            "2965E715-EB66-4719-B53F-1672673BBEFA" = "Results Folder"
            "E555AB60-153B-4D17-9F04-A5FE99FC15EC" = "Ringtones"
            "C870044B-F49E-4126-A9C3-B52A1FF411E8" = "Ringtones"
            "AAA8D5A5-F1D6-4259-BAA8-78E7EF60835E" = "RoamedTileImages"
            "3EB685DB-65F9-4CF6-A03A-E3EF65729F3D" = "Roaming"
            "00BCFC5A-ED94-4E48-96A1-3F6217F21990" = "RoamingTiles"
            "2559A1F3-21D7-11D4-BDAF-00C04F60B9F0" = "Run..."
            "B250C668-F57D-4EE1-A63C-290EE7D1AA1F" = "Sample Music"
            "C4900540-2379-4C75-844B-64E6FAF8716B" = "Sample Pictures"
            "15CA69B3-30EE-49C1-ACE1-6B5EC372AFB5" = "Sample Playlists"
            "859EAD94-2E85-48AD-A71A-0969CB56A6CD" = "Sample Videos"
            "4336A54D-038B-4685-AB02-99BB52D3FB8B" = "Samples"
            "4C5C32FF-BB9D-43B0-B5B4-2D72E54EAAA4" = "Saved Games"
            "FB0C9C8A-6C50-11D1-9F1D-0000F8757FCD" = "Scanners & Cameras"
            "00F2886F-CD64-4FC9-8EC5-30EF6CDBE8C3" = "Scanners and Cameras"
            "E211B736-43FD-11D1-9EFB-0000F8757FCD" = "Scanners and Cameras"
            "D6277990-4C6A-11CF-8D87-00AA0060F5BF" = "Scheduled Tasks"
            "B7BEDE81-DF94-4682-A7D8-57A52620B86F" = "Screenshots"
            "2559A1F0-21D7-11D4-BDAF-00C04F60B9F0" = "Search"
            "72B36E70-8700-42D6-A7F7-C9AB3323EE51" = "Search Connector Folder"
            "04731B67-D933-450A-90E6-4ACD2E9408FE" = "Search Folder"
            "9343812E-1C37-4A49-A12E-4B2D810D956B" = "Search Home"
            "190337D1-B8CA-4121-A639-6D472D16972A" = "Search Results"
            "1F4DE370-D627-11D1-BA4F-00A0C91EEDBA" = "Search Results - Computers (Computer Search Results Folder, Network Computers)"
            "E17D4FC0-5564-11D1-83F2-00A0C90DC849" = "Search Results Folder"
            "7D1D3A04-DEBB-4115-95CF-2F29DA2920DA" = "Searches"
            "D9EF8727-CAC2-4E60-809E-86F80A666C91" = "Secure Startup (BitLocker Drive Encryption)"
            "9F433B7C-5F96-4CE1-AC28-AEAA1CC04D7C" = "Security Center"
            "8983036C-27C0-404B-8F08-102D10DCFD74" = "SendTo"
            "E9950154-C418-419E-A90A-20C5287AE24B" = "Sensors"
            "96437431-5A90-4658-A77C-25478734F03E" = "Server Manager"
            "2559A1F7-21D7-11D4-BDAF-00C04F60B9F0" = "Set Program Access and Defaults"
            "59031A47-3F72-44A7-89C5-5595FE6B30EE" = "Shared Documents Folder (Users Files)"
            "E7E4BC40-E76A-11CE-A9BB-00AA004AE837" = "Shell DocObject Viewer"
            "1A9BA3A0-143A-11CF-8350-444553540000" = "Shell Favorite Folder"
            "E773F1AF-3A65-4866-857D-846FC9C4598A" = "Shell Storage Folder Viewer"
            "3080F90D-D7AD-11D9-BD98-0000947B0257" = "Show Desktop"
            "AB4F43CA-ADCD-4384-B9AF-3CECEA7D6544" = "Sitios Web"
            "69D2CF90-FC33-4FB7-9A0C-EBB0F0FCB43C" = "Slide Shows"
            "D5B1944E-DB4E-482E-B3F1-DB05827F0978" = "Softex OmniPass Encrypted Folder"
            "A5110426-177D-4E08-AB3F-785F10B4439C" = "Sony Ericsson File Manager"
            "F82DF8F7-8B9F-442E-A48C-818EA735FF9B" = "Sound"
            "58E3C745-D971-4081-9034-86E34B30836A" = "Speech Recognition Options"
            "625B53C3-AB48-4EC1-BA1F-A1EF4146FC19" = "Start Menu"
            "A4115719-D62E-491D-AA7C-E74B8BE3B067" = "Start Menu"
            "A00EE528-EBD9-48B8-944A-8942113D46AC" = "Start Menu Commanding Provider Folder"
            "48E7CAAB-B918-4E58-A94D-505519C795DC" = "Start Menu Folder"
            "98F275B4-4FFF-11E0-89E2-7B86DFD72085" = "Start Menu Launcher Provider Folder"
            "E345F35F-9397-435C-8F95-4E922C26259E" = "Start Menu Path Complete Provider Folder"
            "DAF95313-E44D-46AF-BE1B-CBACEA2C3065" = "Start Menu Provider Folder"
            "82A5EA35-D9CD-47C5-9629-E15D2F714E6E" = "Startup"
            "B97D20BB-F46A-4C97-BA10-5E3608430854" = "Startup"
            "F3F5824C-AD58-4728-AF59-A1EBE3392799" = "Sticky Notes Namespace Extension for Windows Desktop Search"
            "F942C606-0914-47AB-BE56-1321B8035096" = "Storage Spaces"
            "EDC978D6-4D53-4B2F-A265-5805674BE568" = "Stream Backed Folder"
            "F5175861-2688-11D0-9C5E-00AA00A45957" = "Subscription Folder"
            "43668BF8-C14E-49B2-97C9-747784D784B7" = "Sync Center"
            "E413D040-6788-4C22-957E-175D1C513A34" = "Sync Center Conflict Delegate Folder"
            "289978AC-A101-4341-A817-21EBA7FD046D" = "Sync Center Conflict Folder"
            "9C73F5E5-7AE7-4E32-A8E8-8D23B85255BF" = "Sync Center Folder"
            "289A9A43-BE44-4057-A41B-587A76D7E7F9" = "Sync Results"
            "BC48B32F-5910-47F5-8570-5074A8A5636A" = "Sync Results Delegate Folder"
            "71D99464-3B6B-475C-B241-E15883207529" = "Sync Results Folder"
            "0F214138-B1D3-4A90-BBA9-27CBC0C5389A" = "Sync Setup"
            "F1390A9A-A3F4-4E5D-9C5F-98F3BD8D935C" = "Sync Setup Delegate Folder"
            "2E9E59C0-B437-4981-A647-9C34B9B90891" = "Sync Setup Folder"
            "BB06C0E4-D293-4F75-8A90-CB05B6477EEE" = "System"
            "9FE63AFD-59CF-4419-9775-ABCC3849F861" = "System Recovery"
            "3F6BC534-DFA1-4AB4-AE54-EF25A74E0107" = "System Restore"
            "D65231B0-B2F1-4857-A4CE-A8E7C6EA7D27" = "System32"
            "1AC14E77-02E7-4E5D-B744-2EB1AE5198B7" = "System32"
            "80F3F1D5-FECA-45F3-BC32-752C152E456E" = "Tablet PC Settings"
            "05D7B0F4-2121-4EFF-BF6B-ED3F69B894D9" = "Taskbar (NotificationAreaIcons)"
            "0DF44EAA-FF21-4412-828E-260A8728E7F1" = "Taskbar and StartMenu"
            "7E636BFE-DFA9-4D5E-B456-D7B39851D8A9" = "Templates"
            "A63293E8-664E-48DB-A079-DF759E0509F7" = "Templates"
            "B94237E7-57AC-4347-9151-B08C6C32D1F7" = "Templates"
            "9E52AB10-F80D-49DF-ACB8-4330F5687855" = "Temporary Burn Folder"
            "7BD29E00-76C1-11CF-9DD0-00A0C9034933" = "Temporary Internet Files"
            "7BD29E01-76C1-11CF-9DD0-00A0C9034933" = "Temporary Internet Files"
            "352481E8-33BE-4251-BA85-6007CAEDCF9D" = "Temporary Internet Files"
            "D17D1D6D-CC3F-4815-8FE3-607E7D5D10B3" = "Text to Speech"
            "4D9F7874-4E0C-4904-967B-40B0D20C3E4B" = "The Internet"
            "F3CE0F7C-4901-4ACC-8648-D5D44B04EF8F" = "The user's full name"
            "9B74B6A3-0DFD-4F11-9E78-5F7800F2E772" = "The user's username (%USERNAME%)"
            "5E6C858F-0E22-4760-9AFE-EA3317B67173" = "The user's username (%USERNAME%)"
            "5B934B42-522B-4C34-BBFE-37A3EF7B9C90" = "This Device Folder"
            "82BA0782-5B7A-4569-B5D7-EC83085F08CC" = "TopViews"
            "BDBE736F-34F5-4829-ABE8-B550E65146C4" = "TopViews"
            "45C6AFA5-2C13-402F-BC5D-45CC8172EF6B" = "Toshiba Bluetooth Stack"
            "708E1662-B832-42A8-BBE1-0A77121E3908" = "Tree property value folder"
            "C58C4893-3BE0-4B45-ABB5-A63E4B8C8651" = "Troubleshooting"
            "C291A080-B400-4E34-AE3F-3D2B9637D56C" = "UNCFAT IShellFolder Class"
            "60632754-C523-4B62-B45C-4172DA012619" = "User Accounts"
            "7A9D77BD-5403-11D2-8785-2E0420524153" = "User Accounts (Users and Passwords)"
            "031E4825-7B94-4DC3-B131-E946B44C8DD5" = "User Libraries"
            "9E3995AB-1F9C-4F13-B827-48B24B6C7174" = "User Pinned"
            "1F3427C8-5C10-4210-AA03-2EE45287D668" = "User Pinned"
            "0762D272-C50A-4BB0-A382-697DCD729B80" = "Users"
            "C4D98F09-6124-4FE0-9942-826416082DA9" = "Users libraries"
            "18989B1D-99B5-455B-841C-AB7C74E4DDFC" = "Videos"
            "491E922F-5643-4AF4-A7EB-4E7A138D8174" = "Videos"
            "A0953C92-50DC-43BF-BE83-3742FED03C9C" = "Videos"
            "5FA96407-7E77-483C-AC93-691D05850DE8" = "Videos folder"
            "292108BE-88AB-4F33-9A26-7748E62E37AD" = "Videos library"
            "631958A6-AD0F-4035-A745-28AC066DC6ED" = "Videos Library"
            "EA25FBD7-3BF7-409E-B97F-3352240903F4" = "Videos Search Results"
            "B5947D7F-B489-4FDE-9E77-23780CC610D1" = "Virtual Machines"
            "BDEADF00-C265-11D0-BCED-00A0C90AB50F" = "Web Folders"
            "B28AA736-876B-46DA-B3A8-84C5E30BA492" = "Web sites"
            "CB1B7F8C-C50A-4176-B604-9E24DEE8D4D1" = "Welcome Center"
            "3080F90E-D7AD-11D9-BD98-0000947B0257" = "Window Switcher"
            "F38BF404-1D43-42F2-9305-67DE0B28FC23" = "Windows"
            "BE122A0E-4503-11DA-8BDE-F66BAD1E3F3A" = "Windows Anytime Upgrade"
            "78CB147A-98EA-4AA6-B0DF-C8681F69341C" = "Windows CardSpace"
            "D8559EB9-20C0-410E-BEDA-7ED416AECC2A" = "Windows Defender"
            "13E7F612-F261-4391-BEA2-39DF4F3FA311" = "Windows Desktop Search"
            "1F43A58C-EA28-43E6-9EC4-34574A16EBB7" = "Windows Desktop Search MAPI Namespace Extension Class"
            "67718415-C450-4F3C-BF8A-B487642DC39B" = "Windows Features"
            "4026492F-2F69-46B8-B9BF-5654FC07E423" = "Windows Firewall"
            "3E7EFB4C-FAF1-453D-89EB-56026875EF90" = "Windows Marketplace"
            "98D99750-0B8A-4C59-9151-589053683D73" = "Windows Search Service Media Center Namespace Extension Handler"
            "D426CFD0-87FC-4906-98D9-A23F5D515D61" = "Windows Search Service Outlook Express Protocol Handler"
            "2559A1F2-21D7-11D4-BDAF-00C04F60B9F0" = "Windows Security"
            "087DA31B-0DD3-4537-8E23-64A18591F88B" = "Windows Security Center"
            "E95A4861-D57A-4BE1-AD0F-35267E261739" = "Windows Side Show"
            "36EEF7DB-88AD-4E81-AD49-0E313F0C35F8" = "Windows Update"
            "ECDB0924-4208-451E-8EE0-373C0956DE16" = "Work Folders"
            "241D7C96-F8BF-4F85-B01F-E2B043341A4B" = "Workspaces Center(Remote Application and Desktop Connections)"
            "27E2E392-A111-48E0-AB0C-E17705A05F85" = "WPD Content Type Folder"
        }

        # Haven't found a static source for log provider GUIDs, but
        # the code below builds it dynamically
        $LogProviderGuidHT = @{}
        & $env:windir\system32\logman.exe query providers | ForEach-Object {
            $provider = $_
            if ($provider -match "\{") {
                $LogName, $LogGuid = ($provider -split "{") -replace "}"
                $LogName = $LogName.Trim()
                $LogGuid = $LogGuid.Trim()
                if ($LogProviderGuidHT.ContainsKey($LogGuid)) {} else {
                    $LogProviderGuidHT.Add($LogGuid, $LogName)
                }
            }
        }

        # Below came from 
        # http://stackoverflow.com/questions/25049875/getting-any-special-folder-path-in-powershell-using-folder-guid        
        if (-not ([System.Management.Automation.PSTypeName]'Shell32').Type) {
            Add-Type -ErrorAction SilentlyContinue @"
                using System;
                using System.Runtime.InteropServices;

                public class shell32 {
                    [DllImport("shell32.dll")]
                    private static extern int SHGetKnownFolderPath(
                    [MarshalAs(UnmanagedType.LPStruct)] 
                    Guid rfid,
                    uint dwFlags,
                    IntPtr hToken,
                    out IntPtr pszPath
                );

                public static string GetKnownFolderPath(Guid rfid) {
                    IntPtr pszPath;
                    if (SHGetKnownFolderPath(rfid, 0, IntPtr.Zero, out pszPath) != 0)
                        return ""; // add whatever error handling you fancy
                    string path = Marshal.PtrToStringUni(pszPath);
                    Marshal.FreeCoTaskMem(pszPath);
                    return path;
                }
            }

"@

        } # End Add-Type conditional
                    
        $Obj = "" | Select-Object GUID,Shell32,"Microsoft Documented",LogProvider,"Netsh Show Helper",EricRZimmerman

    }
    Process {

        $Obj.GUID = $GUID

        $GUID = $GUIDPattern.Match($GUID).value
        if ($HumanReadableValue = $MSWinGUIDHT[$GUID]) {
            $Obj."Microsoft Documented" = $HumanReadableValue
        } else {
            $Obj."Microsoft Documented" = "Not found."
        }

        if ($HumanReadableValue = $NetshShowHelperGUIDHT[$GUID]) {
            $Obj."Netsh Show Helper" = $HumanReadableValue
        } else {
            $Obj."Netsh Show Helper" = "Not found."
        }

        if ($HumanReadableValue = $EZGuidHT[$GUID]) {
            $Obj.EricRZimmerman = $HumanReadableValue
        } else {
            $Obj.EricRZimmerman = "Not found."
        }

        if ($HumanReadableValue = $LogProviderGuidHT[$GUID]) {
            $Obj.LogProvider = $HumanReadableValue
        } else {
            $Obj.LogProvider = "Not found."
        }

        if ($HumanReadableValue = $([Shell32]::GetKnownFolderPath($GUID))) {
            $Obj.Shell32 = $HumanReadableValue
        } else {
            $Obj.Shell32 = "Not found."
        }  
    
        $Obj
    }
    End {}