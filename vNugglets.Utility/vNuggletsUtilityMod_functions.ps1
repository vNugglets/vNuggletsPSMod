function Get-VNNetworkClusterInfo {
<#  .Description
    Get information about the VMware HA Cluster(s) in which the given virtual network (virtual portgroup) is defined. May 2015

    .Synopsis
    Get VMware HA Cluster info for a virtual network

    .Example
    Get-VNNetworkClusterInfo 101,234
    Name           ClusterName  ClusterId           Type                                    MoRef
    ----           -----------  ---------           ----                                    -----
    my.Portgrp101  myCluster0   ClusterCom...n-c94  VMware.Vim.Network                      Network-network-3588
    my.Portgrp234  myCluster20  ClusterCom...n-c99  VMware.Vim.DistributedVirtualPortgroup  Network-network-4687

    Gets information about virtual networks whose names match the (very simple) regular expressions, "101" and "121", returning an object for each matching network with network name and cluster name/ID properties

    .Example
    Get-VNNetworkClusterInfo -LiteralName my.Portgroup0 | ft -a
    Name           ClusterName  ClusterId                          Type                MoRef
    ----           -----------  ---------                          ----                -----
    my.Portgroup0  myCluster0   ClusterComputeResource-domain-c94  VMware.Vim.Network  Network-network-3588

    Gets information about virtual networks whose names are literally "my.Portgroup0" (not matching "my.Portgroup01" or "test_myXPortgroup0" -- just a literal match only), returning an object with network name and cluster name/ID properties

    .Link
    http://vNugglets.com

    .Notes
    This code also gives a nice example of using LinkedViews in .NET View objects to most quickly/efficiently get information about related objects in the vSphere environment.

    .Inputs
    String -- network (virtual portgroup) name pattern(s) or literal name(s)

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="NameAsRegEx")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param (
        ## Name pattern of virtual network for which to get information. This is a regular expression
        [parameter(Mandatory=$true,ParameterSetName="NameAsRegEx",Position=0)][String[]]$Name,

        ## Literal name of virtual network for which to get information.  This RegEx-escapes the string and adds start/end anchors ("^" and "$") so that the only match is an exact match
        [parameter(Mandatory=$true,ParameterSetName="NameAsLiteral",Position=0)][String[]]$LiteralName
    ) ## end param

    process {
        $hshParamForNewRegExPattern = Switch ($PsCmdlet.ParameterSetName) {
            "NameAsRegEx" {@{String = $Name; EscapeAsLiteral = $false}; break}
            ## if literal, do escape as literal
            "NameAsLiteral" {@{String = $LiteralName; EscapeAsLiteral = $true}}
        } ## end switch

        ## make the actual RegEx pattern, joining all values, and escaping if strings are to be literal
        $strNetworkNameFilter = _New-RegExJoinedOrPattern @hshParamForNewRegExPattern

        Get-View -ViewType Network -Property Name,Host -Filter @{Name = $strNetworkNameFilter} | Foreach-Object {
            ## get the updated View data for the network's hosts' parent's name
            $_.UpdateViewData("Host.Parent.Name")
            New-Object -Type PSObject -Property ([ordered]@{
                Name = $_.Name
                ## the name(s) of the cluster(s) in which this network is defined
                ClusterName = $_.LinkedView.Host.LinkedView.Parent.Name | Select-Object -Unique
                ## the ID(s) of the cluster(s) in which this network is defined
                ClusterId = $_.LinkedView.Host.LinkedView.Parent.MoRef | Select-Object -Unique
                Type = ($_ | Get-Member).TypeName | Select-Object -Unique
                ## the network's MoRef (for ease of getting the exact network object subsequently)
                MoRef = $_.MoRef
            }) ## end new-object
        } ## end foreach-object
    } ## end process
} ## end function



function Get-VNVMHostBrokenUplink {
<#  .Description
    For the given VMHost(s), list all VMNICs that are connected to a virtual standard switch (vSSwitch), but that have no link

    .Example
     Get-VNVMHostBrokenUplink
    VMHost            vSwitch   BustedVmnic  BitRatePerSec
    ------            -------   -----------  -------------
    myhost03.dom.com  vSwitch0  vmnic1                   0
    myhost22.dom.com  vSwitch5  vmnic7                   0
    myhost24.dom.com  vSwitch1  vmnic3                   0

    Get information for all VMHost's vSSwitches' uplinks

    .Example
     Get-VNVMHostBrokenUplink -LiteralName myhost24.dom.com
    VMHost            vSwitch   BustedVmnic  BitRatePerSec
    ------            -------   -----------  -------------
    myhost24.dom.com  vSwitch1  vmnic3                   0

    Get information for the particular VMHost's vSSwitches' uplinks

    .Link
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="NameAsRegEx")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param (
        ## Name pattern of VMHost for which to get information. This is a regular expression. If none specified, will check all VMHosts
        [parameter(ParameterSetName="NameAsRegEx",Position=0)][String[]]$Name = ".+",

        ## Literal name of VMHost for which to get information.  This RegEx-escapes the string and adds start/end anchors ("^" and "$") so that the only match is an exact match
        [parameter(Mandatory=$true,ParameterSetName="NameAsLiteral",Position=0)][String[]]$LiteralName
    ) ## end param

    process {
        $hshParamForNewRegExPattern = Switch ($PsCmdlet.ParameterSetName) {
            "NameAsRegEx" {@{String = $Name; EscapeAsLiteral = $false}; break}
            ## if literal, do escape as literal
            "NameAsLiteral" {@{String = $LiteralName; EscapeAsLiteral = $true}}
        } ## end switch

        ## make the actual RegEx pattern, joining all values, and escaping if strings are to be literal
        $strVMHostNameFilter = _New-RegExJoinedOrPattern @hshParamForNewRegExPattern

        ## get all matching HostSystems, and for all of their vSwitches, find the Pnics that do not have a link or the link speed is 0
        Get-View -ViewType HostSystem -Property Name, Config.Network.Vswitch, Config.Network.Pnic -Filter @{"Name" = $strVMHostNameFilter} | Foreach-Object {
            $viewThisHost = $_
            Write-Verbose "working on VMHost '$($viewThisHost.Name)'"
            ## for each vSwitch (that has uplinks) on the host, check the Pnics
            $viewThisHost.Config.Network.Vswitch | Where-Object {$_.Pnic} | Foreach-Object {
                $oThisVswitch = $_
                ## for each Pnic key in this vSwitch
                $oThisVswitch.Pnic | Foreach-Object {
                    $strPnicKey = $_
                    ## get the actual Pnic, check its LinkSpeed
                    $oPnic = $viewThisHost.Config.Network.Pnic | Where-Object {$_.key -eq $strPnicKey}
                    if (($null -eq $oPnic.LinkSpeed) -or ($oPnic.LinkSpeed.SpeedMb -eq 0)) {
                        ## create a new object with some info about the Pnic
                        New-Object -Type PSObject -Property ([ordered]@{
                            VMHost = $viewThisHost.Name
                            vSwitch = $oThisVswitch.Name
                            BustedVmnic = $oPnic.Device
                            BitRatePerSec = if ($null -eq $oPnic.LinkSpeed.SpeedMb) {0} else {$oPnic.LinkSpeed.SpeedMb}
                        }) ## end new-object
                    } ## end if
                } ## end foreach-object
            } ## end foreach-object
        } ## end foreach-object
    } ## end process
} ## end fn



function Get-VNVMByAddress {
<#  .Description
    Find all VMs with a NIC that has the given MAC address or IP address (explicit or wildcard).  Get-by-MAC portion written Jul 2011.

    .Example
    Get-VNVMByAddress -MAC 00:50:56:b0:00:01
    Name     MacAddress                              MoRef
    ------   ------------                            -----
    myvm0    {00:50:56:b0:00:01,00:50:56:b0:00:18}   VirtualMachine-vm-2155

    Get VMs with given MAC address, return VM name and its MAC addresses

    .Example
    Get-VNVMByAddress -IP 10.37.31.12
    Name     IP                                         MoRef
    ------   ---                                        -----
    myvm10   {192.16.13.1, 10.37.31.12, fe80::000...}   VirtualMachine-vm-13

    Get VMs with given IP as reported by VMware Tools, return VM name and its IP addresses

    .Example
    Get-VNVMByAddress -AddressWildcard 10.0.0.*
    Name           IP                                      MoRef
    ----           --                                      -----
    myvm3          {10.0.0.20, fe80::000:5600:fe00:6007}   VirtualMachine-vm-153
    mytestVM001    10.0.0.200                              VirtualMachine-vm-162

    Use -AddressWildcard to find VMs with approximate IP

    .Link
    http://vNugglets.com

    .Notes
    Finding VMs by IP address relies on information returned from VMware Tools in the guest, so those must be installed in the guest and have been running in the guest at least recently.

    .Outputs
    Selected.VMware.Vim.VirtualMachine
#>
    [CmdletBinding(DefaultParametersetName="FindByMac")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        ## MAC address in question, if finding VM by MAC; expects address in format "00:50:56:00:00:01"
        [parameter(Mandatory=$true,ParameterSetName="FindByMac",Position=0)][string[]]$MAC,

        ## IP address in question, for finding VM by IP.  Accepts IPv4 and IPv6 addresses
        [parameter(Mandatory=$true,ParameterSetName="FindByIP",Position=0)][ValidateScript({[bool][System.Net.IPAddress]::Parse($_)})][string]$IP,

        ## wildcard string IP address (standard wildcards like "10.0.0.*"), if finding VM by approximate IP
        [parameter(Mandatory=$true,ParameterSetName="FindByIPWildcard",Position=0)][string]$AddressWildcard
    ) ## end param

    Process {
        Switch ($PsCmdlet.ParameterSetName) {
            "FindByMac" {
                ## return the some info for the VM(s) with the NIC w/ the given MAC
                Get-View -Viewtype VirtualMachine -Property Name, Config.Hardware.Device | Where-Object {$_.Config.Hardware.Device | Where-Object {($_ -is [VMware.Vim.VirtualEthernetCard]) -and ($MAC -contains $_.MacAddress)}} | Select-Object Name, @{n="MacAddress"; e={$_.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualEthernetCard]} | Foreach-Object {$_.MacAddress} | Sort-Object}}, MoRef
                break
            } ## end case
            {"FindByIp","FindByIPWildcard" -contains $_} {
                ## scriptblock to use for the Where clause in finding VMs
                $sblkFindByIP_WhereStatement = if ($PsCmdlet.ParameterSetName -eq "FindByIPWildcard") {{$_.IpAddress | Where-Object {$_ -like $AddressWildcard}}} else {{$_.IpAddress -contains $IP}}
                ## return the .Net View object(s) for the VM(s) with the NIC(s) w/ the given IP
                Get-View -Viewtype VirtualMachine -Property Name, Guest.Net | Where-Object {$_.Guest.Net | Where-Object $sblkFindByIP_WhereStatement} | Select-Object Name, @{n="IP"; e={$_.Guest.Net | Foreach-Object {$_.IpAddress} | Sort-Object}}, MoRef
            } ## end case
        } ## end switch
    } ## end process
} ## end fn



function Get-VNVMEVCInfo {
<#  .Description
    Code to get VMs' EVC mode and that of the cluster in which the VMs reside.  May 2014, Matt Boren
    .Example
    Get-VNVMEVCInfo -Cluster myCluster | ?{$_.VMEVCMode -ne $_.ClusterEVCMode}
    Name        PowerState   VMEVCMode   ClusterEVCMode   ClusterName
    ----        ----------   ---------   --------------   -----------
    myvm001     poweredOff               intel-nehalem    myCluster0
    myvm100     poweredOff               intel-nehalem    myCluster0

    Get all VMs in given clusters where the VM's EVC mode does not match the Cluster's EVC mode

    .Example
    Get-VM myVM | Get-VNVMEVCInfo
    Get the EVC info for the given VM and the cluster in which it resides

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="ByCluster")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        ## Cluster name pattern (regex) to use for getting the clusters whose VMs to get
        [parameter(ParameterSetName="ByCluster",Position=0)][string]$Cluster = ".+",

        ## Id/MoRef of VM for which to get EVC info
        [parameter(ValueFromPipelineByPropertyName=$true,ParameterSetName="ByVMId",Position=0)][Alias("Id","MoRef")][string[]]$VMId
    ) ## end param

    begin {
        $hshParamForGetVMView = @{Property = "Name","Runtime.PowerState","Summary.Runtime.MinRequiredEVCModeKey"}
        ## helper function to create a new info object
        function _New-InfoObj ([VMware.Vim.VirtualMachine]$VMView, [string]$ClusterEVCModeKey, [string]$ClusterName) {
            New-Object -Type PSObject -Property ([ordered]@{
                Name = $VMView.Name
                PowerState = $VMView.Runtime.PowerState
                VMEVCMode = $VMView.Summary.Runtime.MinRequiredEVCModeKey
                ClusterEVCMode = $ClusterEVCModeKey
                ClusterName = $ClusterName
            })
        } ## end helper fn
    } ## end begin

    process {
        ## on VirtualMachine View objects
        #.Summary.Runtime.MinRequiredEVCModeKey
        ## on ClusterComputeResource, though, not necessarily there, so needed to just get .Summary in the Get-View call
        #.Summary.CurrentEVCModeKey

        Switch ($PSCmdlet.ParameterSetName) {
            "ByCluster" {
                Get-View -ViewType ClusterComputeResource -Property Name,Summary -Filter @{"Name" = $Cluster} | Foreach-Object {
                    $viewThisCluster = $_
                    Get-View -ViewType VirtualMachine @hshParamForGetVMView -SearchRoot $viewThisCluster.MoRef | Foreach-Object {
                        _New-InfoObj -VMView $_ -ClusterEVCModeKey $viewThisCluster.Summary.CurrentEVCModeKey -ClusterName $viewThisCluster.Name
                    } ## end foreach-object
                } ## end foreach-object
                break
            } ## end case
            "ByVMId" {
                Get-View @hshParamForGetVMView -Id $VMId | Foreach-Object {
                    ## update the View data to get the cluster name and the cluster summary (which has the cluster's EVCMode)
                    $_.UpdateViewData("Runtime.Host.Parent.Name")
                    $_.Runtime.LinkedView.Host.LinkedView.Parent.UpdateViewData("Summary")
                    _New-InfoObj -VMView $_ -ClusterEVCModeKey $_.Runtime.LinkedView.Host.LinkedView.Parent.Summary.CurrentEVCModeKey -ClusterName $_.Runtime.LinkedView.Host.LinkedView.Parent.Name
                } ## end foreach-object
            } ## end case
        } ## end switch
    } ## end process
} ## end fn



function Get-VNVMHostHBAWWN {
<#  .Description
    Get the Port- and Node WWNs for HBA(s) in VMHost(s)

    .Example
    Get-VMHost myVMHost.dom.com | Get-VMHostHBAWWN
    VMHostName        DeviceName  HBAPortWWN               HBANodeWWN               HBAStatus
    ----------        ----------  ----------               ----------               ---------
    myVMHost.dom.com  vmhba2      10:00:00:00:aa:bb:cc:53  20:00:00:00:aa:bb:cc:53  online
    myVMHost.dom.com  vmhba3      10:00:00:00:aa:bb:cc:86  20:00:00:00:aa:bb:cc:86  online

    Get the HBA WWNs for host myVMHost

    .Example
    Get-Cluster mycluster | Get-VMHostHBAWWN
    Get the HBA WWNs for hosts in the cluster "mycluster"

    .Example
    Get-VMHostHBAWWN -VMHostName myvmhost.*
    Get the HBA WWNs for hosts whose name match the regular expression pattern myvmhost.*

    .Example
    Get-VMHostHBAWWN -VMHostName ^as.+
    Get the HBA WWNs for hosts whose name match the regular expression pattern ^as.+

    .Link
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        ## Name pattern of the host for which to get HBA info (treated as a RegEx pattern)
        [parameter(Mandatory=$true,ParameterSetName="SearchByHostName")][string]$VMHostName,
        ## The ID (MoRef) the host for which to get HBA info
        [parameter(Mandatory=$true,ParameterSetName="SearchByHostId",ValueFromPipelineByPropertyName=$true)][Alias("Id")][string]$VMHostId,
        ## The cluster for whose hosts to get HBA info
        [parameter(Mandatory=$true,ParameterSetName="SearchByCluster",ValueFromPipeline=$true)][VMware.VimAutomation.ViCore.Types.V1.Inventory.Cluster]$Cluster
    ) ## end param

    Process {
        ## params for the Get-View expression for getting the View objects
        $hshGetViewParams = @{
            Property = "Name", "Config.StorageDevice.HostBusAdapter"
        } ## end hashtable
        Switch ($PsCmdlet.ParameterSetName) {
            "SearchByHostId" {$hshGetViewParams["Id"] = $VMHostId; break}
            {"SearchByHostName","SearchByCluster" -contains $_} {$hshGetViewParams["ViewType"] = "HostSystem"}
            ## if host name pattern was provided, filter on it in the Get-View expression
            "SearchByHostName" {$hshGetViewParams["Filter"] = @{"Name" = $VMHostName}; break} ## end case
            ## if cluster name pattern was provided, set it as the search root for the Get-View expression
            "SearchByCluster" {$hshGetViewParams["SearchRoot"] = $Cluster.Id; break}
        } ## end switch

        Get-View @hshGetViewParams | Foreach-Object {
            $viewHost = $_
            $viewHost.Config.StorageDevice.HostBusAdapter | Where-Object {$_ -is [VMware.Vim.HostFibreChannelHba]} | Foreach-Object {
                New-Object -TypeName PSObject -Property ([ordered]@{
                    VMHostName = $viewHost.Name
                    DeviceName = $_.Device
                    HBAPortWWN = _Format-AsHexWWNString -WWN $_.PortWorldWideName
                    HBANodeWWN = _Format-AsHexWWNString -WWN $_.NodeWorldWideName
                    HBAStatus = $_.Status
                }) ## end new-object
            } ## end foreach-object
        } ## end foreach-object
    } ## end process
} ## end fn



function Move-VNTemplateFromVMHost {
<#  .Description
    Function to move (by act of marking as VM, but on a different VMHost, and then marking back as template) templates from one VMhost to the rest of the hosts in the cluster (at random, for good dispersion). Does not move any disk/config files -- leverages API calls to essentially register template as VM on a different host, then mark as template again.

    .Example
    Move-VNTemplateFromVMHost -VMHost (Get-VMHost myhost.dom.com) -DestinationCluster (Get-Cluster someOtherCluster)
    Moves templates from myhost.dom.com to random available hosts in someOtherCluster

    .Example
    Get-VMHost myhost.dom.com | Move-VNTemplateFromVMHost -Verbose
    Moves templates from myhost.dom.com to random available hosts in same cluster as myhost.dom.com

    .Link
    http://vNugglets.com

    .Outputs
    VMware.VimAutomation.Types.Template of each moved template
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([VMware.VimAutomation.Types.Template])]
    param(
        ## VMHost from which to evacuate templates
        [parameter(ValueFromPipeline=$true, Mandatory=$true)][VMware.VimAutomation.Types.VMHost]$VMHost,
        ## VMHost cluster to which to move templates; if not specified, templates will be moved to other available VMHosts in the same cluster as the source VMHost
        [VMware.VimAutomation.Types.Cluster]$DestinationCluster
    ) ## end param


    begin {
        ## name of resource pool in the cluster into which to migrate the template (name of default ResourcePool in a cluster is "Resources")
        $strDestResPoolName = "Resources"
    } ## end begin

    process {
        ## full name of VMHost from which to move templates
        $strSourceVMHostName = $VMHost.Name

        ## .NET View object of VMHost on which templates reside
        # $viewSourceVMHost = Get-View -ViewType HostSystem -Property Parent -Filter @{"Name" = [RegEx]::escape($strSourceVMHostName)}
        $viewSourceVMHost = Get-View -Id $VMHost.Id -Property Parent
        ## if some number of hosts other than 1 was found
        if (($viewSourceVMHost | Measure-Object).Count -ne 1) {Throw "Either zero or more than one VMHost View found; connected to only the vCenter in which VMHost resides? (error when getting View of VMHost)"}

        ## .NET View object of cluster in which the VMHost (and, so, templates) reside
        $viewTemplsCluster = Get-View -Id $viewSourceVMHost.Parent -Property Name
        ## the .NET View object of destination cluster to which to move templates (may be the same as source)
        $viewDestCluster = if ($PSBoundParameters.ContainsKey("DestinationCluster")) {Get-View -Property Name -Id $DestinationCluster.Id} else {$viewTemplsCluster}

        ## get the view object of the destination resource pool
        $viewDestResPool = Get-View -ViewType ResourcePool -Property Name -SearchRoot $viewDestCluster.MoRef -Filter @{"Name" = "^$strDestResPoolName$"}

        ## array of .NET View objects of templates to move
        $arrTemplViewsToMove = Get-View -ViewType VirtualMachine -Property Name -SearchRoot $viewSourceVMHost.MoRef -Filter @{"Config.Template" = "true"}
        ## array of .NET View objects of VMHosts to which to move templates
        $arrDestHostViews = Get-View -ViewType HostSystem -Property Name,Runtime.ConnectionState -SearchRoot $viewDestCluster.MoRef -Filter @{"Runtime.InMaintenanceMode" = "False"} | Where-Object {($_.Name -ne $strSourceVMHostName) -and ($_.RunTime.ConnectionState -eq "connected")}

        ## move the templates to other hosts
        $arrTemplViewsToMove | Foreach-Object {
            $viewThisTemplate = $_
            $strThisTemplateName = $viewThisTemplate.Name
            $viewDestHostSystem = $arrDestHostViews | Get-Random
            if ($PsCmdlet.ShouldProcess($strThisTemplateName, "Move template to HostSystem '$($viewDestHostSystem.Name)'")) {
                try {
                    Write-Verbose "Working on template '$strThisTemplateName' (Id '$($viewThisTemplate.MoRef.ToString())')"
                    ## MigrateVM_Task() not supported on templates (does not work), so go this route:
                    ## mark template as a VM, putting the template on a different host in the process (takes advantage of the Host param to change the Host on which the template resides in the process of marking it as a VM)
                    #   http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html?path=5_0_2_5_12_4#markAsVirtualMachine
                    $_.MarkAsVirtualMachine($viewDestResPool.MoRef, $viewDestHostSystem.MoRef)

                    ## mark VM as template again
                    #   http://pubs.vmware.com/vsphere-50/topic/com.vmware.wssdk.apiref.doc_50/vim.VirtualMachine.html?path=5_0_2_5_12_3#markAsTemplate
                    $_.MarkAsTemplate()
                    Get-Template -Id $_.MoRef
                    Write-Verbose "Moved template '$strThisTemplateName' (Id '$($viewThisTemplate.MoRef.ToString())') to VMHost '$($viewDestHostSystem.Name)'"
                } ## end try
                catch {Throw $_}
            } ## end if
        } ## end foreach-object
    } ## end template
} ## end fn
# ## real 1337 way to move them back to their original host
# <#
# $arrTemplViewsToMove | %{
#     ## MigrateVM_Task() not supported on templates (does not work), so go this route:
#     ## mark template as a VM, putting the template on a different host in the process (takes advantage of the Host param to change the Host on which the template resides in the process of marking it as a VM)
#     $_.MarkAsVirtualMachine($viewDestResPool.MoRef, $viewSourceVMHost.MoRef)

#     ## mark VM as template again
#     $_.MarkAsTemplate()
# } ## end foreach-object
# #>



function Get-VNVMHostNICFirmwareAndDriverInfo {
<#  .Description
    Function to get NIC driver and firmware information for VMHosts

    .Example
    Get-VMHost myhost0.dom.com | Get-VNVMHostNICFirmwareAndDriverInfo
    VMHostName         NicDriverVersion       NicFirmwareVersion
    ----------         ----------------       ------------------
    myhost0.dom.com    nx_nic driver 5.0.619  nx_nic device firmware 4.0.588

    Grab NIC driver- and firmware version(s) for NICs on given host

    .Example
    Get-Cluster myCluster0 | Get-VMHost | Get-VNVMHostNICFirmwareAndDriverInfo | sort VMHostName
    VMHostName         NicDriverVersion        NicFirmwareVersion
    ----------         ----------------        ------------------
    myhost0.dom.com    nx_nic driver 5.0.619   nx_nic device firmware 4.0.588
    myhost1.dom.com    nx_nic driver 5.0.619   nx_nic device firmware 4.0.588
    myhost2.dom.com    nx_nic driver 5.0.619   nx_nic device firmware 4.0.588
    ...

    Grab NIC driver- and firmware version(s) for NICs on hosts in given cluster
#>
    [CmdletBinding(DefaultParametersetName="ByVMHostName")]
    param(
        ## Name pattern(s) of VMHost(s) for which to get information
        [parameter(ParameterSetName="ByVMHostName",Mandatory=$true,Position=0)][Alias("Name")][string[]]$VMHostName,
        ## VMHost ID(s) for which to get information. Most useful when passing VMHost via pipeline
        [parameter(ParameterSetName="ByVMHostId",Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][Alias("Id", "MoRef")][string[]]$VMHostId
    ) ## end param

    begin {
        ## the properties of the HostSystem(s) to retrieve
        $arrHostSystemPropertiesToGet = Write-Output Name, Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo
        ## the hashtable to use as the filter for the Get-View call
        $hshHostSystemFilter = @{"Runtime.ConnectionState" = "connected|maintenance"; "Runtime.PowerState" = "poweredOn"}
        ## Regular Expression against which to match the names of the numeric sensors to get the driver- and firmware sensors
        $strNumericSensorInfoNamePattern = " driver | device firmware "
    } ## end begin

    process {
        ## get the collection of host(s) for which to get NIC driver/firmware info, based on param passed
        $arrHostViews = Switch ($PsCmdlet.ParameterSetName) {
            "ByVMHostName" {
                $hshHostSystemFilter["Name"] = $VMHostName -join "|"
                Get-View -ViewType HostSystem -Property $arrHostSystemPropertiesToGet -Filter $hshHostSystemFilter
                break
            } ## end case
            "ByVMHostId" {
                Get-View -Id $VMHostId -Property $arrHostSystemPropertiesToGet
            } ## end case
        } ## end switch

        ## return the NIC driver/firmware info
        $arrHostViews | Foreach-Object {
            ## get the NumericSensorInfo items that match the given pattern (not the strongest / most robust / most reliable way, maybe; revisit how to do better?)
            $arrNicInfoItems = $_.Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo | Where-Object {$_.Name -match $strNumericSensorInfoNamePattern} | Select-Object -Unique Name
            New-Object -Type PSObject -Property @{
                VMHostName = $_.Name
                NicDriverVersion = $arrNicInfoItems | Where-Object {$_.Name -like "*driver*"} | Foreach-Object {$_.Name} | Sort-Object
                NicFirmwareVersion = $arrNicInfoItems | Where-Object {$_.Name -like "*device firmware*"} | Foreach-Object {$_.Name} | Sort-Object
            } ## end new-object
        } ## end foreach-object
    } ## end process
} ## end fn


# ## other functions:
# ## Get-VMHostFirmwareInfo
# <#  .Description
#     quick script to get BIOS date, Smart Array FW version, and iLO FW version for HP hosts in a given location (folder, cluster, datacenter, etc.); Sep 2011 -- Matt Boren
#     -updated 22-Sep-2011 by Allen Crawford -- added parameters
#     -updated 26 Oct 2011 by Matt Boren -- added comment based help, added "default" value for $strViewType, if neither param is supplied
#     .Example
#     Get-VMHostFirmwareInfo
#     Get all hosts' firmware info
#     .Example
#     Get-VMHostFirmwareInfo -clusterName MyCluster

#     Get firmware info for hosts in the cluster "MyCluster"
#     .Example
#     Get-VMHostFirmwareInfo | sort HPSmartArray,VMHost | ft -a VMHost,SystemBIOS,HPSmartArray
#     Get all hosts' firmware info, and return table of just the given properties, sorted on HPSmartArray version then VMHost name
# #>

# ## params for cluster- or folder-based queries
# param(
#     ## the name of the cluster to query
#     [string]$clusterName_str,
#     ## the name of the folder to query
#     [string]$folderName_str
# ) ## end parameter

# if ($clusterName_str) {
#     $strViewType = "ClusterComputeResource"
#     $strEntityName = $clusterName_str
# } ## end if
# elseif ($folderName_str) {
#     $strViewType = "Folder"
#     $strEntityName = $folderName_str
# } ## end elseif
# ## else, just get info for all hosts (not setting value for $strEntityName)
# else {$strViewType = "DataCenter"}

# Get-View -ViewType HostSystem -Property Name, Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo -SearchRoot (Get-View -ViewType $strViewType -Property Name -Filter @{"Name" = $strEntityName}).MoRef | %{
#     $viewHostSystem = $_
#     $arrNumericSensorInfo = @($viewHostSystem.Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo)
#     ## HostNumericSensorInfo for BIOS, iLO, array controller
#     $nsiBIOS = $arrNumericSensorInfo | ?{$_.Name -like "*System BIOS*"}
#     $nsiArrayCtrlr = $arrNumericSensorInfo | ?{$_.Name -like "HP Smart Array Controller*"}
#     $nsiILO = $arrNumericSensorInfo | ?{$_.Name -like "Hewlett-Packard BMC Firmware*"}
#     New-Object PSObject -Property @{
#         VMHost = $viewHostSystem.Name
#         SystemBIOS = $nsiBIOS.name
#         HPSmartArray = $nsiArrayCtrlr.Name
#         iLOFirmware = $nsiILO.Name
#     } ## end new-object
# } ## end Foreach-Object





# function Update-TitleBarForPowerCLI {
#     $strWindowTitle = "[PowerCLI] {0}" -f $(
#         if ($global:DefaultVIServers.Count -gt 0) {
#             if ($global:DefaultVIServers.Count -eq 1) {"Connected to {0} as {1}" -f $global:DefaultVIServers[0].Name, $global:DefaultVIServers[0].User}
#             else {"Connected to {0} servers:  {1}." -f $global:DefaultVIServers.Count, (($global:DefaultVIServers | Foreach-Object {$_.Name}) -Join ", ")}
#         } ## end if
#         else {"Not Connected"}
#     ) ## end -f call
#     $host.ui.RawUI.WindowTitle = $strWindowTitle
# } ## end fn





# ## Get-VMHostLogicalVolumeInfo
# <#  .Description
#     Get logical volume info for VMHost from StorageStatusInfo of their managed objects. Depends on CIM provider being installed and in good health, presumably.  Aug 2012, MBoren
#     Updated Mar 2013 to also take HostSystem .NET View object(s) as param, instead of just host name
# #>
# [CmdletBinding(DefaultParameterSetName="ByVMHostName")]
# param(
#     ## name of VMHost to check; if none, queries all hosts
#     [parameter(ParameterSetName="ByVMHostName")][string]$VMHostName,
#     ## Managed Object(s) of host(s) to check
#     [parameter(ParameterSetName="ByHostSystem")][VMware.Vim.HostSystem[]]$HostSystem_mo
# ) ## end param

# ## name of the HostSystem property from which to get logical volume info
# $strMOPropertyForStorageStatusInfo = 'Runtime.HealthSystemRuntime.HardwareStatusInfo.StorageStatusInfo'

# Switch ($PsCmdlet.ParameterSetName) {
#     "ByVMHostName" {
#         ## make the Get-View expression to invoke
#         $strGetViewExpr = 'Get-View -ViewType HostSystem -Property Name,$strMOPropertyForStorageStatusInfo'
#         ## if there is a host name filter, add it
#         if ($VMHostName) {$strGetViewExpr += " -Filter @{'Name' = '$VMHostName'}"}
#         ## get the HostSystem(s) of interest
#         $arrHostSystemViews = Invoke-Expression $strGetViewExpr
#         break;} ## end case
#     "ByHostSystem" {
#         ## make sure the the .NET View objects have desired property populated
#         $HostSystem_mo | %{$_.UpdateViewData("Name",$strMOPropertyForStorageStatusInfo)}
#         $arrHostSystemViews = $HostSystem_mo
#         break;} ## end case
# } ## end switch

# ## select the given items that deal with logical volumes on the host(s)
# $arrHostSystemViews | Select name,@{n="logicalVol"; e={($_.Runtime.HealthSystemRuntime.HardwareStatusInfo.StorageStatusInfo | ?{$_.Name -like "Logical*"} | %{$_.Name}) -join ", "}}




# ## Evacuate-Datastore
# <#  .Description
#     Script to evacuate virtual disks and/or VM config files from a given datastore; does not move the entire VM and all its disks if they reside elsewhere. Created 06-Nov-2012 by vNugglets.com.
#     -updated 11-Nov-2012 by Matt Boren -- added comments, optimized syntax
#     -updated 05-Dec-2012 by Allen Crawford -- added parameters and more comments
#     -updated 11-Dec-2012 by Allen Crawford -- added ability to relocate VMs with no virtual disks as well as templates
#     -updated 12-Dec-2012 by Matt Boren -- optimized syntax from previous change
#     -updated Jun 2014 by Matt Boren
#         -allows for datastorecluster for "DestDatastore" param, so as to move a datastore's contents to datastores in a datastore cluster
#         -added WhatIf support
#     -updated Sep 2014 by Matt Boren -- added ability to exclude a VM/template's files from evacuation process (via param)
#     -updated Oct 2016 by Matt Boren -- added feature that uses any/all datastores in datastores cluster (when one is specified for Destination param) for potential destination _per object_ (potentially different datastore for each virtual disk on a VM)
#     .Example
#     EvacuateDatastore -SourceDatastore datastoreToEvac -DestDatastore destinationDatastore -RunAsync
#     Move virtual disks and/or VM config files (if any) from source datastore to the destination datastore, running asynchronously
#     .Example
#     EvacuateDatastore -SourceDatastore datastoreToEvac -DestDatastore (Get-DatastoreCluster my_datastoreCluster)
#     Move VM files from source datastore to datastores in given datastore cluster
# #>

# [CmdletBinding(SupportsShouldProcess=$true)]
# param(
#     ## The name of the source datastore (the one to evacuate)
#     [parameter(Mandatory=$true)][string]$SourceDatastore,
#     ## The name of the destination datastore
#     [parameter(Mandatory=$true)]$DestDatastore,
#     ## Name of VM/template to exclude from evacuation activities (exact name)
#     [string[]]$ExcludeVMName,
#     ## Switch:  exclude templates from this evacuation effort?
#     [Switch]$ExcludeAllTemplate,
#     ## switch:  Run asynchonously?
#     [switch]$RunAsync
# ) ## end parameter

# Begin {
#     ## get the datastore View object, either from one of the datastore IDs in the datastorecluster (if passed), or by the datastore that matches the datastore name given
#     $arrDestDatastoreView = if ($DestDatastore -is [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.DatastoreCluster]) {
#         Get-View -Id ($DestDatastore.ExtensionData.ChildEntity) -Property Name
#     } else {Get-View -ViewType Datastore -Property Name -Filter @{"Name" = "^${DestDatastore}$"}}
# } ## end begin

# Process {
#     ## Set proper variable name from the supplied parameter
#     $strSrcDatastore = $SourceDatastore

#     ## Get the .NET view of the source datastore
#     $viewSrcDatastore = Get-View -ViewType Datastore -Property Name -Filter @{"Name" = "^${strSrcDatastore}$"}
#     ## Get the linked view that contains the list of VMs on the source datastore
#     $viewSrcDatastore.UpdateViewData("Vm.Config.Files.VmPathName", "Vm.Config.Hardware.Device", "Vm.Config.Template", "Vm.Runtime.Host", "Vm.Name")

#     ## Create a VirtualMachineMovePriority object for the RelocateVM task; 0 = defaultPriority, 1 = highPriority, 2 = lowPriority (per http://pubs.vmware.com/vsphere-51/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc%2Fvim.VirtualMachine.MovePriority.html)
#     $specVMMovePriority = New-Object VMware.Vim.VirtualMachineMovePriority -Property @{"value__" = 1}

#     ## For each VM View object, initiate the RelocateVM_Task() method; for each template object, initiate the RelocateVM() method
#     $viewSrcDatastore.LinkedView.Vm | Foreach-Object {
#         $viewVMToMove = $_
#         ## if this machine was to be excluded, do not move its files
#         if (($ExcludeAllTemplate -and ($viewVMToMove.Config.Template -eq "True")) -or ($ExcludeVMName -contains $viewVMToMove.Name)) {Write-Verbose -Verbose "not moving files for excluded machine '$($viewVMToMove.Name)'"}
#         ## else, doit
#         else {
#             ## Create a VirtualMachineRelocateSpec object for the RelocateVM task
#             $specVMRelocate = New-Object Vmware.Vim.VirtualMachineRelocateSpec
#             ## Create an array containing all the virtual disks for the current VM/template
#             $arrVirtualDisks = $viewVMToMove.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualDisk]}
#             ## If the VM/template's config files reside on the source datastore, set this to the destination datastore (if not specified, the config files are not moved)
#             if ($viewVMToMove.Config.Files.VmPathName.Split("]")[0].Trim("[") -eq $strSrcDatastore) {
#                 $specVMRelocate.Datastore = ($arrDestDatastoreView | Get-Random).MoRef
#             } ## end if

#             ## For each VirtualDisk for this VM/template, make a VirtualMachineRelocateSpecDiskLocator object (to move disks that are on the source datastore, and leave other disks on their current datastore)
#             ## But first, make sure the VM/template actually has any disks
#             if ($arrVirtualDisks) {
#                 foreach($oVirtualDisk in $arrVirtualDisks) {
#                     $oVMReloSpecDiskLocator = New-Object VMware.Vim.VirtualMachineRelocateSpecDiskLocator -Property @{
#                         ## If this virtual disk's filename matches the source datastore name, set the VMReloSpecDiskLocator Datastore property to the destination datastore's MoRef, else, set this property to the virtual disk's current datastore MoRef
#                         DataStore = if ($oVirtualDisk.Backing.Filename -match $strSrcDatastore) {($arrDestDatastoreView | Get-Random).MoRef} else {$oVirtualDisk.Backing.Datastore}
#                         DiskID = $oVirtualDisk.Key
#                     } ## end new-object
#                     $specVMRelocate.disk += $oVMReloSpecDiskLocator
#                 } ## end foreach
#             } ## end if

#             if ($PSCmdlet.ShouldProcess("VM '$($viewVMToMove.Name)'", "Relocate files from datastore '$($viewSrcDatastore.Name)', with '$($arrDestDatastoreView.Name -join ", ")' as potential destination")) {
#                 ## Determine if template or VM, then perform necessary relocation steps
#                 if ($viewVMToMove.Config.Template -eq "True") {
#                     ## Gather necessary objects to mark template as a VM (VMHost where template currently resides and default, root resource pool of the cluster)
#                     $viewTemplateVMHost = Get-View -Id $_.Runtime.Host -Property Parent
#                     $viewTemplateResPool = Get-View -ViewType ResourcePool -Property Name -SearchRoot $viewTemplateVMHost.Parent -Filter @{"Name" = "^Resources$"}
#                     ## Mark the template as a VM
#                     $_.MarkAsVirtualMachine($viewTemplateResPool.MoRef, $viewTemplateVMHost.MoRef)
#                     ## Relocate the template synchronously (i.e. one at a time)
#                     Write-Verbose -Verbose "moving template '$($viewVMToMove.Name)' synchronously (template -> VM -> move datastores -> template)"
#                     $oThisReloTask_moref = $viewVMToMove.RelocateVM_Task($specVMRelocate, $specVMMovePriority)
#                     Write-Verbose "migrate task Id: '$oThisReloTask_moref'"
#                     Get-Task -Id $oThisReloTask_moref | Wait-Task
#                     ## Convert VM back to template
#                     $viewVMToMove.MarkAsTemplate()
#                 } ## end if
#                 else {
#                     ## Initiate the RelocateVM task (asynchronously), if RunAsync switch is $true
#                     if ($RunAsync) {$viewVMToMove.RelocateVM_Task($specVMRelocate, $specVMMovePriority)}
#                     ## else, invoke the RelocateVM method (synchronously)
#                     else {$viewVMToMove.RelocateVM($specVMRelocate, $specVMMovePriority)}
#                 } ## end else
#             } ## end if
#         } ## end else
#     } ## end foreach-object
# } ## end process




# ## Get-UplinkNicForVM
# <#  .Description
#     Script to retrieve Netports' (portgroup ports) client, uplink info, vSwitch, etc. info.  Includes things like VMKernel ports and Mangement uplinks.  Nov 2012, Matt Boren
#     Updated Apr 2015 -- cleaned up
#     .Example
#     Get-UplinkNicForVM -VMHost myhost0.dom.com -Cred (Get-Credential root)

#     ClientName                    TeamUplink                    vSwitch                       VMHost
#     ----------                    ----------                    -------                       ---------------
#     Management                    n/a                           vSwitch0                      myhost0.dom.com
#     vmk1                          vmnic0                        vSwitch0                      myhost0.dom.com
#     vmk0                          vmnic0                        vSwitch0                      myhost0.dom.com
#     myvm001                       vmnic0                        vSwitch0                      myhost0.dom.com
#     myvm002                       vmnic3                        vSwitch1                      myhost0.dom.com
#     myvm003                       vmnic5                        vSwitch2                      myhost0.dom.com
#     ...

#     Get the Netports on given VMHost, and return their client name, uplink vmnic, vSwitch, etc.
#     .Outputs
#     PSObject
# #>

# param(
#     ## the VMHost DNS name whose VMs' uplink info to get (not VMHost object name -- so, do not use wildcards)
#     [parameter(Mandatory=$true)][string]$VMHostToCheck,
#     ## PSCredential to use for connecting to VMHost; will prompt for credentials if not passed in here
#     [System.Management.Automation.PSCredential]$CredentialForVMHost = $host.ui.PromptForCredential("Need credentials to connect to VMHost", "Please enter credentials for '$VMHostToCheck'", $null, $null)
# ) ## end param

# process {
#     $strThisVMHostName = $VMHostToCheck

#     ## check if VMHost name given is responsive on the network; if not, exit
#     if (-not (Test-Connection -Quiet -Count 3 -ComputerName $strThisVMHostName)) {Write-Warning "VMHost '$strThisVMHostName' not responding on network -- not proceeding"}
#     else {
#         ## connect to the given VIServer (VMHost, here); use -Force (new in PowerCLI v5.1) to "Suppress all user interface prompts during the cmdlet execution. Currently these include 'Multiple default servers' and 'Invalid certificate action'"
#         $oVIServer = Connect-VIServer $strThisVMHostName -Credential $CredentialForVMHost

#         ## if connecting to VMHost failed, write warning and exit
#         if (-not $oVIServer) {Write-Warning "Did not connect to VMHost '$strThisVMHostName' -- not proceeding"}
#         else {
#             ## array with PortID to vSwitch info, for determining vSwitch name from PortID
#             ## get vSwitch ("PortsetName") and PortID info, grouped by vSwitch
#             #$arrNetPortsetEntries = (Get-EsxTop -TopologyInfo NetPortset).Entries
#             ## or, get vSwitch ("PortsetName") and PortID info, not grouped
#             $arrNetPortEntries = (Get-EsxTop -Server $strThisVMHostName -TopologyInfo NetPort).Entries

#             ## calculated property for vSwitch name
#             $hshVSwitchInfo = @{n="vSwitch"; e={$oNetportCounterValue = $_; ($arrNetPortEntries | Where-Object {$_.PortId -eq $oNetportCounterValue.PortId}).PortsetName}}

#             ## get the VM, uplink NIC, vSwitch, and VMHost info
#             Get-EsxTop -Server $strThisVMHostName -CounterName NetPort | Select-Object ClientName, TeamUplink, $hshVSwitchInfo, @{n="VMHost"; e={$_.Server}}

#             Disconnect-VIServer $strThisVMHostName -Confirm:$false
#         } ## end else
#     } ## end else
# } ## end process



# ## Copy-VIRole
# <#  .Description
#     Copy a role to another role, either in same vCenter or to a different vCenter. Jul 2013, Matt Boren
#     This assumes that connections to source/destination vCenter(s) are already established.  If role of given name already exists in destination vCenter, will stop.
#     Possible add-on in future:  add functionality to replace existing destination role (maybe, rename existing, create new with desired privileges; or, could add/remove the given, different privileges to/from the existing destination role)
#     .Example
#     Copy-VIRole -SrcRoleName SysAdm -DestRoleName SysAdm_copyTest -SrcVCName vcenter.dom.com -DestVCName othervcenter.dom.com
#     .Outputs
#     VMware.VimAutomation.ViCore.Impl.V1.PermissionManagement.RoleImpl if role is created/updated, String in Warning stream and nothing in standard out otherwise
# #>
# [CmdletBinding(SupportsShouldProcess=$true)]
# param(
#     ## Source role name
#     [parameter(Mandatory=$true)][string]$SrcRoleName,
#     ## Destination role name. If none, will use name from source role
#     [string]$DestRoleName,
#     ## Source vCenter connection name
#     [parameter(Mandatory=$true)][string]$SrcVCName,
#     ## Destination vCenter connection name
#     [parameter(Mandatory=$true)][string]$DestVCName
# ) ## end param

# process {
#     ## get the VIRole from the source vCenter
#     $oSrcVIRole = Get-VIRole -Server $SrcVCName -Name $SrcRoleName -ErrorAction:SilentlyContinue
#     ## if the role does not exist in the source vCenter
#     if ($null -eq $oSrcVIRole) {Throw "VIRole '$SrcRoleName' does not exist in source vCenter '$SrcVCName'. No source VIRole from which to copy"}
#     if (-not $PSBoundParameters.ContainsKey("DestRoleName")) {$DestRoleName = $oSrcVIRole.Name}
#     ## see if there is VIRole by the given name in the destination vCenter
#     $oDestVIRole = Get-VIRole -Server $DestVCName -Name $DestRoleName -ErrorAction:SilentlyContinue

#     ## if the role already exists in the destination vCenter
#     if ($null -ne $oDestVIRole) {Throw "VIRole '$DestRoleName' already exists in destination vCenter '$DestVCName'"}
#     ## else, create the role
#     else {
#         New-VIRole -Server $DestVCName -Name $DestRoleName -Privilege (Get-VIPrivilege -Server $DestVCName -Id $oSrcVIRole.PrivilegeList)
#     } ## end else
# } ## end process




# ## Get-VMOnNetworkPortGroup
# <#  .Description
#     Script to get names of VMs on a given virtual network (a.k.a. "virtual portgroup"), and the VMs' VMhost names.  Matt Boren, Nov 2012
#     Updated Nov 2013:  added piece to return VMHosts' cluster name, too
#     Updated Apr 2015:  added PowerState and MoRef properties
#     .Example
#     Get-VMOnNetworkPortGroup -net VLAN19

#     VMName           NetworkName      VMHost
#     ------           -----------      ------
#     vm0.dom.com      VLAN19.Sekurr    vmhost0.dom.com
#     vm10.dom.com     VLAN19.Sekurr    vmhost3.dom.com
#     vm32.dom.com     VLAN19.Sekurr    vmhost2.dom.com
#     ...

#     Get networks matching "VLAN19", and get their VMs' names and the VMs' host
#     .Outputs
#     PSObject
# #>

# param(
#     ## name of network to get; regex pattern
#     [parameter(Mandatory=$true)][string[]]$NetworkName
# ) ## end param

# process {
#     $arrNetworkViews = Get-View -ViewType Network -Property Name -Filter @{"Name" = $($NetworkName -join "|")}
#     if (($arrNetworkViews | Measure-Object).Count -eq 0) {Write-Warning "No networks found matching name '$NetworkName'"}
#     else {
#         ## get the networks' VMs' info
#         $arrNetworkViews | Foreach-Object {$_.UpdateViewData("Vm.Name","Vm.Runtime.Host.Name","Vm.Runtime.Host.Parent.Name","Vm.Runtime.PowerState")}
#         $arrNetworkViews | Foreach-Object {
#             $viewNetwk = $_
#             $viewNetwk.LinkedView.Vm | Foreach-Object {
#                 New-Object -TypeName PSObject -Property ([ordered]@{
#                     Name = $_.Name
#                     Network = $viewNetwk.Name
#                     VMHost = $_.Runtime.LinkedView.Host.Name
#                     Cluster = $_.Runtime.LinkedView.Host.LinkedView.Parent.Name
#                     PowerState = $_.Runtime.PowerState
#                     MoRef = $_.MoRef
#                 })
#             } ## end foreach-object
#         } ## end foreach-object
#     } ## end else
# } ## end process




# ## Get-VMDiskAndRDM
# <#  .Description
#     Snippet of code to get a VM's hard disk and RDM info; Sep 2011 -- Matt Boren
#     -updated Oct 2011 -- MBoren:  re-wrote to use .NET View objects instead of native cmdlets, so now it is much faster
#     -updated Dec 2013 -- MBoren:  re-wrote to use New-Object instead of hashtables for calculated properties, and removed a redundant lookup that impacted speed by about 50%!  Go-o-o-o, FaF!
#     -updated Sep 2014 -- MBoren:  added parameter Id for VM ID, added ability to accept value from pipeline for Id (good for piping VM objects and VirtualMachine objects to the function)
#     .Example
#     Get-VMDiskAndRDM -VM someVM
#     Get the disks (including RDMs) for "someVM".  Output would be something like:
#     VMName            : someVM
#     HardDiskName      : Hard disk 1
#     ScsiId            : 0:0
#     DeviceDisplayName :
#     SizeGB            : 50
#     ScsiCanonicalName :

#     VMName            : someVM
#     HardDiskName      : Hard disk 2
#     ScsiId            : 1:0
#     DeviceDisplayName : someVM-/log_dir
#     SizeGB            : 20
#     ScsiCanonicalName : naa.60000111111115615641111111111111
#     .Example
#     Get-VMDiskAndRDM -VM someVM | ft -a
#     Get the disks (including RDMs) for "someVM", formatting output in auto-sized table.  Output would be something like:
#     VMName HardDiskName ScsiId DeviceDisplayName SizeGB ScsiCanonicalName
#     ------ ------------ ------ ----------------- ------ -----------------
#     someVM Hard disk 1  0:0                          50
#     someVM Hard disk 2  1:0    someVM-/log_dir       20 naa.60000111111115615641111111111111
# #>
# [CmdletBinding(DefaultParameterSetName="ByName")]
# param(
#     ## Name pattern of the VM guest for which to get info
#     [parameter(Mandatory=$true,ParameterSetName="ByName",Position=0)][string]$VM,
#     ## MoRef of VM for which to get disk information
#     [parameter(ParameterSetName="ById",ValueFromPipelineByPropertyName=$true,Position=0)][Alias("MoRef")][string[]]$Id,
#     ## switch to specify that VMDK's datastore path should also be returned
#     [switch]$ShowVMDKDatastorePath_sw
# )

# begin {
#     $hshParamForGetViewForVMachine = @{Property = @("Name", "Config.Hardware.Device", "Runtime.Host")}
# } ## end begin

# process {
#     <# the new, cool, FaF way (using .NET View objects) #>
#     ## get the VM object(s)
#     Switch ($PSCmdlet.ParameterSetName) {
#         "ByName" {
#             $hshParamForGetViewForVMachine["ViewType"] = "VirtualMachine"
#             $hshParamForGetViewForVMachine["Filter"] = @{"Name" = "^$VM(\..*)?"}
#             $strMessageForWarning = "name pattern '$VM'"
#         } ## end case
#         "ById" {
#             $hshParamForGetViewForVMachine["Id"] = $Id
#             $strMessageForWarning = "Id '$Id'"
#         } ## end case
#     } ## end switch
#     $arrVMViewsForStorageInfo = Get-View @hshParamForGetViewForVMachine
#     if (($arrVMViewsForStorageInfo | Measure-Object).Count -eq 0) {Throw "No VirtualMachine objects found matching $strMessageForWarning"} ## end if

#     $arrVMViewsForStorageInfo | Foreach-Object {
#         $viewVMForStorageInfo = $_
#         ## get the view of the host on which the VM currently resides
#         $viewHostWithStorage = Get-View -Id $viewVMForStorageInfo.Runtime.Host -Property Config.StorageDevice.ScsiLun

#         $viewVMForStorageInfo.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualDisk]} | Foreach-Object {
#             $hdThisDisk = $_
#             $oScsiLun = $viewHostWithStorage.Config.StorageDevice.ScsiLun | Where-Object {$_.UUID -eq $hdThisDisk.Backing.LunUuid}
#             ## the properties to return in new object
#             $hshThisVMProperties = @{
#                 VMName = $viewVMForStorageInfo.Name
#                 ## the disk's "name", like "Hard disk 1"
#                 HardDiskName = $hdThisDisk.DeviceInfo.Label
#                 ## get device's SCSI controller and Unit numbers (1:0, 1:3, etc)
#                 ScsiId = &{$strControllerKey = $_.ControllerKey.ToString(); "{0}`:{1}" -f $strControllerKey[$strControllerKey.Length - 1], $_.Unitnumber}
#                 DeviceDisplayName = $oScsiLun.DisplayName
#                 SizeGB = [Math]::Round($_.CapacityInKB / 1MB, 0)
#                 ScsiCanonicalName = $oScsiLun.CanonicalName
#             } ## end hsh
#             ## the array of items to select for output
#             $arrPropertiesToSelect = "VMName,HardDiskName,ScsiId,DeviceDisplayName,SizeGB,ScsiCanonicalName".Split(",")
#             ## add property for VMDKDStorePath if desired
#             if ($ShowVMDKDatastorePath_sw -eq $true) {$hshThisVMProperties["VMDKDStorePath"] = $hdThisDisk.Backing.Filename; $arrPropertiesToSelect += "VMDKDStorePath"}
#             New-Object -Type PSObject -Property $hshThisVMProperties | Select $arrPropertiesToSelect
#         } ## end foreach-object
#     } ## end foreach-object
# } ## end process



# ## Get-VMWithGivenRDM
# <#  .Description
#     Code to find what VM (if any) is using a LUN as an RDM, based on the LUN's SCSI canonical name. Assumes that the best practice of all hosts in a cluster seeing the same LUNs is followed.  Nov 2011, Matt Boren
#     Updated Dec 2013:  added ability to pass array of canonical names, changed verbose output to use Write-Verbose
#     .Example
#     Get-VMWithGivenRDM -CanonicalName naa.60000112233445501000000000000001 -Cluster someCluster | ft -a
#     Find a VM using the given LUN as an RDM, formatting output in auto-sized table.  Output would be something like:

#     VMName   VMDiskName   DeviceDisplayName CanonicalName
#     ------   ----------   ----------------- -------------
#     myvm0050 Hard disk 10 myvm0050-data     naa.60000112233445501000000000000001
#     .Outputs
#     Zero or more PSObjects with info about the VM and its RDM
# #>

# [CmdletBinding()]
# Param(
#     ## The canonical name of the LUN in question
#     [parameter(Mandatory=$true)][string[]]$CanonicalName,
#     ## The cluster whose hosts see this LUN
#     [parameter(Mandatory=$true)][string]$ClusterName
# ) ## end param

# process {
#     ## get the View object of the cluster in question
#     $viewCluster = Get-View -ViewType ClusterComputeResource -Property Name -Filter @{"Name" = "^$([RegEx]::escape($ClusterName))$"}
#     ## get the View of a host in the given cluster (presumably all hosts in the cluster see the same storage)
#     $viewHostInGivenCluster = Get-View -ViewType HostSystem -Property Name -SearchRoot $viewCluster.MoRef | Get-Random
#     ## get the Config.StorageDevice.ScsiLun property of the host (retrieved _after_ getting the View object for speed, as this property is only retrieved for this object, not all hosts' View objects)
#     $viewHostInGivenCluster.UpdateViewData("Config.StorageDevice.ScsiLun")

#     ## if matching device(s) found, store some info for later use
#     $arrMatchingDisk = &{
#         ## get the View objects for all VMs in the given cluster
#         Get-View -ViewType VirtualMachine -Property Name, Config.Hardware.Device -SearchRoot $viewCluster.MoRef | Foreach-Object {$viewThisVM = $_
#             ## for all of the RDM devices on this VM, see if the canonical name matches the canonical name in question
#             $viewThisVM.Config.Hardware.Device | Where-Object {($_ -is [VMware.Vim.VirtualDisk]) -and ("physicalMode","virtualMode" -contains $_.Backing.CompatibilityMode)} | Foreach-Object {
#                 $hdThisDisk = $_
#                 $lunScsiLunOfThisDisk = $viewHostInGivenCluster.Config.StorageDevice.ScsiLun | Where-Object {$_.UUID -eq $hdThisDisk.Backing.LunUuid}
#                 ## if the canonical names match, create a new PSObject with some info about the VirtualDisk and the VM using it
#                 if ($CanonicalName -contains $lunScsiLunOfThisDisk.CanonicalName) {
#                     New-Object -TypeName PSObject -Property @{
#                         VMName = $viewThisVM.Name
#                         VMDiskName = $hdThisDisk.DeviceInfo.Label
#                         CanonicalName = $lunScsiLunOfThisDisk.CanonicalName
#                         DeviceDisplayName = $lunScsiLunOfThisDisk.DisplayName
#                     } ## end new-object
#                 } ## end if
#             } ## end where-object
#         } ## end where-object
#     } ## end subexpression

#     ## if a matching device was found, output its info
#     if ($arrMatchingDisk) {$arrMatchingDisk | Select VMName, VMDiskName, DeviceDisplayName, CanonicalName}
#     ## else, say so
#     else {Write-Verbose "Booo. No matching disk device with canonical name in '$CanonicalName' found attached to a VM as an RDM in cluster '$ClusterName'"}
# }

