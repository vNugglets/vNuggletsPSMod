<#	.Description
	Pester tests for vNugglets.Utility PowerShell module.  Expects that:
	0) vNugglets.Utility module is already loaded (but, will try to load it if not)
	1) a connection to at least one vCenter is in place (but, will prompt for vCenter to which to connect if not)
#>

## initialize things, preparing for tests
# . $PSScriptRoot\vNugglets.Utility.TestingInit.ps1

Write-Verbose -Verbose "tests not yet fully written"

<#
Cmdlets for which to still write tests:
Copy-VNVIRole
Disconnect-VNVIServer
Get-VNNetworkClusterInfo
Get-VNUplinkNicForVM
Get-VNVMByAddress
Get-VNVMByRDM
Get-VNVMByVirtualPortGroup
Get-VNVMDiskAndRDM
Get-VNVMEVCInfo
Get-VNVMHostBrokenUplink
Get-VNVMHostFirmwareInfo
Get-VNVMHostLogicalVolumeInfo
Get-VNVMHostNICFirmwareAndDriverInfo
Invoke-VNEvacuateDatastore
Move-VNTemplateFromVMHost
Update-VNTitleBarForPowerCLI
#>

Describe -Tags "Get" -Name "Get-VNVMHostHBAWWN" {
	It "Gets VMHost HBA WWN information" {
		## the NoteProperties that the return objects should have
		$arrExpectedReturnObjNotePropertyNames = Write-Output DeviceName HBANodeWWN HBAPortWWN HBAStatus VMHostName
		$arrReturnObj = Get-VMHost -State Connected | Select-Object -First 1 | Get-VNVMHostHBAWWN
		$arrReturnTypes = $arrReturnObj | Get-Member | Select-Object -Unique -ExpandProperty TypeName
		$bGetsOnlyPSCustomObjectType = $arrReturnTypes -eq "System.Management.Automation.PSCustomObject"
		## does the array of names of NoteProperties in the set of return objects have only the values expected for return objects? (does the comparison of the arrays return no difference objects?)
		$bHasExpectedNoteProperties = $null -eq (Compare-Object -ReferenceObject $arrExpectedReturnObjNotePropertyNames -DifferenceObject ($arrReturnObj | Get-Member -MemberType NoteProperty).Name)
		$bGetsOnlyPSCustomObjectType | Should Be $true
		$bHasExpectedNoteProperties | Should Be $true
	} ## end it
} ## end describe
