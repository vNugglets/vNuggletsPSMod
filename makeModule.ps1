## some code to generate the module manifest
$strFilespecForPsd1 = "$PSScriptRoot\vNugglets.Utility\vNugglets.Utility.psd1"

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
