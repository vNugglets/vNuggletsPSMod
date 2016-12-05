## initialization code for use by multiple *.Tests.ps1 files for testing vNugglets.Utility PowerShell module

$strNameOfModuleToTest = "vNugglets.Utility"
## if module not already loaded, try to load it (assumes that module is in PSModulePath)
if (-not ($oModuleInfo = Get-Module $strNameOfModuleToTest)) {
	$oModuleInfo = Import-Module $strNameOfModuleToTest -PassThru
	if (-not ($oModuleInfo -is [System.Management.Automation.PSModuleInfo])) {Throw "Could not load module '$strNameOfModuleToTest' -- is it available in the PSModulePath? You can manually load the module and start tests again"}
} ## end if
Write-Verbose -Verbose ("Starting testing of module '{0}' (version '{1}' from '{2}')" -f $oModuleInfo.Name, $oModuleInfo.Version, $oModuleInfo.Path)

## ensure that this session is connected to at least one vCenter server (prompt to do so if not already connected)
$oSomeVCConnection = if (-not (($global:DefaultVIServers | Measure-Object).Count -gt 0)) {
	$hshParamForConnectVIServer = @{Server = $(Read-Host -Prompt "vCenter server name to which to connect for testing")}
	ConnVIServer @hshParamForConnectVIServer
} ## end if
else {$global:DefaultVIServers[0]}
