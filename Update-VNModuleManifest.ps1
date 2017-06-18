<#	.Description
	Some code to help automate the updating of the ModuleManifest file
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param()
begin {
	## some code to generate the module manifest
	$strFilespecForPsd1 = "$PSScriptRoot\vNugglets.Utility\vNugglets.Utility.psd1"

	$hshModManifestParams = @{
		# Confirm = $true
		Path = $strFilespecForPsd1
		ModuleVersion = "1.2.0"
		Description = "Module with the super useful functions that were previously scattered about the web by the vNugglets team (particularly, at vNugglets.com)"
		## some aliases, both as written, and with "VN" prefixed on them
		AliasesToExport = Write-Output ConnVIServer DisconnVIServer | Foreach-Object {$_; "VN$_"}
		FileList = Write-Output vNugglets.Utility.psd1 vNuggletsUtilityMod.psm1 vNuggletsUtilityMod_functions.ps1, vNugglets_SupportingFunctions.ps1, en-US\about_vNugglets.Utility.help.txt
		FunctionsToExport = Write-Output Connect-VNVIServer Copy-VNVIRole Disconnect-VNVIServer Find-VNVMWithDuplicateMACAddress Get-VNNetworkClusterInfo Get-VNUplinkNicForVM Get-VNVMByAddress Get-VNVMByRDM Get-VNVMByVirtualPortGroup Get-VNVMDiskAndRDM Get-VNVMEVCInfo Get-VNVMHostBrokenUplink Get-VNVMHostFirmwareInfo Get-VNVMHostHBAWWN Get-VNVMHostLogicalVolumeInfo Get-VNVMHostNICFirmwareAndDriverInfo Invoke-VNEvacuateDatastore Move-VNTemplateFromVMHost Update-VNTitleBarForPowerCLI
		IconUri = "http://static.vnugglets.com/imgs/vNuggletsLogo.jpg"
		LicenseUri = "https://github.com/vNugglets/vNuggletsPSMod/blob/master/License"
		NestedModules = Write-Output vNuggletsUtilityMod_functions.ps1 vNugglets_SupportingFunctions.ps1
		# PassThru = $true
		ProjectUri = "https://github.com/vNugglets/vNuggletsPSMod"
		ReleaseNotes = "See release notes at https://github.com/vNugglets/vNuggletsPSMod/blob/master/ChangeLog.md"
		## relies on a centrally-important VMware PowerCLI module
		RequiredModules = "VMware.VimAutomation.Core"
		Tags = Write-Output vNugglets vNugglets.com "VMware vSphere" FaF PowerCLI VIRole "MAC Address" VM RDM vPG "Virtual Portgroup" EVC VMHost HBA Datastore
		# Verbose = $true
	} ## end hashtable
} ## end begin

process {
	if ($PsCmdlet.ShouldProcess($strFilespecForPsd1, "Update module manifest")) {
		## do the actual module manifest update
		PowerShellGet\Update-ModuleManifest @hshModManifestParams
		## replace the comment in the resulting module manifest that includes "PSGet_" prefixed to the actual module name with a line without "PSGet_" in it
		(Get-Content -Path $strFilespecForPsd1 -Raw).Replace("# Module manifest for module 'PSGet_vNugglets.Utility'", "# Module manifest for module 'vNugglets.Utility'") | Set-Content -Path $strFilespecForPsd1
	} ## end if
} ## end prcoess


<#
## used for original manifest creation
$hshModManifestParams = @{
	Path = $strFilespecForPsd1
	Author = "Matt Boren"
	CompanyName = "vNugglets.com"
	Copyright = "MIT License"
	## when setting value for DefaultCommandPrefix in module, need to account for that when setting value for Aliases anywhere (need to code those to point at what the functions _will_ be called when the DefaultCommandPrefix is applied)
	#DefaultCommandPrefix = ""
	#FormatsToProcess = "SomeModule.format.ps1xml"
	ModuleToProcess = "vNuggletsUtilityMod.psm1"
	ModuleVersion = "1.1.0"
	## scripts (.ps1) that are listed in the NestedModules key are run in the module's session state, not in the caller's session state. To run a script in the caller's session state, list the script file name in the value of the ScriptsToProcess key in the manifest
	NestedModules = @("vNuggletsUtilityMod_functions.ps1", "vNugglets_SupportingFunctions.ps1")
	PowerShellVersion = [System.Version]"4.0"
	Description = "Module with the functions that have previously been scattered about the web by the vNugglets team (particularly, at vNugglets.com"
	## specifies script (.ps1) files that run in the caller's session state when the module is imported. You can use these scripts to prepare an environment, just as you might use a login script
	# ScriptsToProcess = "New-HtmlReport_configItems.ps1"
	VariablesToExport = @()
	AliasesToExport = @()
	CmdletsToExport = @()
	FileList = Write-Output vNugglets.Utility.psd1 vNuggletsUtilityMod.psm1 vNuggletsUtilityMod_functions.ps1, vNugglets_SupportingFunctions.ps1, about_vNugglets.Utility.help.txt
	Verbose = $true
}
## using -PassThru so as to pass the generated module manifest contents to a var for later output as ASCII (instead of having a .psd1 file of default encoding, Unicode)
$oManifestOutput = New-ModuleManifest @hshModManifestParams -PassThru
## have to do in separate step, as PSD1 file is "being used by another process" -- the New-ModuleManifest cmdlet, it seems
#   in order to have this module usable (importable) via PowerShell v2, need to update the newly created .psd1 file, replacing the 'RootModule' keyword with 'ModuleToProcess'
# ($oManifestOutput -split "`n" | Foreach-Object {$_ -replace "^RootModule = ", "ModuleToProcess = "}) -join "`n" | Out-File -Verbose -FilePath $strFilespecForPsd1 -Encoding ASCII
$oManifestOutput | Out-File -Verbose $strFilespecForPsd1 -Encoding ASCII
#>
