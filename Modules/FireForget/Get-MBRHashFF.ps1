# This module is designed to inspect the System drive's Master Boot Record (MBR) to look for possible signs of tampering to install persistence there.
# This is a low fidelity indicator, since an attacker who controls the MBR can load their malware BEFORE the operating system so they can rootkit the
# system and intercept/tamper with any requests to inspect the MBR.  But attackers make mistakes too...they may forget to cover their tracks. It might
# at least provide some interesting baseline data. In our experience, we haven't found any evil with this module, but we did identify several users 
# that purchased SSds outside of corporate channels and used unapproved drive imaging/migration software to move their data to the new/faster drives.
# The software altered the MBR enough to make it stand out from the baseline.

Function InvokeCSharp
{
    param(
        [string] $code = '',
        [string] $file = '',
        [string] $class = '',
        [string] $method = '()',
        [Object[]] $parameters = $null,
        [string[]] $reference = @(),
        [switch] $forceCompile
    )
 
    # Stores a cache of generated assemblies. If this library is dot-sourced
    # from a script, these objects go away when the script exits.
    if(-not (Test-Path Variable:\macaw.solutionsfactory.assemblycache))
    {
        ${GLOBAL:macaw.solutionsfactory.assemblycache} = @{}
    }
 
    if (($code -eq '') -and ($file -eq '')) { throw 'Neither code nor file are specified. Specify either one or the other.' }
 
    # If a source file was specified, see if it was already loaded, compiled and cached:
    if ($file -ne '')
    {
        if ($code -ne '') { throw 'Both code and file are specified. Specify either one or the other.' }
 
        # We interpret the current directory as the directory containing the calling script, instead of the currect directory of the current process.
        if ($file.StartsWith('.'))
        {
            $callingScriptFolder = Split-Path -path ((Get-Variable MyInvocation -Scope 1).Value).MyCommand.Path -Parent
            $file = Join-Path -Path $callingScriptFolder -ChildPath $file
        }
 
        # If no class name is  specified, we assume by convention that the file name is equal to the class name.
        if ($class -eq '') { $class = [System.IO.Path]::GetFileNameWithoutExtension($file) }
 
        # Use the real full path as the cache key:
        $file = [System.IO.Path]::GetFullPath((Convert-Path -path $file))
        $cacheKey = $file
    }
    else
    {
        # See if the code has already been compiled and cached
        $cacheKey = $code
    }
    if ($class -eq '') { throw 'Required parameter missing: class' }
 
    # See if the code must be (re)compiled:
    $cachedAssembly = ${macaw.solutionsfactory.assemblycache}[$cacheKey]
    if(($cachedAssembly -eq $null) -or $forceCompile)
    {
        if ($code -eq '') { $code = [System.IO.File]::ReadAllText($file) }
        Write-Verbose "Compiling C# code:`r`n$code`r`n"
 
        # Obtains an ICodeCompiler from a CodeDomProvider class.
        $provider = New-Object Microsoft.CSharp.CSharpCodeProvider 
 
        # Get the location for System.Management.Automation DLL
        $dllName = [PsObject].Assembly.Location
 
        # Configure the compiler parameters
        $compilerParameters = New-Object System.CodeDom.Compiler.CompilerParameters 
 
        $assemblies = @("System.dll", $dllName)
        $compilerParameters.ReferencedAssemblies.AddRange($assemblies)
        $compilerParameters.ReferencedAssemblies.AddRange($reference)
        $compilerParameters.IncludeDebugInformation = $true
        $compilerParameters.GenerateInMemory = $true 
 
        # Invokes compilation.
        $compilerResults = $provider.CompileAssemblyFromSource($compilerParameters, $code)
 
        # Write any errors if generated.
        if($compilerResults.Errors.Count -gt 0)
        {
            $errorLines = ""
            foreach($error in $compilerResults.Errors)
            {
                $errorLines += "`n`t" + $error.Line + ":`t" + $error.ErrorText
            }
            Write-Error $errorLines
        }
        # There were no errors.  Store the resulting assembly in the cache.
        else
        {
            ${macaw.solutionsfactory.assemblycache}[$cacheKey] = $compilerResults.CompiledAssembly
        }
 
        $cachedAssembly = ${macaw.solutionsfactory.assemblycache}[$cacheKey]
    }
 
    # Prevent type mismatch issues caused by PowerShell wrapping of managed objects in PSObject.
    # We need to explicitly unwrap those objects because otherwise the .NET reflection classes will
    # not find the constructor or method whose signature matches the specified parameters.
    # This unwrapping eliminates the need to always wrap all your parameters in @() and to explicitly
    # cast each parameter to the correct type in each call to InvokeCSharp.
    if ($parameters -ne $null)
    {
        for($i = 0; $i -lt $parameters.Length; $i++)
        {
            $parameters[$i] = [System.Management.Automation.LanguagePrimitives]::ConvertTo( `
                $parameters[$i], `
                [System.Type]::GetType($parameters[$i].GetType().FullName) `
            )
        }
    }
 
    if ($method -eq '') # We return the assembly
    {
        $result = $cachedAssembly
    }
    elseif ($method -eq '()') # We create and return a class instance
    {
        $result = $cachedAssembly.CreateInstance($class, $false, [System.Reflection.BindingFlags]::CreateInstance, $null, $parameters, $null, @())
    }
    else # We invoke the method and return the method result
    {
        $classType = $cachedAssembly.GetType($class)
 
        $parameterTypes = @()
        if ($parameters -ne $null) { foreach($p in $parameters) { $parameterTypes += $p.GetType() } }
 
        $methodInfo = $classType.GetMethod($method, [System.Type[]]$parameterTypes)
        if ($methodInfo.IsStatic)
        {
            $instance = $null
        }
        else
        {
            $instance = $cachedAssembly.CreateInstance($class, $false, [System.Reflection.BindingFlags]::CreateInstance, $null, $null, $null, @())
        }
        $result = $methodInfo.Invoke($instance, $parameters);
    }
 
    return $result
}

Function Get-Hash([Array] $Buffer, $HashType = "MD5")
{
	# Possible hash types: MD5, RIPEMD160, SHA1, SHA256, SHA384, SHA512
	$StringBuilder = New-Object System.Text.StringBuilder
	[System.Security.Cryptography.HashAlgorithm]::Create($HashType).ComputeHash($Buffer)|%{
		[Void]$StringBuilder.Append($_.ToString("x2"))
	}
	return $StringBuilder.ToString()
}

$CSharpCode = @"
	using System.Runtime.InteropServices;
	using Microsoft.Win32.SafeHandles;
	using System;
	
	public class DiskAccess
	{
		public enum EMoveMethod : uint 
        { 
            Begin = 0, 
            Current = 1, 
            End = 2 
        } 

		[DllImport("Kernel32.dll", SetLastError = true, CharSet = CharSet.Auto)] 
        static extern uint SetFilePointer( 
            [In] SafeFileHandle hFile, 
            [In] long lDistanceToMove, 
            [Out] out int lpDistanceToMoveHigh, 
            [In] EMoveMethod dwMoveMethod); 
			
		[DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)] 
		static extern SafeFileHandle CreateFile(string lpFileName, uint dwDesiredAccess, 
		    uint dwShareMode, IntPtr lpSecurityAttributes, uint dwCreationDisposition, 
		    uint dwFlagsAndAttributes, IntPtr hTemplateFile);
		  
		[DllImport("kernel32", SetLastError = true)] 
        internal extern static int ReadFile(SafeFileHandle handle, byte[] bytes, 
            int numBytesToRead, out int numBytesRead, IntPtr overlapped_MustBeZero); 
	  
		public byte[] DumpSector(string drive, double sector, int bytesPerSector) 
		{ 
			short FILE_ATTRIBUTE_NORMAL = 0x80; 
			short INVALID_HANDLE_VALUE = -1; 
			uint GENERIC_READ = 0x80000000; 
			uint GENERIC_WRITE = 0x40000000; 
			uint CREATE_NEW = 1; 
			uint CREATE_ALWAYS = 2; 
			uint OPEN_EXISTING = 3; 
			SafeFileHandle handleValue = CreateFile(drive, GENERIC_READ, 0, IntPtr.Zero, OPEN_EXISTING, 0, IntPtr.Zero); 
			if (handleValue.IsInvalid) 
			{ 
				Marshal.ThrowExceptionForHR(Marshal.GetHRForLastWin32Error()); 
			} 
			double sec = sector * bytesPerSector; 
			int size = int.Parse(bytesPerSector.ToString()); 
			byte[] buf = new byte[size]; 
			int read = 0; 
			int moveToHigh; 
			SetFilePointer(handleValue, int.Parse(sec.ToString()), out moveToHigh, EMoveMethod.Begin); 
			ReadFile(handleValue, buf, size, out read, IntPtr.Zero); 
			handleValue.Close(); 
			return buf; 
		} 
	}
"@

# Get the System Drive
$OSDrive = (Get-WmiObject Win32_DiskDrive).DeviceID

# Read the first sector (assumes it is 512 bytes)
$MBRBuffer = InvokeCSharp -code $CSharpCode -class 'DiskAccess' -method 'DumpSector' -parameters $OSDrive, 0, 512

# Create the results object
$result = @{}

# No longer hashing the entire MBR since every host is unique due to signatures and the addresses within the partition table.
# Instead, we can hash just the first 440 bytes, which is the Bootstrap code only (without the partition table).
# https://en.wikipedia.org/wiki/Master_boot_record
$MD5hash = Get-Hash $MBRBuffer[0..439] MD5
$MBRdata = [Convert]::ToBase64String($MBRBuffer)
$result.add("Hash", $MD5hash)
$result.add("MBRData", $MBRdata)

# Add the results object to the final results to process
Add-Result -hashtbl $result
