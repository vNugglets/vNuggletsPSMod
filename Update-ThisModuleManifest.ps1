<#	.Description
	Some code to help automate the updating of the ModuleManifest file (will create it if it does not yet exist, too)
#>
[CmdletBinding(SupportsShouldProcess=$true)]
param(
	## Module Version to set
	[parameter(Mandatory=$true)][System.Version]$ModuleVersion,

	## Recreate the manifest (overwrite with full, fresh copy instead of update?)
	[Switch]$Recreate
)
begin {
	$strModuleName = "vNugglets.Utility"
	$strFilespecForPsd1 = Join-Path ($strModuleFolderFilespec = "$PSScriptRoot\$strModuleName") "${strModuleName}.psd1"

	$hshManifestParams = @{
		# Confirm = $true
		Path = $strFilespecForPsd1
		ModuleVersion = $ModuleVersion
		Copyright = "MIT License"
		Description = "Module with the super useful functions that were previously scattered about the web by the vNugglets team (particularly, at vNugglets.com)"
		## some aliases, both as written, and with "VN" prefixed on them
		AliasesToExport = Write-Output ConnVIServer DisconnVIServer | Foreach-Object {$_; "VN$_"}
		FileList = Write-Output "${strModuleName}.psd1" vNuggletsUtilityMod.psm1 vNuggletsUtilityMod_functions.ps1 vNugglets_SupportingFunctions.ps1 "en-US\about_${strModuleName}.help.txt"
		FunctionsToExport = Write-Output Connect-VNVIServer Copy-VNVIRole Disconnect-VNVIServer Find-VNVMWithDuplicateMACAddress Get-VNInventoryType Get-VNNetworkClusterInfo Get-VNUplinkNicForVM Get-VNVMByAddress Get-VNVMByRDM Get-VNVMByVirtualPortGroup Get-VNVMDiskAndRDM Get-VNVMEVCInfo Get-VNVMHostBrokenUplink Get-VNVMHostFirmwareInfo Get-VNVMHostHBAWWN Get-VNVMHostLogicalVolumeInfo Get-VNVMHostNICFirmwareAndDriverInfo Invoke-VNEvacuateDatastore Move-VNTemplateFromVMHost Update-VNTitleBarForPowerCLI
		IconUri = "http://static.vnugglets.com/imgs/vNuggletsLogo.jpg"
		LicenseUri = "https://github.com/vNugglets/vNuggletsPSMod/blob/main/License"
		## scripts (.ps1) that are listed in the NestedModules key are run in the module's session state, not in the caller's session state. To run a script in the caller's session state, list the script file name in the value of the ScriptsToProcess key in the manifest; RegisterArgCompleter apparently needs to be added _after_ function definition .ps1 files are run (via NestedModules) (else, given functions are not defined, and if RegisterArgCompleter is referring to commands from module dynamically, it would not get them; that is the case if the function definitions are in a .psm1 file instead of .ps1 file, and are being defined in NestedModules)
		NestedModules = Write-Output vNuggletsUtilityMod_functions.ps1 vNugglets_SupportingFunctions.ps1
		# PassThru = $true
		PowerShellVersion = [System.Version]"5.0"
		ProjectUri = "https://github.com/vNugglets/vNuggletsPSMod"
		ReleaseNotes = "See release notes at https://github.com/vNugglets/vNuggletsPSMod/blob/main/ChangeLog.md"
		## relies on a centrally-important VMware PowerCLI module
		RequiredModules = "VMware.VimAutomation.Core"
		Tags = Write-Output vNugglets vNugglets.com VMware vSphere FaF PowerCLI VIRole MAC VM RDM vPG VirtualPortgroup EVC VMHost HBA Datastore
		# Verbose = $true
	} ## end hashtable
} ## end begin

process {
	$bManifestFileAlreadyExists = Test-Path $strFilespecForPsd1
	## check that the FileList property holds the names of all of the files in the module directory, relative to the module directory
	## the relative names of the files in the module directory (just filename for those in module directory, "subdir\filename.txt" for a file in a subdir, etc.)
	$arrRelativeNameOfFilesInModuleDirectory = Get-ChildItem $strModuleFolderFilespec -Recurse | Where-Object {-not $_.PSIsContainer} | ForEach-Object {$_.FullName.Replace($strModuleFolderFilespec, "", [System.StringComparison]::OrdinalIgnoreCase).TrimStart("\")}
	if ($arrDiffResults = (Compare-Object -ReferenceObject $hshManifestParams.FileList -DifferenceObject $arrRelativeNameOfFilesInModuleDirectory)) {Write-Error "Uh-oh -- FileList property value for making/updating module manifest and actual files present in module directory do not match. Better check that. The variance:`n$($arrDiffResults | Out-String)"} else {Write-Verbose -Verbose "Hurray, all of the files in the module directory are named in the FileList property to use for the module manifest"}
	$strMsgForShouldProcess = "{0} module manifest" -f $(if ((-not $bManifestFileAlreadyExists) -or $Recreate) {"Create"} else {"Update"})
	if ($PsCmdlet.ShouldProcess($strFilespecForPsd1, $strMsgForShouldProcess)) {
		## do the actual module manifest update
		if ((-not $bManifestFileAlreadyExists) -or $Recreate) {Microsoft.PowerShell.Core\New-ModuleManifest @hshManifestParams}
		else {PowerShellGet\Update-ModuleManifest @hshManifestParams}
		## replace the comment in the resulting module manifest that includes "PSGet_" prefixed to the actual module name with a line without "PSGet_" in it
		(Get-Content -Path $strFilespecForPsd1 -Raw).Replace("# Module manifest for module 'PSGet_$strModuleName'", "# Module manifest for module '$strModuleName'") | Set-Content -Path $strFilespecForPsd1
	} ## end if
} ## end prcoess
