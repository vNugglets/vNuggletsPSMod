## dot-source the config items file
#. $PSScriptRoot\configItems.ps1

## Set aliases; when setting value for DefaultCommandPrefix in module, need to account for that when setting value for Alias here (value needs to be of what the final function name will be with that DefaultCommandPrefix)
$hshNewAliasInfo = @{
	## Connect and Disconnect VIServer
	ConnVIServer = "Connect-VNVIServer"
	DisconnVIServer = "Disconnect-VNVIServer"
} ## end hsh
$arrAliasNamesToExport = $hshNewAliasInfo.GetEnumerator() | Foreach-Object {
	$strNameThisAlias = $_.Name; $strValueThisAlias = $_.Value
	## make aliases, both for given alias name, and one with given string prepended to alias name
	$strNameThisAlias,"VN$strNameThisAlias" | Foreach-Object {if (-not (Get-Alias -Name $_ -ErrorAction:SilentlyContinue)) {New-Alias -Name $_ -Value $strValueThisAlias; $_}}
} ## end foreach-object

## export these items for use by consumer
$hshModuleMemberParams = @{
	Function = Write-Output Connect-VNVIServer, Disconnect-VNVIServer,
		Get-VNNetworkClusterInfo, Get-VNVMByAddress, Get-VNVMEVCInfo, Get-VNVMHostBrokenUplink, Get-VNVMHostFirmwareInfo, Get-VNVMHostHBAWWN,
		Get-VNVMHostNICFirmwareAndDriverInfo, Move-VNTemplateFromVMHost, Update-VNTitleBarForPowerCLI
	Alias = $arrAliasNamesToExport
} ## end hsh

## do the actual member export
Export-ModuleMember @hshModuleMemberParams
