<#	.Description
	Pester tests for vNugglets.Utility PowerShell module.  Will expect that (once fully written):
	0) vNugglets.Utility module is already loaded (but, will try to load it if not)
	1) a connection to at least one vCenter is in place (but, will prompt for vCenter to which to connect if not)
#>

## initialize things, preparing for tests
. $PSScriptRoot\vNugglets.Utility.TestingInit.ps1

Write-Verbose -Verbose "tests not yet fully written"

$oTestVMHost = Get-VMHost -State Connected | Select-Object -First 1

## array of objects, each with information about what and how to test for the given cmdlet; used to create, for each cmdlet, the actual tests below
$arrInfoOnCmdletsToTest = @(
	New-Object -Type PSObject -Property @{
		CmdletName = "Get-VNVMHostFirmwareInfo"
		TestDescription = "Gets VMHost physical server's firmware information (HP-focused)"
		ExpectedReturnTypename = "System.Management.Automation.PSCustomObject"
		ExpectedReturnObjNotePropertyNames = Write-Output HPSmartArray iLOFirmware Model SystemBIOS VMHostName
		TestScriptblock = {$oTestVMHost | Get-VNVMHostFirmwareInfo}
	}
	New-Object -Type PSObject -Property @{
		CmdletName = "Get-VNVMHostHBAWWN"
		TestDescription = "Gets VMHost HBA WWN information"
		ExpectedReturnTypename = "System.Management.Automation.PSCustomObject"
		ExpectedReturnObjNotePropertyNames = Write-Output DeviceName HBANodeWWN HBAPortWWN HBAStatus VMHostName
		TestScriptblock = {$oTestVMHost | Get-VNVMHostHBAWWN}
	}
	New-Object -Type PSObject -Property @{
		CmdletName = "Get-VNVMHostLogicalVolumeInfo"
		TestDescription = "Gets VMHost's logical volume information"
		ExpectedReturnTypename = "System.Management.Automation.PSCustomObject"
		ExpectedReturnObjNotePropertyNames = Write-Output LogicalVolume VMHostName
		TestScriptblock = {$oTestVMHost | Get-VNVMHostLogicalVolumeInfo}
	}
	New-Object -Type PSObject -Property @{
		CmdletName = "Get-VNVMHostNICFirmwareAndDriverInfo"
		TestDescription = "Gets VMHost's NIC drive and firmware information"
		ExpectedReturnTypename = "System.Management.Automation.PSCustomObject"
		ExpectedReturnObjNotePropertyNames = Write-Output NicDriverVersion NicFirmwareVersion VMHostName
		TestScriptblock = {$oTestVMHost | Get-VNVMHostNICFirmwareAndDriverInfo}
	}
)

## perform the actual tests for standard Get- types of cmdlets
$arrInfoOnCmdletsToTest | Foreach-Object {
	$oInfoForThisCmdletTest = $_
	Describe -Tags "Get" -Name $oInfoForThisCmdletTest.CmdletName {
		It $oInfoForThisCmdletTest.TestDescription {
			## the NoteProperties that the return objects should have
			$arrExpectedReturnObjNotePropertyNames = $oInfoForThisCmdletTest.ExpectedReturnObjNotePropertyNames
			$arrReturnObj = & $oInfoForThisCmdletTest.TestScriptblock
			$arrReturnTypes = $arrReturnObj | Get-Member | Select-Object -Unique -ExpandProperty TypeName
			$bGetsOnlyExpectedObjectType = $arrReturnTypes -eq $oInfoForThisCmdletTest.ExpectedReturnTypename
			## does the array of names of NoteProperties in the set of return objects have only the values expected for return objects? (does the comparison of the arrays return no difference objects?)
			$bHasExpectedNoteProperties = $null -eq (Compare-Object -ReferenceObject $arrExpectedReturnObjNotePropertyNames -DifferenceObject ($arrReturnObj | Get-Member -MemberType NoteProperty).Name)
			$bGetsOnlyExpectedObjectType | Should Be $true
			$bHasExpectedNoteProperties | Should Be $true
		} ## end it
	} ## end describe
} ## end foreach-object