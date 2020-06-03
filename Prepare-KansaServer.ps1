# This script prepares a server to be used as a Kansa host. This only needs to run one 
# time per server unless its WinRM configuration is reset.

# Check that the winrm service is running, start it if it isn't running:
$svc = Get-Service winrm

if ($svc.Status -eq "Disabled"){
    Write-Warning "WinRM is disabled, please ensure that group policy is not blocking the service and try again."
    exit
}
elseif ($svc.Status -ne "Running"){
    Write-Warning "WinRM not currently running. Starting service..."
    Start-Service winrm
}
else{
    Write-Host "WinRM is running :)"
}

$svc = Get-Service winrm
if ($svc.Status -ne "Running"){
    Write-Warning "WinRM failed to start, please investigate and try again."
    exit
}

# Check to ensure that a listener exists and is enabled
$listeners = Test-Path WSMan:\localhost\Listener\Listener_*
if ($listeners){
}
else{
    Write-Warning "No valid WinRM listener found. Please configure using winrm quickconfig"
    exit
}

# Check that powershell plugin is enabled
$PSPlugin = Get-Item WSMan:\localhost\Plugin\microsoft.powershell\Enabled
if ($PSPlugin.Name -ne "Enabled"){
    Write-Warning "PowerShell WinRM plugin not enabled, enabling..."
    Register-PSSessionConfiguration -Name Microsoft.PowerShell -Force -ErrorAction SilentlyContinue
}
else{}

# Configure resource constraints for remote shells to allow heavy RAM usage
Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 10000
Set-Item WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxMemoryPerShellMB 10000

# Restart winrm service to apply changes
Stop-Service winrm
Start-Service winrm

Write-Host "`n---------------------------"
Write-Host "Complete: Server is ready for Kansa. Please ignore the above warnings."
