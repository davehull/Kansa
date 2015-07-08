<# 
.SYNOPSIS
Get-MasterFileTable.ps1 leverages the Win32 device namespace to access the raw
filesystem. This bypasses file locks, attributes, and access control lists;
enabling access to the MFT from an elevated user session.
.PARAMETER Disk
Required if Partition is passed, otherwise optional. Restricts the module to
a single phyisical disk. By default, it enumerates the MFT on all partitions on
all local disks (as provided by WMI).
.PARAMETER Partition
Optional. Restricts the module to a single partition on a single disk.
.EXAMPLE
Get-MasterFileTable.ps1

Returns a single object with all files enumerated from the MFT of all active 
NTFS partitions.
.EXAMPLE
Get-MasterFileTable.ps1 -Disk 0 -Partition 1

Returns an object with the files from the second partition of the first disk.
.NOTES
OUTPUT TSV

When passing specific modules with parameters via Kansa.ps1's -ModulePath 
parameter, be sure to quote the entire string, like shown here:
.\kansa.ps1 -ModulePath ".\Modules\Disk\Get-MasterFileTable.ps1 0,1"
#>

[CmdletBinding()]
Param(
	[Parameter(Mandatory=$true,Position=0,ParameterSetName="SinglePartition")]
	[Parameter(Mandatory=$false,Position=0,ParameterSetName="Default")]
		[ValidateScript({ 
			$filter = [String]::Format("DeviceId like '%PHYSICALDRIVE{0}'", $_.ToString())
			if ($null -ne (Get-WMIObject -Class Win32_DiskDrive -Filter $filter)) {
				$true
			}
			else {
				$msg = [String]::Format("No physical drive of index {0} on this host.", $_.ToString())
				throw $msg
			}
		})]
		[int]$Disk,
	[Parameter(Mandatory=$true,Position=1,ParameterSetName="SinglePartition")]
		[ValidateScript({ 
			# We have to have the value of DiskId to make sure we're checking the right
			# partition list, so let's pull it from the parent scope.
			[string]$myDisk = (Get-Variable -Name Disk -Scope 1).Value
			$filter = [String]::Format("DeviceId like '%PHYSICALDRIVE{0}'", $myDisk)
			if (($_ -lt (Get-WMIObject -Class Win32_DiskDrive -Filter $filter).Partitions) -and ($_ -ge 0)) {
				$true
			}
			else {
				$msg = [String]::Format("Partition index {0} is outside the valid partition range.", $_.ToString())
				throw $msg
			}
		})]
		[int]$Partition
)

BEGIN {

	function Open-RawStream {
		[CmdletBinding()]
		Param(
			[Parameter(Mandatory=$true,ValueFromPipeline=$true)]
			[string]$Path
		)

		$orig_EA = $ErrorActionPreference
		$ErrorActionPreference = "SilentlyContinue"
		Add-Type -MemberDefinition @"
[DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
public static extern SafeFileHandle CreateFileW(
	  [MarshalAs(UnmanagedType.LPWStr)] string filename,
	  [MarshalAs(UnmanagedType.U4)] FileAccess access,
	  [MarshalAs(UnmanagedType.U4)] FileShare share,
	  IntPtr securityAttributes,
	  [MarshalAs(UnmanagedType.U4)] FileMode creationDisposition,
	  [MarshalAs(UnmanagedType.U4)] FileAttributes flagsAndAttributes,
	  IntPtr templateFile);

public static FileStream OpenFileStream(string path) {
	SafeFileHandle handle = CreateFileW(path, 
										FileAccess.Read, 
										FileShare.ReadWrite, 
										IntPtr.Zero, 
										FileMode.Open, 
										FileAttributes.Normal, 
										IntPtr.Zero);

	if (handle.IsInvalid) {
		Marshal.ThrowExceptionForHR(Marshal.GetHRForLastWin32Error());
	}

	return new FileStream(handle, FileAccess.Read);
}
"@ -Name Win32 -Namespace System -UsingNamespace System.IO,Microsoft.Win32.SafeHandles
		$ErrorActionPreference = $orig_EA

		try {
			$fs = [System.Win32]::OpenFileStream($path)
			return $fs
		}
		catch {
			throw $Error[0]
		}
	}
	
	function Read-FromRawStream {
		<#
		.SYNOPSIS
		Read-FromRawStream takes a filestream object, length, and optional 
		offset, reads the desired amount of data from the stream, and returns a
		byte array.
		.PARAMETER Stream
		FileStream object as returned by Open-RawFileStream.
		.PARAMETER Length
		Number of bytes to read from FileStream. Cannot be negative.
		.PARAMETER Offset
		Optional but strongly recommended. Offset in bytes from the begining of
		FileStream where reading should start. Cannot be negative. If not 
		provided, will read from where the pointer currently rests.
		#>
		Param (
			[Parameter(Mandatory=$true, Position=0)]
				$Stream,
			[Parameter(Mandatory=$true, Position=1)]
			[ValidateScript(
				{ 
					if( $_ -ge 0 ) { $true }
					else { throw "Length parameter cannot be negative."}
				}
			)]
				[uint64]$Length,
			[Parameter(Mandatory=$false, Position=2)]
			[ValidateScript(
				{ 
					if( $_ -ge 0 ) { $true }
					else { throw "Offset parameter cannot be negative."}
				}
			)]
				[int64]$Offset = 0
		)

		# If an offset was provided, move the pointer to it. Otherwise we'll read
		# from where any previous operations left off.
		if ($MyInvocation.BoundParameters.ContainsKey("Offset")) {
			$suppress = $Stream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
		}
		
		<#
		# Make sure we're not starting/ending past the end of the stream
		# Commented out 2015-05-29 because the Length property is returning
		# null. Will have to find another way to do this.
		$StreamLen = $Stream.Length # Well, that's odd. This doesn't return anything...
		if (($Offset + $Length) -gt $StreamLen) {
			$Length = $StreamLen - $Offset
			Write-Warning "Tried to read past the end of the stream."
		}
		elseif ($Offset -gt $StreamLen) {
			Write-Warning "Tried to start reading past the end of the stream."
			return [byte[]]0x00
		}
		#>
		[byte[]]$buffer = New-Object byte[] $Length
		$suppress = $Stream.Read($buffer, 0, $Length)

		return $buffer
	}
	
	function Format-AsHex {
		<#
		.SYNOPSIS
		Foramat-AsHex takes a byte array and returns a string representing the values
		in that array in the connanical format. This is a derivitive of code released
		by Lee Holmes in his Windows PowerShell Cookbook (O'Reilly).
		#>
		Param (
			 [Parameter(Mandatory=$true, Position=0)]
				[byte[]]$Bytes,
			 [Parameter(Mandatory=$false, Position=1)] 
				[switch]$NoOffset,
			 [Parameter(Mandatory=$false, Position=2)] 
				[switch]$NoText
		)

		$placeholder = "." # What to print when byte is not a letter or digit.
		
		## Store our header, and formatting information
        $counter = 0
        $header = "            0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F"
        $nextLine = "{0}   " -f  [Convert]::ToString($counter, 16).ToUpper().PadLeft(8, '0')
        $asciiEnd = ""

        ## Output the header
        "`r`n$header`r`n"

		foreach ($byte in $bytes) {
			$nextLine += "{0:X2} " -f $byte

			if ([Char]::IsLetterOrDigit($byte) -or [Char]::IsPunctuation($byte) -or [Char]::IsSymbol($byte) ) { 
				$asciiEnd += [Char] $byte 
			}
			else {
				$asciiEnd += $placeholder 
			}

			$counter += 1

			## If we've hit the end of a line, combine the right half with the
            ## left half, and start a new line.
            if(($counter % 16) -eq 0) {
                "$nextLine $asciiEnd"
                $nextLine = "{0}   " -f [Convert]::ToString($counter, 16).ToUpper().PadLeft(8, '0')
                $asciiEnd = ""
            }
		}

		## At the end of the file, we might not have had the chance to output
        ## the end of the line yet.  Only do this if we didn't exit on the 16-byte
        ## boundary, though.
        if(($counter % 16) -ne 0) {
            while(($counter % 16) -ne 0) {
                $nextLine += "   "
                $asciiEnd += " "
                $counter++;
            }
            "$nextLine $asciiEnd"
        }

        ""
	}
	
	function Get-PartitionStats {
        Param(
            [Parameter(Mandatory=$true, Position=0, ValueFromPipeline=$true)]
                [byte[]]$PartitionEntry,
            [Parameter(Mandatory=$false, Position=1)]
                [int]$SectorSize = 0x200
        )

        <#
            Example:
                  0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F
            0x00 00 BE 13 2C 07 FE FF FF 00 F8 0A 00 B0 6D 65 74

            Offset  Length  Description
              0x00       1  Status. Active/Bootable = 0x80, Inactive = 0x00.
              0x01       3  CHS (cylinder|head|sector) address of first sector.
              0x04       1  Partition type.
              0x05       3  CHS address of last sector.
              0x08       4  LBA (logical block address) of first sector.
              0x0C       4  Size in sectors.

            All multi-byte entries are presented in little endian.

            CHS is legacy and not used by Windows 2000 and later, but included
            in the MBR for backwards compatibility.

            This would produce:
            Bootable  Type  FirstSector  Length
            --------  ----  -----------  ------
               False  NTFS  0xAF800      0x74656DB0 sectors (931 GB)
        #>

        BEGIN {  
            $PartitionTypes = @{
                "00" = "Empty";
                "05" = "Microsoft Extended";
                "07" = "NTFS";
                "82" = "Linux swap";
                "83" = "Linux";
                "84" = "Hibernation";
                "85" = "Linux Extended";
                "86" = "NTFS Volume Set";
                "87" = "NTFS Volume Set";
                "EE" = "EFI GPT Disk";
                "EF" = "EFI System Partition"
            }
        }
        PROCESS {
            $o = "" | Select-Object Bootable, Type, FirstSector, Length
            
            # Check active Partition byte
            if ($PartitionEntry[0] -eq [byte]0x80) {
                $o.Bootable = $true
            }
            else {
                $o.Bootable = $false
            }

            # Check partition type
            $PartitionTypeString = "{0:X2}" -f $PartitionEntry[4]
            if ($PartitionTypes.ContainsKey($PartitionTypeString)) {
                $o.Type = $PartitionTypes[$PartitionTypeString]
            }
            else {
                $o.Type = "0x{0}", $PartitionTypeString
            }

            # Get string representation of LBA in big endian
            $FirstSector = $PartitionEntry[8..11]
            [Array]::Reverse($FirstSector) # Convert to big endian order
            $FirstSector | % { $o.FirstSector += ("{0:X2}" -f $_)}
            $o.FirstSector = "0x" + $($o.FirstSector).TrimStart("0")

            # Get string representation of length in big endian and its value as an integer
            $LengthArr = $PartitionEntry[12..15]
            $Length = [BitConverter]::ToUInt32($PartitionEntry, 12) * $SectorSize
            [Array]::Reverse($LengthArr) # Convert to big endian order
            $LengthStr = ""
            $LengthArr | % { $LengthStr += ("{0:X2}" -f $_)}
			$LengthStrHr = ConvertTo-ReadableSize $Length
            $o.Length = "0x{0} sectors ({1:F0} {2})" -f $LengthStr.TrimStart("0"), $LengthStrHr.Value, $LengthStrHr.Label

            $o
        }
        END {  }
    }

	function Parse-StdInfoEntry {
		<#
		.SYNOPSIS
		Parse-StdInfoEntry parses an MFT STANDARD_INFORMATION entry and returns the data
		needed to build a timeline. Per the specification, this will always be resident.
		#>
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$AttributeContent,
			[Parameter(Mandatory=$false, Position=1)]
				[bool]$IsResident = $true
		)

		if ($IsResident) {
			$o = "" | Select-Object SI_Created, SI_Modified, SI_EntryModified, SI_Accessed, SI_UpdateSequenceNumber
			$o.SI_Created = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x00))
			$o.SI_Modified = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x08))
			$o.SI_EntryModified = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x10))
			$o.SI_Accessed = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x18))

		
			if ($AttributeContent.Length -ge 0x48) {
				$o.SI_UpdateSequenceNumber = [BitConverter]::ToUInt64($AttributeContent, 0x40)
				#$o.SI_UpdateSequenceNumber = $AttributeContent[0x40..0x47]
			}
			else {
				$o.SI_UpdateSequenceNumber = 0
			}

			$o
		}
		else {
			$false
		}
	}

	function Parse-FilenameEntry {
		<#
		.SYNOPSIS
		Parse-FilenameEntry parses an MFT FILE_NAME entry and returns the data
		needed to build a timeline. Per the specification, this will always be resident.
		#>
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$AttributeContent,
			[Parameter(Mandatory=$false, Position=1)]
				[bool]$IsResident = $true
		)

		if ($IsResident) {
			$o = "" | Select-Object FN_Created, FN_Modified, FN_EntryModified, FN_Accessed, FN_ParentEntry, `
									FN_ParentSeq, FN_AllocatedSize, FN_RealSize, FN_NameSpace, FN_Name

			<# 
			https://msdn.microsoft.com/en-us/library/bb470211(v=vs.85).aspx
				typedef struct _MFT_SEGMENT_REFERENCE {
					ULONG  SegmentNumberLowPart;
					USHORT SegmentNumberHighPart;
					USHORT SequenceNumber;
				} MFT_SEGMENT_REFERENCE, *PMFT_SEGMENT_REFERENCE;
			#>
			$o.FN_ParentEntry = ([BitConverter]::ToUInt16($AttributeContent, 0x04) -shl 16) + ([BitConverter]::ToUInt32($AttributeContent, 0x00))
			$o.FN_ParentSeq = [BitConverter]::ToUInt16($AttributeContent, 0x06)
			$o.FN_Created = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x08))
			$o.FN_Modified = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x10))
			$o.FN_EntryModified = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x18))
			$o.FN_Accessed = [DateTime]::FromFileTimeUtc([BitConverter]::ToUInt64($AttributeContent, 0x20))
			$o.FN_AllocatedSize = [BitConverter]::ToUInt64($AttributeContent, 0x28)
			$o.FN_RealSize = [BitConverter]::ToUint64($AttributeContent, 0x30)
			$o.FN_NameSpace = switch ([int]$AttributeContent[0x41]) {
				0 { "POSIX" }
				1 { "Win32" }
				2 { "DOS" }
				3 { "Win32 & DOS" }
				default { "Unknown" }
			}

			# Calculate the end of the name. Starts at byte 0x42, number of unicode characters
			# is recorded in byte 0x40. Count from 1, index from 0.
			[int]$FN_NameEnd = 0x42 + ($AttributeContent[0x40] * 2) - 1
			$o.FN_Name = [Text.UnicodeEncoding]::Unicode.GetString($AttributeContent[0x42..$FN_NameEnd])

			$o
		}
		else {
			$false
		}
	}

	function Parse-DataEntry {
		<#
		.SYNOPSIS
		Parse-DataEntry parses an MFT DATA entry and returns the data needed to build
		a timeline. Could be either resident or non-resident.
		#>
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$AttributeContent,
			[Parameter(Mandatory=$false, Position=1)]
				[bool]$IsResident = $false
		)

		$o = "" | Select-Object DATA_Resident, DATA_SizeAllocated, DATA_SizeActual, DATA_Runlist, `
								DATA_StreamName, DATA_ResidentData

		# Most of these values exist in the caller's scope, but for function consistency
		# and ease of processing, I don't want to pass them if they're not needed.
		$o.DATA_Resident = $IsResident
		$o.DATA_StreamName = (Get-Variable -Name AttributeName -Scope 1).Value

		if ($IsResident) {
			$o.DATA_ResidentData = Format-AsHex $AttributeContent
		}
		else {
			$o.DATA_SizeAllocated = (Get-Variable -Name AttributeSizeAllocated -Scope 1).Value
			$o.DATA_SizeActual = (Get-Variable -Name AttributeSizeActual -Scope 1).Value
			$o.DATA_Runlist = Parse-RunList $AttributeContent
		}

		$o
	}

	function Parse-RunList {
		<#
		.SYNOPSIS
		Parse-RunList takes an MFT runlist and returns the starting cluster and
		length of each entry.
		.NOTES
		Runlists are formatted such that the low nibble of the first byte is the
		number of bytes that describe the length of the run. The high nibble of
		the first byte is the number of bytes that descrbe the offset to the run.
		+------+------+------+------+------+------+------+------+------+------+
		| 0010 | 0001 |    RLEN     |                RUN OFFSET               |
		+------+------+------+------+------+------+------+------+------+------+
		
		Offsets are signed integers and relative to the offset of the previous run.
		The first offset is relative to the beginning of the volume (a logical 
		cluster number, or LCN). This means that segments of a file can occupy a
		physical position on disk that is before ones they follow logically.
	
		Runlists can have offsets of 0, but some length. This represents a "sparse"
		file; i.e. one with a virtual size larger than its physical space on disk.
		#>
	    Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$RunList
		)
		$index = 0
		$Previous_RunStart = 0
		
		$out = @()
	
		$NextEntryStart = 0
		while (($NextEntryStart -lt $RunList.Length) -and ($RunList[$NextEntryStart] -ne 0x00)) {
			#$o = "" | Select-Object Run_Index, Run_Length, Run_Start
	        $o = New-Object psobject
			[int]$RunLengthBytes = $RunList[$NextEntryStart] -band 0x0F
			[int]$RunOffsetBytes = $RunList[$NextEntryStart] -shr 4
	
			[byte[]]$RunLenPart = 
				if ($RunLengthBytes -gt 0) {
					$RLenStart = $NextEntryStart + 1
					$RLenEnd   = $RLenStart + $RunLengthBytes - 1
					$RunList[$RLenStart..$RLenEnd]
				}
				else {
					$RLenEnd = $NextEntryStart
					0x00
				}
			
			[byte[]]$RunOffPart = 
	            if ($RunOffsetBytes -gt 0) {
	                $ROffStart = $RLenEnd + 1
	        		$ROffEnd = $ROffStart + $RunOffsetBytes - 1
	                $RunList[$ROffStart..$ROffEnd]
	            }
	            else {
	                $ROffEnd = $RLenEnd
	                0x00
	            }
	
			# Convert to an 8-byte LE array so we can make it an integer. I'm
			# sure there's a better way to do this...
			while ($RunLenPart.Length -lt 8) {
				$RunLenPart += 0x00
			}
	
			# Same as above, but more complicated since this is a signed value.
			if (($RunOffPart[($RunOffPart.Length - 1)] -band 0x80) -eq 0) {
				# Positive integer, no special treatment needed
				while ($RunOffPart.Length -lt 8) {
					$RunOffPart += 0x00
				}
			}
			else {
				# Negative integer, must preserve that
				while ($RunOffPart.Length -lt 8) {
					$RunOffPart += 0xFF
				}
			}
	
			$RunLength = [BitConverter]::ToUInt64($RunLenPart, 0)
			$RunOffset = [BitConverter]::ToInt64($RunOffPart, 0)
	        $RunOffset = 
	            if($RunOffset -ne 0) {
	                $Previous_RunStart += $RunOffset
	                $Previous_RunStart
	            } 
	            else {
	                0x00
	                $Prevous_RunStart = $Previous_RunStart
	            }
	
			$o | Add-Member -MemberType NoteProperty -Name Run_Index -Value $index
			$o | Add-Member -MemberType NoteProperty -Name Run_Length -Value $RunLength
			$o | Add-Member -MemberType NoteProperty -Name Run_Start -Value $RunOffset
	
			$NextEntryStart = $ROffEnd + 1
			$index += 1
			
			$out += $o
		}
	
	    return ,$out
	}

	function Parse-AttributeListEntry {
		<#
		.SYNOPSIS
		Parse-AttributeListEntry parses an MFT attribute list entry and returns
		the data needed to find other attributes if the MFT data spans more
		than one record.
	
		Type is defined here: https://msdn.microsoft.com/en-us/library/bb470038(v=vs.85).aspx
		#>
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$AttributeContent,
			[Parameter(Mandatory=$false, Position=1)]
				[bool]$IsResident = $true
		)
	
		$out = @()
		$NextAttributeStart = 0
	
		while ($NextAttributeStart -lt $AttributeContent.Length) {
			$o = New-Object psobject
			$o | Add-Member -MemberType NoteProperty -Name AttributeTypeCode -Value ([BitConverter]::ToUInt32($AttributeContent, $NextAttributeStart))
			$o | Add-Member -MemberType NoteProperty -Name AttributeTypeName -Value ""
	        $o | Add-Member -MemberType NoteProperty -Name AttributeId -Value ($AttributeContent[($NextAttributeStart + 0x18)])
			$o | Add-Member -MemberType NoteProperty -Name StartingVcn -Value ([BitConverter]::ToUInt64($AttributeContent, $NextAttributeStart + 0x08))
			$o | Add-Member -MemberType NoteProperty -Name AttributeFileReferenceNumber -Value (([BitConverter]::ToUInt16($AttributeContent, $NextAttributeStart + 0x14) -shl 16) + ([BitConverter]::ToUInt32($AttributeContent, $NextAttributeStart + 0x10)))
			$o | Add-Member -MemberType NoteProperty -Name AttributeFRNSequenceNumber -Value ([BitConverter]::ToUInt16($AttributeContent, 0x16))
			$o | Add-Member -MemberType NoteProperty -Name AttributeName -Value ""
						
			[int]$NameLength = $AttributeContent[($NextAttributeStart + 0x06)]
			[int]$NameOffset = $AttributeContent[($NextAttributeStart + 0x07)]
	
			if ($NameLength -gt 0) {
				$o.AttributeName = [System.Text.UnicodeEncoding]::Unicode.GetString($AttributeContent[$NameOffset..($NameOffset + $NameLength)])
			}
	
	        $o.AttributeTypeName = 
	            switch ($o.AttributeTypeCode) {
			        0x10 { "STANDARD_INFORMATION" }
			        0X20 { "ATTRIBUTE_LIST" }
			        0X30 { "FILE_NAME" }
			        0X40 { "OBJECT_ID" }
			        0X60 { "VOLUME_NAME" }
			        0X70 { "VOLUME_INFORMATION" }
			        0X80 { "DATA" }
			        0X90 { "INDEX_ROOT" }
			        0XA0 { "INDEX_ALLOCATION" }
			        0XB0 { "BITMAP" }
			        0XCO { "REPARSE_POINT" }
			        DEFAULT { "Undefined" }
				}
	
			$EntryLength = [BitConverter]::ToUInt16($AttributeContent, $NextAttributeStart + 0x04)
			$NextAttributeStart += $EntryLength
			$out += $o
		}
		
		return ,$out	
	}

	function Parse-ObjectIdEntry {
		<#
		.SYNOPSIS
		Parse-ObjectIdEntry parses an MFT obeject id entry and returns the data 
		needed to enhance the creation of timeline entries. If defined, usually
		only one of the possible four ids is populated.
		#>
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$AttributeContent,
			[Parameter(Mandatory=$false, Position=1)]
				[bool]$IsResident = $true
		)
	
		function Get-Guid {
	        Param(
	            [byte[]]$guid
	        )
	
	        $newGuid = New-Object Guid (,$guid)
	        $newGuid.ToString()
	    }
	
	    $o = New-Object psobject
		switch ($AttributeContent.Length) {
			{$_ -ge 16} { $o | Add-Member -MemberType NoteProperty -Name ObjectId -Value (Get-Guid $AttributeContent[0x00..0x0F])}
			{$_ -ge 32} { $o | Add-Member -MemberType NoteProperty -Name BirthVolumeId -Value (Get-Guid $AttributeContent[0x10..0x1F])}
			{$_ -ge 48} { $o | Add-Member -MemberType NoteProperty -Name BirthObjectId -Value (Get-Guid $AttributeContent[0x20..0x2F])}
			{$_ -eq 64} { $o | Add-Member -MemberType NoteProperty -Name BirthDomainId -Value (Get-Guid $AttributeContent[0x30..0x3F])}
			default { return $false }
		}
	
		$o
	}
    
	function Parse-MftRecord {
		<#
		.SYNOPSIS
		Parse-MftRecord takes a byte array representing a single record from 
		the NFTS Master File Table and returns a parsed object.
		#>
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				[byte[]]$MftRecord,
			[Parameter(Mandatory=$false, Position=1)]
				[int]$SectorSize = 0x200
		)

		# Constants and Signature values
		[byte[]]$FILE_SIG = 0x46, 0x49, 0x4C, 0x45
		[byte[]]$INDX_SIG = 0x49, 0x4E, 0x44, 0x58
		[byte[]]$EOF_SIG  = 0xFF, 0xFF, 0xFF, 0xFF
		[byte[]]$NULL_BYTE = 0x00
		
		# The object we'll return
		$ParsedMftRecord = New-Object psobject

		# All values are stored in little endian format
		# Determine which type of record this is and parse it correctly.
		if ($null -eq (Compare-Object $MftRecord[0x00..0x03] $FILE_SIG)) {
			# MFT file record header
			$FixupOffset = [BitConverter]::ToUInt16($MftRecord, 0x4)
			$FixupEntries = [BitConverter]::ToUInt16($MftRecord, 0x06)
			$LogSequenceNumber = [BitConverter]::ToUInt64($MftRecord, 0x08)
			$SequenceValue = [BitConverter]::ToUInt16($MftRecord, 0x10)
			$LinkCount = [BitConverter]::ToUInt16($MftRecord, 0x12)
			$NextAttributeOffset = [BitConverter]::ToUInt16($MftRecord, 0x14)
			$Flags = [BitConverter]::ToUint16($MftRecord, 0x16)
			$EntrySizeUsed = [BitConverter]::ToUInt32($MftRecord, 0x18)
			$EntrySizeAllocated = [BitConverter]::ToUInt32($MftRecord, 0x1C)
			$BaseRecordReference = $MftRecord[0x20..27] # If not all zeroes, then this is an extended entry
			$NextAttributeId = [BitConverter]::ToUInt16($MftRecord, 0x28)

			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name LogSequenceNumber -Value $LogSequenceNumber
			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name SequenceValue -Value $SequenceValue
			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name LinkCount -Value $LinkCount
			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name Flags -Value $Flags
			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name EntrySizeUsed -Value $EntrySizeUsed
			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name EntrySizeAllocated -Value $EntrySizeAllocated
			$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name BaseRecordReference -Value $BaseRecordReference

			# Apply the fixup entries
			if ($FixupEntries -gt 0) {
				$FixupSignature = $MftRecord[$FixupOffset..($FixupOffset + 1)]
				for ($i = 1; $i -lt $FixupEntries; $i++) {
					$SourceOffset = $FixupOffset + (2 * $i)
					$TargetOffset = ($SectorSize * $i) - 2
					$FixupEntry = $MftRecord[$SourceOffset..($SourceOffset + 1)]
					# Check that the targets match the fixup signature. If not, this record is corrupt.
					if ($null -eq (Compare-Object $MftRecord[$TargetOffset..($TargetOffset + 1)] $FixupSignature)) {
						$MftRecord[$TargetOffset] = $FixupEntry[0]
						$MftRecord[($TargetOffset + 1)] = $FixupEntry[1]
					}
					else {
						# Record is corrupt, stop processing it and return boolean $False.
						# It is the responsiblity of the caller to handle it as appropriate for their use case.
						return $False
					}
				}
			}

			# While the next attribute id isn't the EOF marker, process the attribute.
			# Don't want an endless loop, either, so set a hard upper limit of the size
			# of the entry.
			while (
				($null -ne (Compare-Object ($AttributeTypeId = $MftRecord[$NextAttributeOffset..($NextAttributeOffset + 0x03)]) $EOF_SIG)) `
				-and ($NextAttributeOffset -lt $EntrySizeUsed)
			) {
				# First 16 bytes are the general header, applicable for both resident and
				# non-resident entries.
				$AttributeLength = [BitConverter]::ToUInt32($MftRecord, ($NextAttributeOffset + 0x04))
				$AttributeResident = $null -eq (Compare-Object $MftRecord[($NextAttributeOffset + 0x08)] $NULL_BYTE) # True if 0x00 (resident), False if 0x01 or anything else (non-resident)
				[int]$AttributeNameLength = $MftRecord[($NextAttributeOffset + 0x09)] * 2 # Stores the number of unicode characters in the name, so actual length is twice its value.
				$AttributeNameOffset = [BitConverter]::ToUInt16($MftRecord, ($NextAttributeOffset + 0x0A))
				$AttributeFlags = $MftRecord[($NextAttributeOffset + 0x0C)..($NextAttributeOffset + 0x0D)]
				$AttributeId = [BitConverter]::ToUInt16($MftRecord, ($NextAttributeOffset + 0x0E))

				if ($AttributeNameLength -gt 0) {
					$AttributeNameStart = $NextAttributeOffset + $AttributeNameOffset
					$AttributeNameEnd = $AttributeNameStart + $AttributeNameLength - 1 # Count from 1, index from 0
					$AttributeName = [Text.UnicodeEncoding]::Unicode.GetString($MftRecord[$AttributeNameStart..$AttributeNameEnd])
				}
				else {
					$AttributeName = $null
				}

				# Here's where processing gets kinda funky...
				if ($AttributeResident) {
					$AttributeContentSize = [BitConverter]::ToUInt32($MftRecord, ($NextAttributeOffset + 0x10))
					$AttributeContentOffset = [BitConverter]::ToUInt16($MftRecord, ($NextAttributeOffset + 0x14))
					$AttributeContentStart = $NextAttributeOffset + $AttributeContentOffset
					$AttributeContent = $MftRecord[($AttributeContentStart)..($AttributeContentStart + $AttributeContentSize -1)] # Count from 1, index from 0
				}
				else {
				    $AttributeStartingVcn = $MftRecord[($NextAttributeOffset + 0x10)..($NextAttributeOffset + 0x17)]
					$AttributeEndingVcn = $MftRecord[($NextAttributeOffset + 0x18)..($NextAttributeOffset + 0x1F)]
					$AttributeRunlistOffset = [BitConverter]::ToUInt16($MftRecord, ($NextAttributeOffset + 0x20))
					$AttributeCompressionUnitSize = [BitConverter]::ToUInt16($MftRecord, ($NextAttributeOffset + 0x22))
					$AttributeSizeAllocated = [BitConverter]::ToUInt64($MftRecord, ($NextAttributeOffset + 0x28))
					$AttributeSizeActual = [BitConverter]::ToUInt64($MftRecord, ($NextAttributeOffset + 0x30))
					$AttributeSizeInit = [BitConverter]::ToUInt64($MftRecord, ($NextAttributeOffset + 0x38))

					$AttributeRunlistStart = $NextAttributeOffset + $AttributeRunlistOffset
					$AttributeRunlistEnd = $NextAttributeOffset + $AttributeLength - 1 # Count from 1, index from 0
					$AttributeContent = $MftRecord[$AttributeRunlistStart..$AttributeRunlistEnd]
				}

				# Okay, we have the attribute metatdata and data separated; let's get to processing the actual data.
				# Attribute type values are here: https://msdn.microsoft.com/en-us/library/bb470038(v=vs.85).aspx
				# This has to be handled somehow...Need to return one "MFT Entry" object per FN attribute.
				$AttributeType = [BitConverter]::ToUInt32($AttributeTypeId, 0x00)
				switch ($AttributeType)  {
					0x10 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name StdInfoEntry -Value (Parse-StdInfoEntry $AttributeContent $AttributeResident) }
					# Has a bug, I'm not using the output yet, and I'm out of time to find and fix it. Disabling for now to get rid of the error messages.
					#0x20 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name AttributeListEntry -Value (Parse-AttributeListEntry $AttributeContent $AttributeResident) }
					0x30 { 
						$FNEntry = Parse-FilenameEntry $AttributeContent $AttributeResident
						if ($null -eq $ParsedMftRecord.FilenameEntries) {
							$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name FilenameEntries -Value @(,$FNEntry) 
						}
						else {
							$ParsedMftRecord.FilenameEntries += $FNEntry
						}
					}
					0x40 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name ObjectIdEntry -Value (Parse-ObjectIdEntry $AttributeContent $AttributeResident) }
					#0x50 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name SecurityDesciptorEntry -Value (Parse-SecurityDescriptorEntry $AttributeContent $AttributeResident) }
					#0x60 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name VolumeNameEntry -Value (Parse-VolumeNameEntry $AttributeContent $AttributeResident) }
					#0x70 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name VolumeInfoEntry -Value (Parse-VolumeInfoEntry $AttributeContent $AttributeResident) }
					0x80 { 
						$DataEntry = Parse-DataEntry $AttributeContent $AttributeResident
						if ($null -eq $ParsedMftRecord.DataEntry) {
							$ParsedMftRecord | Add-Member -MemberType NoteProperty -Name DataEntry -Value @(,$DataEntry) 
						}
						else {
							$ParsedMftRecord.DataEntry += $DataEntry
						} 
					}
					#0x90 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name IndexRootEntry -Value (Parse-IndexRootEntry $AttributeContent $AttributeResident) }
					#0xA0 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name IndexAllocationEntry -Value (Parse-IndexAllocationEntry $AttributeContent $AttributeResident) }
					#0xB0 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name BitmapEntry -Value (Parse-BitmapEntry $AttributeContent $AttributeResident) }
					#0xC0 { $ParsedMftRecord | Add-Member -MemberType NoteProperty -Name ReparsePointEntry -Value (Parse-ReparsePointEntry $AttributeContent $AttributeResident) }
					#default { Write-Verbose ("MFT Entry contained attribute type 0x{0:X}, which is not yet supported" -f $AttributeType) }
					default { }
				}
				
				# Move the offset pointer forward and start again.
				$NextAttributeOffset = $NextAttributeOffset + $AttributeLength
			}

			# Return the parsed MFT record as one object per Filename entry.
			# If there are multiple Data entries, return them all on the main
			# FN record only.
			$first_fn = $true
			foreach ($FilenameEntry in $ParsedMftRecord.FilenameEntries) {
				# Copy the original object to make sure we're getting everything
				$out = $ParsedMftRecord.PsObject.Copy()

				# Replace the multi-enty Filename property with the single value
				$out.FilenameEntries = $FilenameEntry

				if ($($ParsedMftRecord.DataEntry).Count -gt 1) {
					if ($first_fn) {
						$first_fn = $false # Flip our flag so we don't come in here again
						foreach ($DataEntry in $ParsedMftRecord.DataEntry) {
							$out_data = $out.PsObject.Copy()
							$out_data.DataEntry = $DataEntry

							$out_data
						}
						# Make sure we only output once
						continue
					}
					else {
						$out.DataEntry = $out.DataEntry[0]
					}
					
				}

				$out
			}
		}
	}
	
	function ConvertTo-ReadableSize {
		Param(
			[Parameter(Mandatory=$true, Position=0)]
				$Value
		)
		$labels = @("bytes","KB","MB","GB","TB","PB")
		$runs = 0

		while ((($temp = ($Value / 1024)) -ge 1) -and (($runs + 1) -lt $labels.Count)) {
			$runs += 1
			$Value = $temp
		}

		$o = "" | Select-Object Value, Label
		$o.Value = $Value
		$o.Label = $labels[$runs]
		$o
	}

	if (($MyInvocation.BoundParameters).ContainsKey("Disk")) { 
		$DiskDeviceIds = @(,[String]::Format("\\.\PHYSICALDRIVE{0}", $Disk))
	}
	else {
		$DiskDeviceIds = Get-WmiObject -Class Win32_DiskDrive | Select-Object -ExpandProperty DeviceID
	}

	# Setup some constants
	[byte[]]$MBR_SIG = 0x55, 0xAA
	[byte[]]$NTFS_SIG = 0x4E, 0x54, 0x46, 0x53, 0x20, 0x20, 0x20, 0x20
    [byte[]]$EmptyEntry = 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00
}

<#
  Foreach disk:
	Read partition table from MBR
    Foreach partition:
      Verify partition is NTFS
      Get $boot location from boot sector
	    Get $MFT location from $boot
		Read $MFT entry about self to get length, # of entries, data runs, etc.
		Parse the rest of it

	$diskRawStream = .\Open-RawStream.ps1 -Path "\\.\PHYSICALDRIVE0"
	[byte[]]$buffer = New-Object byte[] 0x200
	$diskRawStream.Read($buffer, 0, $buffer.Length)
	$buffer | Format-Hex

				0  1  2  3  4  5  6  7  8  9  A  B  C  D  E  F

	00000000   33 C0 8E D0 BC 00 7C 8E C0 8E D8 BE 00 7C BF 00
	00000010   06 B9 00 02 FC F3 A4 50 68 1C 06 CB FB B9 04 00
	00000020   BD BE 07 80 7E 00 00 7C 0B 0F 85 0E 01 83 C5 10
	00000030   E2 F1 CD 18 88 56 00 55 C6 46 11 05 C6 46 10 00
	00000040   B4 41 BB AA 55 CD 13 5D 72 0F 81 FB 55 AA 75 09
	00000050   F7 C1 01 00 74 03 FE 46 10 66 60 80 7E 10 00 74
	00000060   26 66 68 00 00 00 00 66 FF 76 08 68 00 00 68 00
	00000070   7C 68 01 00 68 10 00 B4 42 8A 56 00 8B F4 CD 13
	00000080   9F 83 C4 10 9E EB 14 B8 01 02 BB 00 7C 8A 56 00
	00000090   8A 76 01 8A 4E 02 8A 6E 03 CD 13 66 61 73 1C FE 
	000000A0   4E 11 75 0C 80 7E 00 80 0F 84 8A 00 B2 80 EB 84
	000000B0   55 32 E4 8A 56 00 CD 13 5D EB 9E 81 3E FE 7D 55
	000000C0   AA 75 6E FF 76 00 E8 8D 00 75 17 FA B0 D1 E6 64
	000000D0   E8 83 00 B0 DF E6 60 E8 7C 00 B0 FF E6 64 E8 75
	000000E0   00 FB B8 00 BB CD 1A 66 23 C0 75 3B 66 81 FB 54
	000000F0   43 50 41 75 32 81 F9 02 01 72 2C 66 68 07 BB 00
	00000100   00 66 68 00 02 00 00 66 68 08 00 00 00 66 53 66
	00000110   53 66 55 66 68 00 00 00 00 66 68 00 7C 00 00 66
	00000120   61 68 00 00 07 CD 1A 5A 32 F6 EA 00 7C 00 00 CD
	00000130   18 A0 B7 07 EB 08 A0 B6 07 EB 03 A0 B5 07 32 E4
	00000140   05 00 07 8B F0 AC 3C 00 74 09 BB 07 00 B4 0E CD
	00000150   10 EB F2 F4 EB FD 2B C9 E4 64 EB 00 24 02 E0 F8
	00000160   24 02 C3 49 6E 76 61 6C 69 64 20 70 61 72 74 69
	00000170   74 69 6F 6E 20 74 61 62 6C 65 00 45 72 72 6F 72
	00000180   20 6C 6F 61 64 69 6E 67 20 6F 70 65 72 61 74 69
	00000190   6E 67 20 73 79 73 74 65 6D 00 4D 69 73 73 69 6E
	000001A0   67 20 6F 70 65 72 61 74 69 6E 67 20 73 79 73 74
	000001B0   65 6D 00 00 00 63 7B 9A 91 E6 80 47 00 00 80 20
	000001C0   21 00 07 BE 12 2C 00 08 00 00 00 F0 0A 00 00 BE
	000001D0   13 2C 07 FE FF FF 00 F8 0A 00 B0 6D 65 74 00 00
	000001E0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
	000001F0   00 00 00 00 00 00 00 00 00 00 00 00 00 00 55 AA
#>     

PROCESS {
	foreach ($DiskDeviceId in $DiskDeviceIds) {
		Write-Verbose "Starting to process disk $DiskDeviceId"
		# Setup local scope configuration variables
		$DeviceIdFilter = [String]::Format("DeviceId = '{0}'", ($DiskDeviceId -replace '\\', '\\'))
		$DeviceWmiObject = Get-WmiObject -Class Win32_DiskDrive -Filter $DeviceIdFilter

		# Get some basic data about the disk that we'll need to locate records
		$SectorSize = $DeviceWmiObject | Select-Object -ExpandProperty BytesPerSector
		Write-Verbose ("Disk sector size is 0x{0:X} ({0}) bytes" -f $SectorSize)
	
		Write-Verbose "Grabbing first sector and analyzing master boot record."
		$RawStream = Open-RawStream -Path ($DeviceWmiObject | Select-Object -ExpandProperty Name)
		#[byte[]]$ByteBuffer = New-Object byte[] $SectorSize
		# Ensure we're at the beginning of the drive, then read the first sector.
		#$suppress = $RawStream.Seek(0, [System.IO.SeekOrigin]::Begin)
		#$suppress = $RawStream.Read($ByteBuffer, 0, $ByteBuffer.Length)
		[byte[]]$ByteBuffer = Read-FromRawStream -Stream $RawStream -Length $SectorSize -Offset 0
	
		# Validate that we have an MBR
		# Where is this signiture if $SectorSize -ne 512 bytes?
		if ($null -ne (Compare-Object $ByteBuffer[510..511] $MBR_SIG)) {
			Write-Verbose "Provided device does not have master boot record in the first sector."
			continue
		}

		# Pull out the partition entries.
		$PartitionEntries = $ByteBuffer[446..461], 
							$ByteBuffer[462..477], 
							$ByteBuffer[478..493], 
							$ByteBuffer[494..509]
		
		$PartitionCount = ($PartitionEntries | Where-Object { $null -ne (Compare-Object $_ $EmptyEntry)} ).Count
		$PartitionStats = $PartitionEntries | Get-PartitionStats
        Write-Verbose ("Found {0} partition entries.`r`n{1}" `
            -f $PartitionCount, `
            ($PartitionStats | Where-Object { $_.Type -ne "Empty" } | Format-Table -AutoSize | Out-String))

		if (($MyInvocation.BoundParameters).ContainsKey("Partition")) {
			$PartitionIds  = @(,$Partition)
		}
		else {
			$PartitionIds = @(0..($PartitionCount - 1)) # Count from 1, index from 0
		}

		foreach ($PartitionId in $PartitionIds) {
			Write-Verbose ""
			Write-Verbose "Starting to process partition entry $PartitionId."
            
            # Validate a few things
            if ((($PartitionStats[$PartitionId]).Type -ne "NTFS") -and `
				(($PartitionStats[$PartitionId]).Type -inotmatch "extended") -and `
				(($PartitionStats[$PartitionId]).Type -inotmatch "GPT")
			) {
                Write-Error ("Non-NTFS primary partition selected. Partition {0} is of type {1}." `
                    -f $PartitionId, $($PartitionStats[$PartitionId].Type))
                continue
            }
			elseif (($PartitionStats[$PartitionId]).Type -imatch "extended") {
				Write-Error ("Partition {0} is an extended partition, which is not yet supported." -f $PartitionId)
				continue
			}
			elseif (($PartitionStats[$PartitionId]).Type -imatch "GPT") { # This needs to be added ASAP
				Write-Error ("Partition entry {0} points to a GPT partition table, which is not yet supported." -f $PartitionId)
				continue
			}
			
			# Should be working with only an NTFS partition now.
			# Seek to the partition's start and read the NTFS boot sector.
			$Offset = [int](($PartitionStats[$PartitionId]).FirstSector) * $SectorSize
			#$suppress = $RawStream.Seek($Offset, [System.IO.SeekOrigin]::Begin)
			#$suppress = $RawStream.Read($ByteBuffer, 0, $ByteBuffer.Length)
			$ByteBuffer = Read-FromRawStream -Stream $RawStream -Length $SectorSize -Offset $Offset

			# Bytes 0x03 - 0x0A should be "NTFS    ", so let's make sure.
			if ($null -ne (Compare-Object $ByteBuffer[0x03..0x0A] $NTFS_SIG)) {
				Write-Error ("Sector at offset 0x{0:X} is not an NTFS boot sector." -f $Offset)
				continue
			}
            Write-Verbose ("    Verified partition entry {0} refers to an NTFS partition." -f $PartitionId)

			#$ByteBuffer | Format-Hex

			# Now we can get the relative offset to the MFT.
			$PartitionBytesPerSector = [BitConverter]::ToUInt16($ByteBuffer, 0x0B)
			[int]$PartitionSectorsPerCluster = $ByteBuffer[0x0D]
			Write-Verbose ("    Partition has {0} bytes per sector and {1} sectors per cluster." -f $PartitionBytesPerSector, $PartitionSectorsPerCluster)
			
			$MftLogicalClusterNumber = [BitConverter]::ToUInt64($ByteBuffer, 0x30)
			$MftLogicalOffset = $PartitionBytesPerSector * $PartitionSectorsPerCluster * $MftLogicalClusterNumber
			Write-Verbose ("    MFT is 0x{0:X} ({0}) bytes into the partition." -f $MftLogicalOffset)

			# File record size is recorded as a signed byte. If possitive, it 
			# represents the number of clusters for the data structure. If not,
			# the structure is 2^x where x is the absolute value of the byte.
			[int]$SizeOfFileRecord = $ByteBuffer[0x40]
			if ($SizeOfFileRecord -ge 0x80) {
				$SizeOfFileRecord = [Math]::Pow(2, (($SizeOfFileRecord -bxor 0xFF) + 1)) # Two's compliment.
			}
			else {
				$SizeOfFileRecord = $SizeOfFileRecord * $PartitionSectorsPerCluster * $PartitionBytesPerSector
			}
			Write-Verbose ("    MFT file records are 0x{0:X} ({0}) bytes long." -f [int]$SizeOfFileRecord)

			# Index record size is recorded the same way as file record size.
			[int]$SizeOfIndexRecord = $ByteBuffer[0x44]
			if ($SizeOfIndexRecord -ge 0x80) {
				$SizeOfIndexRecord = [Math]::Pow(2, (($SizeOfIndexRecord -bxor 0xFF) + 1)) # Two's compliment.
			}
			else {
				$SizeOfIndexRecord = $SizeOfIndexRecord * $PartitionSectorsPerCluster * $PartitionBytesPerSector
			}
			Write-Verbose ("    MFT index records are 0x{0:X} ({0}) bytes long." -f [int]$SizeOfIndexRecord)

			# Seek to the start of the MFT and parse its self-referential first entry.
			#[byte[]]$FileRecordByteBuffer = New-Object byte[] $SizeOfFileRecord
			#$suppress = $RawStream.Seek(($Offset + $MftLogicalOffset), [System.IO.SeekOrigin]::Begin)
			#$suppress = $RawStream.Read($FileRecordByteBuffer, 0, $FileRecordByteBuffer.Length)
			[byte[]]$FileRecordByteBuffer = Read-FromRawStream -Stream $RawStream -Length $SizeOfFileRecord -Offset ($Offset + $MftLogicalOffset)

			#$FileRecordByteBuffer | Format-Hex
			Write-Verbose "    Parsing the MFT's self-referential entry."
			$MftMetadata = Parse-MftRecord $FileRecordByteBuffer

			foreach ($DataRun in $MftMetadata.DataEntry.DATA_Runlist) { 
				# Something is returning two empty entries at the begining of 
				# the object, but I can't find it. Hack to get around it.
				if ($DataRun.Run_Index -ge 0) {
					# $DataRun.Run_Length = number of clusters in run
					# $DataRun.Run_Start  = begining of data as number of clusters from start of partition
					# $RunStart = physical offset to start of run in bytes
					$RunIndex = $DataRun.Run_Index
					$RunLength = $DataRun.Run_Length * $PartitionBytesPerSector * $PartitionSectorsPerCluster
					$RunStart = $Offset + ($DataRun.Run_Start * $PartitionBytesPerSector * $PartitionSectorsPerCluster)
					$RunEnd   = $RunStart + $RunLength
					$RunPointer = $RunStart
					
					# To get logical file offset (so we can calculate the MFT 
					# entry number robustly), need to know: what run we are in;
					# how long all previous runs are; how far in to this run 
					# we are.
					$RunFileOffset = ((
						$MftMetadata.DataEntry.DATA_Runlist | `
						Where-Object { $_.Run_Index -in (0..$RunIndex) } | `
						Select-Object -ExpandProperty Run_Length | `
						Measure-Object -Sum
					).Sum * $PartitionBytesPerSector * $PartitionSectorsPerCluster) - $RunLength
					# Write-Verbose ("Current run's logical file offset: {0}" -f $RunFileOffset)

					#$i = 0
					#while ($RunPointer -lt $RunEnd -and $i -le 5) {
					while ($RunPointer -lt $RunEnd) {
						# Calculate this entry's number
						$EntryNumber = ($RunFileOffset + ($RunPointer - $RunStart)) / $SizeOfFileRecord
							
						if ($MftAttributes = Parse-MftRecord (Read-FromRawStream -Stream $RawStream -Length $SizeOfFileRecord -Offset $RunPointer)) {
							foreach ($MftAttribute in $MftAttributes) {
								# Picking an output format that makes sense to me.
								# FUTURE WORK: Add support for fls/mactime/l2t formats.
								$OutputRecord = New-Object psobject -Property ([ordered]@{
									'Device' = $DiskDeviceId;
									'Partition' = $PartitionId;
									'Entry Number' = $EntryNumber; 
									'Sequence Number' = $MftAttribute.SequenceValue;
									'File Name' = $MftAttribute.FilenameEntries.FN_Name;
									'Active' = (($MftAttribute.Flags -band 1) -gt 0).ToString();
									'Link Count' = $MftAttribute.LinkCount;
									'Entry Type' = if(($MftAttribute.Flags -band 2) -eq 0) { 'File' } else { 'Directory' };
									'Log Sequence Number' = ('{0:D}' -f $MftAttribute.LogSequenceNumber);
									'StdInfo: Modified' = ('{0:s}' -f $MftAttribute.StdInfoEntry.SI_Modified); # m in macb
									'StdInfo: Accessed' = ('{0:s}' -f $MftAttribute.StdInfoEntry.SI_Accessed); # a in macb
									'StdInfo: Entry Modified' = ('{0:s}' -f $MftAttribute.StdInfoEntry.SI_EntryModified); # c in macb
									'StdInfo: Created' = ('{0:s}' -f $MftAttribute.StdInfoEntry.SI_Created); # b in macb
									'StdInfo: USN' = ('{0:D}' -f $MftAttribute.StdInfoEntry.SI_UpdateSequenceNumber);
									'Filename: Modified' = ('{0:s}' -f $MftAttribute.FilenameEntries.FN_Modified); # m in macb
									'Filename: Accessed' = ('{0:s}' -f $MftAttribute.FilenameEntries.FN_Accessed); # a in macb
									'Filename: Entry Modified' = ('{0:s}' -f $MftAttribute.FilenameEntries.FN_EntryModified); # c in macb
									'Filename: Created' = ('{0:s}' -f $MftAttribute.FilenameEntries.FN_Created); # b in macb
									'Filename: Namespace' = $MftAttribute.FilenameEntries.FN_NameSpace;
									'Filename: Parent Entry' = ('{0:D}' -f $MftAttribute.FilenameEntries.FN_ParentEntry);
									'Filename: Parent Sequence Number' = ('{0:D}' -f $MftAttribute.FilenameEntries.FN_ParentSeq);
									'Filename: Actual Size' = ('{0:D}' -f $MftAttribute.FilenameEntries.FN_RealSize);
									'Filename: Allocated Size' = ('{0:D}' -f $MftAttribute.FilenameEntries.FN_AllocatedSize);
									'Data: Resident' = $MftAttribute.DataEntry.DATA_Resident;
									'Data: Actual Size' = ('{0:D}' -f $MftAttribute.DataEntry.DATA_SizeActual);
									'Data: Allocated Size' = ('{0:D}' -f $MftAttribute.DataEntry.DATA_SizeAllocated);
									'Data: Stream Name' = $MftAttribute.DataEntry.DATA_StreamName;
									'Data: Resident Data' = ($MftAttribute.DataEntry.DATA_ResidentData | Out-String).Trim();
									'Data: Data Runs' = ($MftAttribute.DataEntry.DATA_Runlist | Format-Table -AutoSize | Out-String).Trim()
								})

								$OutputRecord
							}
						}

						#$i += 1
						$RunPointer += $SizeOfFileRecord
					}
				}
			}
		}
	}
}

END {
	# Close the raw disk stream
	$RawStream.Close()
}