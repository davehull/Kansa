<#
.SYNOPSIS
Get-RegistryKeyValData.ps1 retrieves the value of the provided key as
well as the last modified time of the key.

.NOTES
Next line needed by Kansa.ps1 for proper handling of this script's data
OUTPUT tsv

HKEY_LOCAL_MACHINE
HKEY_USERS
HKEY_CURRENT_USER is a subkey of HKEY_USERS
HKEY_CURRENT_CONFIG is a subkey (HKEY_LOCAL_MACHINE\SYSTEM\CurrentControlSet\Hardware Profiles\Current)
HKEY_CLASSES_ROOT is a subkey (HKEY_LOCAL_MACHINE\SOFTWARE\Classes)
#>
param(
[string]$Key
)

$Error.Clear()
$ErrorActionPreference = "SilentlyContinue"

## The following code is from
## Name: Get-RegistryKeyTimestamp
##    Author: Boe Prox
##    Version History:
##        1.0 -- Boe Prox 17 Dec 2014
##            -Initial Build
#region Create Win32 API Object
Try {
	[void][advapi32]
} 

Catch {
	#region Module Builder
	$Domain = [AppDomain]::CurrentDomain
	$DynAssembly = New-Object System.Reflection.AssemblyName('RegAssembly')
	$AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, [System.Reflection.Emit.AssemblyBuilderAccess]::Run) # Only run in memory
	$ModuleBuilder = $AssemblyBuilder.DefineDynamicModule('RegistryTimeStampModule', $False)
	#endregion Module Builder

	#region DllImport
	$TypeBuilder = $ModuleBuilder.DefineType('advapi32', 'Public, Class')

	#region RegQueryInfoKey Method
	$PInvokeMethod = $TypeBuilder.DefineMethod(
		'RegQueryInfoKey', #Method Name
		[Reflection.MethodAttributes] 'PrivateScope, Public, Static, HideBySig, PinvokeImpl', #Method Attributes
		[IntPtr], #Method Return Type
		[Type[]] @(
			[Microsoft.Win32.SafeHandles.SafeRegistryHandle], #Registry Handle
			[System.Text.StringBuilder], #Class Name
			[UInt32 ].MakeByRefType(),  #Class Length
			[UInt32], #Reserved
			[UInt32 ].MakeByRefType(), #Subkey Count
			[UInt32 ].MakeByRefType(), #Max Subkey Name Length
			[UInt32 ].MakeByRefType(), #Max Class Length
			[UInt32 ].MakeByRefType(), #Value Count
			[UInt32 ].MakeByRefType(), #Max Value Name Length
			[UInt32 ].MakeByRefType(), #Max Value Name Length
			[UInt32 ].MakeByRefType(), #Security Descriptor Size           
			[long].MakeByRefType() #LastWriteTime
		) #Method Parameters
	)

	$DllImportConstructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor(@([String]))
	$FieldArray = [Reflection.FieldInfo[]] @(       
		[Runtime.InteropServices.DllImportAttribute].GetField('EntryPoint'),
		[Runtime.InteropServices.DllImportAttribute].GetField('SetLastError')
	)

	$FieldValueArray = [Object[]] @(
		'RegQueryInfoKey', #CASE SENSITIVE!!
		$True
	)

	$SetLastErrorCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder(
		$DllImportConstructor,
		@('advapi32.dll'),
		$FieldArray,
		$FieldValueArray
	)

	$PInvokeMethod.SetCustomAttribute($SetLastErrorCustomAttribute)
	#endregion RegQueryInfoKey Method

	[void]$TypeBuilder.CreateType()
	#endregion DllImport
} ## End of Name: Get-RegistryKeyTimestamp

# Test to make sure the provide key is valid.
Try{
	# If valid, get property and set RegistryKey value
	If (test-path -Path registry::$Key) {
		Get-ItemProperty -Path Registry::$Key
		$RegistryKey = Get-Item -Path Registry::$Key

		## The following code is from
		## Name: Get-RegistryKeyTimestamp
		##		Author: Boe Prox
		##		Version History:
		##			1.0 -- Boe Prox 17 Dec 2014
		##				-Initial Build
		#region Constant Variables
		$ClassLength = 255
		[long]$TimeStamp = $null
		#endregion Constant Variables

		$ClassName = New-Object System.Text.StringBuilder $RegistryKey.Name
		$RegistryHandle = $RegistryKey.Handle
		#endregion Registry Key Data

		#region Retrieve timestamp
		$Return = [advapi32]::RegQueryInfoKey(
			$RegistryHandle,
			$ClassName,
			[ref]$ClassLength,
			$Null,
			[ref]$Null,
			[ref]$Null,
			[ref]$Null,
			[ref]$Null,
			[ref]$Null,
			[ref]$Null,
			[ref]$Null,
			[ref]$TimeStamp
		)
		Switch ($Return) {
			0 {
				#Convert High/Low date to DateTime Object
				$LastWriteTime = [datetime]::FromFileTime($TimeStamp)

				#Return object
				$Object = [pscustomobject]@{
					FullName = $RegistryKey.Name
					Name = $RegistryKey.Name -replace '.*\\(.*)','$1'
					LastWriteTime = $LastWriteTime
				}
				$Object.pstypenames.insert(0,'Microsoft.Registry.Timestamp')
				$Object
			}
			122 {
				Throw "ERROR_INSUFFICIENT_BUFFER (0x7a)"
			}
			Default {
				Throw "Error ($return) occurred"
			}
		}
		#endregion Retrieve timestamp
		## End of Name: Get-RegistryKeyTimestamp
	}
	# if not, write error message
	else {
		Write-Error -Message "Key does not exist"
	}
}

# If for some reason everything fails, write error message
Catch{
	Write-Error -Message "Unable to retrieve data from registry"
}

if ($Error) {
	# Write the $Error to the $Errorlog
    Write-Error "Get-RegistryKeyValData Error on $env:COMPUTERNAME"
    Write-Error $Error
	$Error.Clear()
}
Write-Debug "Exiting $($MyInvocation.MyCommand)" 
