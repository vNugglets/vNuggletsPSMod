## dot-source the config items file
#. $PSScriptRoot\configItems.ps1

## export these items for use by consumer
Export-ModuleMember -Function Get-VNNetworkClusterInfo, Get-VNVMByAddress, Get-VNVMEVCInfo, Get-VNVMHostBrokenUplink, Get-VNVMHostHBAWWN, Move-VNTemplateFromVMHost
