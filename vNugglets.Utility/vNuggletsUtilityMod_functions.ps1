function Find-VNVMWithDuplicateMACAddress {
<#  .Description
    Get information about the VM(s) that have a network adapter whose MAC address is a duplicate of another network adapter in the vCenter(s) to which this PowerCLI session is connected

    .Synopsis
    Get information about duplicate MAC addresses

    .Example
    Find-VNVMWithDuplicateMACAddress
    VMName                DuplicatedMAC         MoRef                                                Count
    ------                -------------         -----                                                -----
    {myVM03, oldVM322}    00:50:56:3F:FF:FF     {VirtualMachine-vm-16277, VirtualMachine-vm-109}         2

    Find VMs with network adapters whose MAC address is the same, and return a bit of info about them

    .Example
    Find-VNVMWithDuplicateMACAddress
    VMName     DuplicatedMAC         MoRef                       Count
    ------     -------------         -----                       -----
    myVM21     00:50:56:00:00:09     VirtualMachine-vm-16277         2

    Find VM (just one, apparently, in this vCenter) with network adapters whose MAC address is the same -- in this case, the VM has at least two network adapters, both of which have the same MAC address

    .Link
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param () ## end param

    process {
        ## get VirtualMachine .NET views where the items is not marked as a Template
        $colDevMacAddrInfo = `
        Get-View -ViewType VirtualMachine -Property Name,Config.Hardware.Device -Filter @{"Config.Template" = "False"} | Foreach-Object {
           $viewThisVM = $_
           $_.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualEthernetCard]} | Foreach-Object {
               New-Object -Type PSObject -Property @{VMName = $viewThisVM.Name; MacAddr = $_.MacAddress; MoRef = $viewThisVM.MoRef}
           } ## end foreach-object
        } ## end foreach-object

        ## get the non-unique MAC addresses (if any),
        $arrDuplicatedMAC_GroupInfo = $colDevMacAddrInfo | Group-Object MacAddr | Where-Object {$_.count -gt 1}

        ## for each duplicated MAC, return an object with the given properties
        if ($null -ne $arrDuplicatedMAC_GroupInfo) {
            $arrDuplicatedMAC_GroupInfo | Foreach-Object {
                New-Object -Type PSObject -Property ([ordered]@{
                    VMName = $_.Group | Foreach-Object {$_.VMName} | Select-Object -Unique
                    DuplicatedMAC = $_.Name
                    MoRef = $_.Group | Foreach-Object {$_.MoRef} | Select-Object -Unique
                    Count = $_.Count
                }) ## end new-object
            } ## end foreach-object
        } ## end if
        else {Write-Verbose "no duplicate MAC addresses found on non-template VMs"}
    } ## end process
} ## end function



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
    Name     IP                                         MoRef                  Client
    ------   ---                                        -----                  ------
    myvm10   {192.16.13.1, 10.37.31.12, fe80::000...}   VirtualMachine-vm-13   VMware.Vim.VimClientImpl

    Get VMs with given IP as reported by VMware Tools, return VM name and its IP addresses

    .Example
    Get-VNVMByAddress -AddressWildcard 10.0.0.*
    Name           IP                                      MoRef
    ----           --                                      -----
    myvm3          {10.0.0.20, fe80::000:5600:fe00:6007}   VirtualMachine-vm-153
    mytestVM001    10.0.0.200                              VirtualMachine-vm-162

    Use -AddressWildcard to find VMs with approximate IP

    .Example
    Get-VNVMByAddress -IP 10.37.31.12
    Name     GuestHostname    MoRef                  Client
    ------   -------------    -----                  ------
    myvm10   myvm10.dom.com   VirtualMachine-vm-13   VMware.Vim.VimClientImpl

    Get VMs with given hostname configured in the guest OS as reported by VMware Tools, return VM name and its guest hostname

    .Example
    Get-VNVMByAddress -Uuid b99b546a-ee00-43f3-856a-80779ffddd0e
    Name     Uuid                                   MoRef                     Client
    ------   ----                                   -----                     ------
    myvm37   b99b546a-ee00-43f3-856a-80779ffddd0e   VirtualMachine-vm-19991   VMware.Vim.VimClientImpl

    Get VMs with given SMBIOS UUID, return VM name and its UUID

    .Link
    Get-VNVMByRDM
    Get-VNVMByVirtualPortGroup
    http://vNugglets.com

    .Notes
    Finding VMs by IP address / Guest hostname relies on information returned from VMware Tools in the guest, so VMware Tools must be installed in the guest and have been running in the guest at least recently.

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
        [parameter(Mandatory=$true,ParameterSetName="FindByIPWildcard",Position=0)][string]$AddressWildcard,

        ## Fully qualified DNS hostname as it appears in guest OS, for finding VM by guest hostname
        [parameter(Mandatory=$true,ParameterSetName="FindByGuestHostname",Position=0)][string]$GuestHostname,

        ## VM SMBIOS UUID, for finding VM by UUID
        [parameter(Mandatory=$true,ParameterSetName="FindByUuid",Position=0)][string]$Uuid
    ) ## end param

    begin {
        ## array of properties to select on VirtualMachine object return when searching by IP or IP Wildcard, by Guest hostname, etc.
        $arrPropertiesForReturnWhenSearchByIP = "Name", @{n="IP"; e={$_.Guest.Net | Foreach-Object {$_.IpAddress} | Sort-Object}}, "MoRef", "Client"
        $arrPropertiesForReturnWhenSearchByGuestHostname = "Name", @{n="GuestHostname"; e={$_.Guest.HostName}}, "MoRef", "Client"
        $arrPropertiesForReturnWhenSearchByUuid = "Name", @{n="Uuid"; e={$_.Config.Uuid}}, "MoRef", "Client"
    } ## end begin

    Process {
        Switch ($PsCmdlet.ParameterSetName) {
            "FindByMac" {
                ## return the some info for the VM(s) with the NIC w/ the given MAC
                Get-View -Viewtype VirtualMachine -Property Name, Config.Hardware.Device | Where-Object {$_.Config.Hardware.Device | Where-Object {($_ -is [VMware.Vim.VirtualEthernetCard]) -and ($MAC -contains $_.MacAddress)}} | Select-Object Name, @{n="MacAddress"; e={$_.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualEthernetCard]} | Foreach-Object {$_.MacAddress} | Sort-Object}}, MoRef
                break
            } ## end case
            "FindByIp" {
                ## get the SearchIndex object(s) (one from each connected vCenter)
                Get-View -Id SearchIndex-SearchIndex -PipelineVariable viewThisSearchIndex | Foreach-Object {
                    ## the vCenter name for this SearchIndex (ServiceUrl is like "https://myvcenter.dom.com/sdk", and the .Host property of a .NET URI object is just the DNS hostname portion of the URI)
                    $strVcenterOfThisSearchIndex = ([System.Uri]$viewThisSearchIndex.Client.ServiceUrl).Host
                    ## SearchIndex Find* methods return MoRefs; docs at http://pubs.vmware.com/vsphere-65/index.jsp#com.vmware.wssdk.apiref.doc/vim.SearchIndex.html
                    #   FindAllByIp(moref datacenter*, string ip, bool vmSearch)
                    $viewThisSearchIndex.FindAllByIp($null, $IP, $true) | Select-Object -Unique | Foreach-Object {Get-View -Id $_ -Property Name, Guest.Net -Server $strVcenterOfThisSearchIndex} | Select-Object -Property $arrPropertiesForReturnWhenSearchByIP
                } ## end foreach-object
                break
            } ## end case
            "FindByGuestHostname" {
                ## get the SearchIndex object(s) (one from each connected vCenter)
                Get-View -Id SearchIndex-SearchIndex -PipelineVariable viewThisSearchIndex | Foreach-Object {
                    ## the vCenter name for this SearchIndex (ServiceUrl is like "https://myvcenter.dom.com/sdk", and the .Host property of a .NET URI object is just the DNS hostname portion of the URI)
                    $strVcenterOfThisSearchIndex = ([System.Uri]$viewThisSearchIndex.Client.ServiceUrl).Host
                    ## SearchIndex Find* methods return MoRefs; docs at http://pubs.vmware.com/vsphere-65/index.jsp#com.vmware.wssdk.apiref.doc/vim.SearchIndex.html
                    #   FindAllByDnsName(moref datacenter*, string dnsName, bool vmSearch)
                    $viewThisSearchIndex.FindAllByDnsName($null, $GuestHostname, $true) | Select-Object -Unique | Foreach-Object {Get-View -Id $_ -Property Name, Guest.HostName -Server $strVcenterOfThisSearchIndex} | Select-Object -Unique -Property $arrPropertiesForReturnWhenSearchByGuestHostname
                } ## end foreach-object
                break
            } ## end case
            "FindByUuid" {
                ## get the SearchIndex object(s) (one from each connected vCenter)
                Get-View -Id SearchIndex-SearchIndex -PipelineVariable viewThisSearchIndex | Foreach-Object {
                    ## the vCenter name for this SearchIndex (ServiceUrl is like "https://myvcenter.dom.com/sdk", and the .Host property of a .NET URI object is just the DNS hostname portion of the URI)
                    $strVcenterOfThisSearchIndex = ([System.Uri]$viewThisSearchIndex.Client.ServiceUrl).Host
                    ## SearchIndex Find* methods return MoRefs; docs at http://pubs.vmware.com/vsphere-65/index.jsp#com.vmware.wssdk.apiref.doc/vim.SearchIndex.html
                    #   FindAllByUuid(moref datacenter*, string uuid, bool vmSearch, bool instanceUuid*)
                    $viewThisSearchIndex.FindAllByUuid($null, $Uuid, $true, $false) | Select-Object -Unique | Foreach-Object {Get-View -Id $_ -Property Name, Config.Uuid -Server $strVcenterOfThisSearchIndex} | Select-Object -Unique -Property $arrPropertiesForReturnWhenSearchByUuid
                } ## end foreach-object
                break
            } ## end case
            "FindByIPWildcard" {
                ## scriptblock to use for the Where clause in finding VMs
                $sblkFindByIP_WhereStatement = {$_.IpAddress | Where-Object {$_ -like $AddressWildcard}}
                ## return the .Net View object(s) for the VM(s) with the NIC(s) w/ the given IP
                Get-View -Viewtype VirtualMachine -Property Name, Guest.Net | Where-Object {$_.Guest.Net | Where-Object $sblkFindByIP_WhereStatement} | Select-Object -Property $arrPropertiesForReturnWhenSearchByIP
            } ## end case
        } ## end switch
    } ## end process
} ## end fn



function Get-VNVMByRDM {
<#  .Description
    Function to find what VM(s) (if any) are using a LUN as an RDM, based on the LUN's SCSI canonical name. Assumes that the best practice of all hosts in a cluster seeing the same LUNs is followed.

    .Example
    Get-VNVMByRDM -CanonicalName naa.60000112233445501000000000000001 -Cluster someCluster
    VMName            : myvm002
    HardDiskName      : Hard disk 7
    CompatibilityMode : physicalMode
    CanonicalName     : naa.60000112233445501000000000000001
    DeviceDisplayName : myvm002-logs
    MoRef             : VirtualMachine-vm-174

    Find VM using the given LUN as an RDM, returning an object with the information about that RDM harddisk on the VM

    .Example
    Get-VNVMByRDM -CanonicalName naa.60000112233445501000000000000002 -Cluster someCluster | ft -a VMName, HardDiskName, DeviceDisplayName, CanonicalName
    VMName    HardDiskName  DeviceDisplayName   CanonicalName
    ------    ----------    -----------------   -------------
    myvm0050  Hard disk 10  myMSCluster-quorum  naa.60000112233445501000000000000002
    myvm0051  Hard disk 10  myMSCluster-quorum  naa.60000112233445501000000000000002

    Find VMs using the given LUN as an RDM, formatting output in auto-sized table with just the given properties

    .Link
    Get-VNVMByAddress
    Get-VNVMByVirtualPortGroup
    http://vNugglets.com

    .Outputs
    Zero or more PSObjects with info about the VM and its corresponding RDM disk
#>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    Param(
        ## The canonical name(s) of the LUN(s) in question (the LUNs used as RDMs)
        [parameter(Mandatory=$true)][string[]]$CanonicalName,

        ## The cluster whose hosts see this LUN
        [parameter(Mandatory=$true)][string]$ClusterName
    ) ## end param

    process {
        ## get the View object of the cluster in question
        $viewCluster = Get-View -ViewType ClusterComputeResource -Property Name -Filter @{"Name" = "^$([RegEx]::escape($ClusterName))$"}
        ## get the View of a host in the given cluster (presumably all hosts in the cluster see the same storage)
        $viewHostInGivenCluster = Get-View -ViewType HostSystem -Property Name -SearchRoot $viewCluster.MoRef | Get-Random
        ## get the Config.StorageDevice.ScsiLun property of the host (retrieved _after_ getting the View object for speed, as this property is only retrieved for this object, not all hosts' View objects)
        $viewHostInGivenCluster.UpdateViewData("Config.StorageDevice.ScsiLun")

        ## get the View objects for all VMs in the given cluster
        Get-View -ViewType VirtualMachine -Property Name, Config.Hardware.Device -SearchRoot $viewCluster.MoRef | Foreach-Object {$viewThisVM = $_
            ## for all of the RDM devices on this VM, see if the canonical name matches the canonical name in question
            $viewThisVM.Config.Hardware.Device | Where-Object {($_ -is [VMware.Vim.VirtualDisk]) -and ("physicalMode","virtualMode" -contains $_.Backing.CompatibilityMode)} | Foreach-Object {
                $hdThisDisk = $_
                $lunScsiLunOfThisDisk = $viewHostInGivenCluster.Config.StorageDevice.ScsiLun | Where-Object {$_.UUID -eq $hdThisDisk.Backing.LunUuid}
                ## if the canonical names match, create a new PSObject with some info about the VirtualDisk and the VM using it
                if ($CanonicalName -contains $lunScsiLunOfThisDisk.CanonicalName) {
                    New-Object -TypeName PSObject -Property ([ordered]@{
                        VMName = $viewThisVM.Name
                        HardDiskName = $hdThisDisk.DeviceInfo.Label
                        CompatibilityMode = $_.Backing.CompatibilityMode
                        CanonicalName = $lunScsiLunOfThisDisk.CanonicalName
                        DeviceDisplayName = $lunScsiLunOfThisDisk.DisplayName
                        MoRef = $viewThisVM.MoRef
                    }) ## end new-object
                } ## end if
            } ## end where-object
        } ## end where-object
    } ## end process
} ## end fn



function Get-VNVMByVirtualPortGroup {
<#  .Description
    Function to get information about which VMs are on a given virtual network (a.k.a. "virtual portgroup")

    .Example
    Get-VNVMByVirtualPortGroup -NetworkName VLAN19 | ft VMName,Network,VMHost,Cluster
    VMName          Network         VMHost            Cluster
    ------          -----------     ------            -------
    vm0.dom.com     VLAN19.Sekurr   vmhost0.dom.com   myCluster0
    vm10.dom.com    VLAN19.Sekurr   vmhost3.dom.com   myCluster0
    vm32.dom.com    VLAN19.Sekurr   vmhost2.dom.com   myCluster0
    ...

    Get networks matching "VLAN19", and get their VMs' names and some other VM information

    .Example
    Get-VNVMByVirtualPortGroup -NetworkLiteralName VLAN3 | ft -a
    VMName   Network  VMHost            Cluster     PowerState   MoRef
    ------   -------  ------            -------     ----------   -----
    myVM0    VLAN3    myVMHost.dom.com  myCluster2  poweredOn    VirtualMachine-vm-142
    ...

    Get network named exactly "VLAN3", and get its VMs' names and some other VM information

    .Link
    Get-VNVMByAddress
    Get-VNVMByRDM
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="NameAsRegEx")]
    [OutputType([System.Management.Automation.PSCustomObject])]

    param(
        ## Name of the virtual network (virtual portgroup) to get.  This is a Regular Expression pattern
        [parameter(Mandatory=$true,ParameterSetName="NameAsRegEx",Position=0)][string[]]$NetworkName,

        ## Literal name of virtual network for which to get information.  This RegEx-escapes the string and adds start/end anchors ("^" and "$") so that the only match is an exact match
        [parameter(Mandatory=$true,ParameterSetName="NameAsLiteral",Position=0)][String[]]$NetworkLiteralName
    ) ## end param

    process {
        ## make the params for generating the new RegEx pattern
        $hshParamForNewRegExPattern = Switch ($PsCmdlet.ParameterSetName) {
            "NameAsRegEx" {@{String = $NetworkName; EscapeAsLiteral = $false}; break}
            ## if literal, do escape as literal
            "NameAsLiteral" {@{String = $NetworkLiteralName; EscapeAsLiteral = $true}}
        } ## end switch

        ## make the actual RegEx pattern, joining all values, and escaping if strings are to be literal
        $strNetworkNameFilter = _New-RegExJoinedOrPattern @hshParamForNewRegExPattern

        $arrNetworkViews = Get-View -ViewType Network -Property Name -Filter @{Name = $strNetworkNameFilter}
        if (($arrNetworkViews | Measure-Object).Count -eq 0) {Write-Warning "No networks found matching name '$($hshParamForNewRegExPattern['String'])'"}
        else {
            ## get the networks' VMs' info
            $arrNetworkViews | Foreach-Object {$_.UpdateViewData("Vm.Name","Vm.Runtime.Host.Name","Vm.Runtime.Host.Parent.Name","Vm.Runtime.PowerState")}
            ## for each item, return a new info object
            $arrNetworkViews | Foreach-Object {
                $viewNetwk = $_
                $viewNetwk.LinkedView.Vm | Foreach-Object {
                    New-Object -TypeName PSObject -Property ([ordered]@{
                        VMName = $_.Name
                        Network = $viewNetwk.Name
                        VMHost = $_.Runtime.LinkedView.Host.Name
                        Cluster = $_.Runtime.LinkedView.Host.LinkedView.Parent.Name
                        PowerState = $_.Runtime.PowerState
                        MoRef = $_.MoRef
                    }) ## end new-object
                } ## end foreach-object
            } ## end foreach-object
        } ## end else
    } ## end process
} ## end fn



function Get-VNVMEVCInfo {
<#  .Description
    Function to get VMs' EVC mode and that of the cluster in which the VMs reside
    .Example
    Get-Cluster myCluster | Get-VNVMEVCInfo | ?{$_.VMEVCMode -ne $_.ClusterEVCMode}
    Name        PowerState   VMEVCMode   ClusterEVCMode   ClusterName
    ----        ----------   ---------   --------------   -----------
    myvm001     poweredOff               intel-nehalem    myCluster0
    myvm100     poweredOff               intel-nehalem    myCluster0

    Get all VMs in given clusters where the VM's EVC mode does not match the Cluster's EVC mode

    .Example
    Get-VM myVM0,myVM1 | Get-VNVMEVCInfo
    Get the EVC info for the given VMs and the cluster in which they reside

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="ByCluster")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        ## Cluster whose VMs about which to get EVC information
        [parameter(ValueFromPipeline=$true,ParameterSetName="ByCluster",Position=0)][VMware.VimAutomation.Types.Cluster[]]$Cluster,

        ## VM for which to get EVC info
        [parameter(ValueFromPipeline=$true,ParameterSetName="ByVM",Position=0)][VMware.VimAutomation.Types.VirtualMachine[]]$VM
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
                Get-View -Property Name,Summary -Id $Cluster.Id | Foreach-Object {
                    $viewThisCluster = $_
                    Get-View -ViewType VirtualMachine @hshParamForGetVMView -SearchRoot $viewThisCluster.MoRef | Foreach-Object {
                        _New-InfoObj -VMView $_ -ClusterEVCModeKey $viewThisCluster.Summary.CurrentEVCModeKey -ClusterName $viewThisCluster.Name
                    } ## end foreach-object
                } ## end foreach-object
                break
            } ## end case
            "ByVM" {
                Get-View @hshParamForGetVMView -Id $VM.Id | Foreach-Object {
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

    .Link
    Get-VNVMHostFirmwareInfo
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
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
            New-Object -Type PSObject -Property ([ordered]@{
                VMHostName = $_.Name
                NicDriverVersion = $arrNicInfoItems | Where-Object {$_.Name -like "*driver*"} | Foreach-Object {$_.Name} | Sort-Object
                NicFirmwareVersion = $arrNicInfoItems | Where-Object {$_.Name -like "*device firmware*"} | Foreach-Object {$_.Name} | Sort-Object
            }) ## end new-object
        } ## end foreach-object
    } ## end process
} ## end fn


function Get-VNVMHostFirmwareInfo {
<#  .Description
    Function to get System BIOS date, HP Smart Array firmware version, and HP iLO firmware version for HP VMHosts

    .Example
    Get-VNVMHostFirmwareInfo
    Get all VMHosts' firmware info

    .Example
    Get-Cluster MyCluster | Get-VMHost | Get-VNVMHostFirmwareInfo
    Get firmware info for VMHosts in the cluster "MyCluster"

    .Example
    Get-VNVMHostFirmwareInfo | sort HPSmartArray,VMHost | ft -a VMHostName,SystemBIOS,HPSmartArray
    Get all hosts' firmware info, and return table of just the given properties, sorted on HPSmartArray version then VMHost name

    .Link
    Get-VNVMHostNICFirmwareAndDriverInfo
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParametersetName="ByVMHostName")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        ## Name pattern(s) of VMHost(s) for which to get information
        [parameter(ParameterSetName="ByVMHostName",Position=0)][Alias("Name")][string[]]$VMHostName = ".+",

        ## VMHost ID(s) for which to get information. Most useful when passing VMHost via pipeline
        [parameter(ParameterSetName="ByVMHostId",Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][Alias("Id", "MoRef")][string[]]$VMHostId
    ) ## end param

    begin {
        ## the properties of the HostSystem(s) to retrieve
        $arrHostSystemPropertiesToGet = Write-Output Name, Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo, Hardware.SystemInfo.Model
    } ## end begin

    process {
        ## get the collection of host(s) for which to get NIC driver/firmware info, based on param passed
        $arrHostViews = Switch ($PsCmdlet.ParameterSetName) {
            "ByVMHostName" {
                $hshHostSystemFilter = @{Name = $VMHostName -join "|"}
                Get-View -ViewType HostSystem -Property $arrHostSystemPropertiesToGet -Filter $hshHostSystemFilter
                break
            } ## end case
            "ByVMHostId" {
                Get-View -Id $VMHostId -Property $arrHostSystemPropertiesToGet
            } ## end case
        } ## end switch

        $arrHostViews | Foreach-Object {
            $viewHostSystem = $_
            $arrNumericSensorInfo = @($viewHostSystem.Runtime.HealthSystemRuntime.SystemHealthInfo.NumericSensorInfo)
            ## HostNumericSensorInfo for BIOS, iLO, array controller
            $nsiBIOS = $arrNumericSensorInfo | Where-Object {$_.Name -like "*System BIOS*"}
            $nsiArrayCtrlr = $arrNumericSensorInfo | Where-Object {$_.Name -like "HP Smart Array Controller*"}
            $nsiILO = $arrNumericSensorInfo | Where-Object {$_.Name -like "Hewlett-Packard BMC Firmware*"}
            New-Object PSObject -Property ([ordered]@{
                VMHostName = $viewHostSystem.Name
                SystemBIOS = $nsiBIOS.name
                HPSmartArray = $nsiArrayCtrlr.Name
                iLOFirmware = $nsiILO.Name
                Model = $viewHostSystem.Hardware.SystemInfo.Model
            }) ## end new-object
        } ## end Foreach-Object
    } ## end process
} ## end fn




function Update-VNTitleBarForPowerCLI {
<#  .Description
    Function to update the PowerShell window's title bar with the VIServers to which the current session is connected.  Called automatically by functions Connect-VNVIServer and Disconnect-VNVIServer.

    .Example
    Update-VNTitleBarForPowerCLI
    Updates PowerShell window's title bar

    .Link
    Connect-VNVIServer
    Disconnect-VNVIServer
    http://vNugglets.com

    .Outputs
    Null
#>
    process {
        $host.ui.RawUI.WindowTitle = "[PowerCLI] {0}" -f $(
            if ($global:DefaultVIServers.Count -gt 0) {
                if ($global:DefaultVIServers.Count -eq 1) {"Connected to {0} as {1}" -f $global:DefaultVIServers[0].Name, $global:DefaultVIServers[0].User}
                else {"Connected to {0} servers:  {1}." -f $global:DefaultVIServers.Count, (($global:DefaultVIServers | Foreach-Object {$_.Name}) -Join ", ")}
            } ## end if
            else {"Not Connected"}
        ) ## end -f call
    } ## end process
} ## end fn



function Connect-VNVIServer {
<#  .Description
    Function to use for connecting to VIServers instead of the default "Connect-VIServer" cmdlet -- includes call to function to update PowerShell window's title bar with the VIServer(s) to which the current session has connections

    .Example
    Connect-VNVIServer -Credential $myCred -Server myVC0.dom.com, myVC1.dom.com
    Connects to the given vCenters using the given credentials, and updates the PowerShell window's title bar accordingly

    .Link
    Disconnect-VNVIServer
    Update-VNTitleBarForPowerCLI
    http://vNugglets.com

    .Outputs
    VMware.VimAutomation.Types.VIServer
#>
    param(
        ## Name of VI server to which to connect
        [parameter(Mandatory=$true, Position=0)][string[]]$Server,

        ## Credential to use for connection
        [parameter(Position=1)][ValidateNotNullOrEmpty()][System.Management.Automation.PSCredential]$Credential
    ) ## end param

    process {
        ## check that given target VIServers are responsive to ping requests (assumes that ICMP echo traffic is allowed from the target machine)
        $arrVIServersToWhichToConnect = $Server | Foreach-Object {
            $strVIServerToWhichToConnect = $_
            if (-not (Test-Connection -Quiet -Count 2 $strVIServerToWhichToConnect)) {Write-Warning "server at '$strVIServerToWhichToConnect' not reachable; not trying to connect"}
            else {$strVIServerToWhichToConnect}
        } ## end foreach
        $hshConnectVIServerParams = @{Server = $arrVIServersToWhichToConnect}
        if ($PSBoundParameters.ContainsKey("Credential")) {$hshConnectVIServerParams["Credential"] = $Credential}
        ## connect to the given server(s)
        Connect-VIServer @hshConnectVIServerParams
        ## update the PowerShell WindowTitle
        Update-VNTitleBarForPowerCLI
    } ## end process
} ## end fn



function Disconnect-VNVIServer {
<#  .Description
    Function to use for disconnecting from VIServers, to be used instead of the "Disconnect-VIServer" cmdlet, as it includes a call to a function that updates the PowerShell window's title bar with the VIServer(s) to which the current session still has connections (if any)

    .Example
    Disconnect-VNVIServer
    Disconnects from all VIServers to which current PowerCLI session had connections

    .Link
    Connect-VNVIServer
    Update-VNTitleBarForPowerCLI
    http://vNugglets.com

    .Outputs
    Null
#>
    param (
        ## Name(s) of the VIServers from which to disconnect.  Accepts wildcards.  Disconnects from all VIServer if none specified here.
        [string[]]$Server = "*"
    ) ## end param

    process {
        Disconnect-VIServer -Server $Server -Confirm:$false
        ## update the PowerShell WindowTitle
        Update-VNTitleBarForPowerCLI
    } ## end process
} ## end fn



function Get-VNVMHostLogicalVolumeInfo {
<#  .Description
    Get logical volume information for VMHost from StorageStatusInfo of their managed objects. Depends on CIM provider being installed and in good health, presumably.

    .Example
    Get-Cluster myCluster0 | Get-VMHost | Get-VNVMHostLogicalVolumeInfo
    VMHostName          LogicalVolume
    ----------          -------------
    myhost20.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 136GB : Disk 1,2
    myhost21.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 136GB : Disk 1,2
    myhost22.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 279GB : Disk 1,2,3

    .Example
    Get-VNVMHostLogicalVolumeInfo -VMHostName myhost0,myhost1,myhost22
    VMHostName          LogicalVolume
    ----------          -------------
    myhost0.dom.com     Logical Volume 1 on HPSA1 : RAID 5 : 273GB : Disk 1,3,4
    myhost1.dom.com     Logical Volume 1 on HPSA1 : RAID 1 : 136GB : Disk 1,2
    myhost22.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 279GB : Disk 1,2,3

    .Link
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="ByVMHostName")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param (
        ## Name pattern(s) of VMHost(s) for which to get information
        [parameter(ParameterSetName="ByVMHostName",Position=0)][Alias("Name")][string[]]$VMHostName = ".+",

        ## VMHost ID(s) for which to get information. Most useful when passing VMHost via pipeline
        [parameter(ParameterSetName="ByVMHostId",Mandatory=$true,ValueFromPipelineByPropertyName=$true,Position=0)][Alias("Id", "MoRef")][string[]]$VMHostId
    ) ## end param

    begin {
        ## the properties of the HostSystem(s) to retrieve
        $arrHostSystemPropertiesToGet = Write-Output Name, Runtime.HealthSystemRuntime.HardwareStatusInfo.StorageStatusInfo
        $hshParamForGetView = @{Property = $arrHostSystemPropertiesToGet}
    } ## end begin

    process {
        Switch ($PsCmdlet.ParameterSetName) {
            "ByVMHostName" {
                $hshParamForGetView["ViewType"] = "HostSystem"
                ## if there is a host name filter, add it
                if ($PSBoundParameters.ContainsKey("VMHostName")) {$hshParamForGetView["Filter"] = @{Name = $(_New-RegExJoinedOrPattern -String $VMHostName)}}
                break
            } ## end case
            "ByVMHostId" {
                $hshParamForGetView["Id"] = $VMHostId
            } ## end case
        } ## end switch

        ## get the HostSystem(s) of interest and foreach, create a new info object with info about the logical volumes on the VMHost(s)
        Get-View @hshParamForGetView | Foreach-Object {
            New-Object -Type PSObject -Property ([ordered]@{
              VMHostName = $_.Name
              LogicalVolume = $_.Runtime.HealthSystemRuntime.HardwareStatusInfo.StorageStatusInfo | Where-Object {$_.Name -like "Logical*"} | Foreach-Object {$_.Name}
            }) ## end new-object
        } ## end foreach-object
    } ## end process
} ## end fn



function Copy-VNVIRole {
<#  .Description
    Copy a VIRole to another VIRole, either in same vCenter or to a different vCenter.
    This assumes that connections to source/destination vCenter(s) are already established.  If role of given name already exists in destination vCenter, this attempt will stop.

    .Example
    Copy-VNVIRole -SourceRoleName SysAdm -DestinationRoleName SysAdm_copyTest -SourceVCName vcenter.dom.com -DestinationVCName othervcenter.dom.com
    Copy the VIRole "SysAdm" from the given source vCenter to a new VIRole named "SysAdm_copyTest" in the given destination vCenter

    .Example
    Copy-VNVIRole -SourceRoleName MyTestRole0 -DestinationRoleName SomeRole_copyTest -SourceVCName vcenter.dom.com -DestinationVCName vcenter.dom.com
    Copy the given VIRole from the given source vCenter to a new VIRole named "SysAdm_copyTest" in the _same_ vCenter

    .Link
    http://vNugglets.com

    .Outputs
    VMware.VimAutomation.Types.PermissionManagement.Role if role is created/updated, String in Warning stream and nothing in standard out otherwise
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([VMware.VimAutomation.Types.PermissionManagement.Role])]
    param(
        ## Name of the source VIRole
        [parameter(Mandatory=$true,Position=0)][string]$SourceRoleName,

        ## Name to use for new destination VIRole. If none, will use name from source role
        [parameter(Mandatory=$true,Position=1)][string]$DestinationRoleName,

        ## Source vCenter connection name
        [parameter(Mandatory=$true)][string]$SourceVCName,

        ## Destination vCenter connection name (to copy VIRole to same vCenter, use same vCenter name for destination as used for source)
        [parameter(Mandatory=$true)][string]$DestinationVCName
    ) ## end param

    process {
        ## get the VIRole from the source vCenter
        $oSrcVIRole = Get-VIRole -Server $SourceVCName -Name $SourceRoleName -ErrorAction:SilentlyContinue
        ## if the role does not exist in the source vCenter
        if ($null -eq $oSrcVIRole) {Throw "VIRole '$SourceRoleName' does not exist in source vCenter '$SourceVCName'. No source VIRole from which to copy"}
        if (-not $PSBoundParameters.ContainsKey("DestinationRoleName")) {$DestinationRoleName = $oSrcVIRole.Name}
        ## see if there is VIRole by the given name in the destination vCenter
        $oDestVIRole = Get-VIRole -Server $DestinationVCName -Name $DestinationRoleName -ErrorAction:SilentlyContinue

        ## if the role already exists in the destination vCenter
        if ($null -ne $oDestVIRole) {Throw "VIRole '$DestinationRoleName' already exists in destination vCenter '$DestinationVCName'"}
        ## else, create the role
        else {
            New-VIRole -Server $DestinationVCName -Name $DestinationRoleName -Privilege (Get-VIPrivilege -Server $DestinationVCName -Id $oSrcVIRole.PrivilegeList)
        } ## end else
    } ## end process
} ## end fn



function Get-VNUplinkNicForVM {
<#  .Description
    Script to retrieve Netports' (virtual portgroup ports) client, uplink information, vSwitch, and more information.  This is useful for knowing which actual VMHost physcial uplink a VM is currently using.  Also includes things like VMKernel ports and Mangement uplinks.

    .Example
    Get-VNUplinkNicForVM -VMHost myhost0.dom.com -Credential (Get-Credential root)
    ClientName           TeamUplink          vSwitch           VMHost
    ----------           ----------          -------           ---------------
    Management           n/a                 vSwitch0          myhost0.dom.com
    vmk1                 vmnic0              vSwitch0          myhost0.dom.com
    vmk0                 vmnic0              vSwitch0          myhost0.dom.com
    myvm001              vmnic0              vSwitch0          myhost0.dom.com
    myvm002              vmnic3              vSwitch1          myhost0.dom.com
    myvm003              vmnic5              vSwitch2          myhost0.dom.com
    myvm050.eth0         vmnic4              DvsPortset-0      myhost0.dom.com
    ...

    Get the Netports on given VMHost, and return their client name, uplink vmnic, vSwitch, etc.  Currently the vSwitch name for virtual distributed switches is just a generic "DvsPortset-0" type of name. The ToDo for this function includes making this property have more robust values for VDSwitches

    .Link
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding()]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        ## The DNS name of the VMHost whose VMs' uplink information to get (not VMHost object name, but the name to use for connecting to said VIServer for use of Get-EsxTop cmdlet -- so, do not use wildcards)
        [parameter(Mandatory=$true)][string]$VMHostToCheck,

        ## PSCredential to use for connecting to VMHost; will prompt for credentials if not passed in here
        [System.Management.Automation.PSCredential]$Credential = $host.ui.PromptForCredential("Need credentials to connect to VMHost", "Please enter credentials for '$VMHostToCheck'", $null, $null)
    ) ## end param

    process {
        $strThisVMHostName = $VMHostToCheck

        ## check if VMHost name given is responsive on the network; if not, exit
        if (-not (Test-Connection -Quiet -Count 3 -ComputerName $strThisVMHostName)) {Write-Warning "VMHost '$strThisVMHostName' not responding on network -- not proceeding"}
        else {
            ## connect to the given VIServer (VMHost, here); use -Force (new in PowerCLI v5.1) to "Suppress all user interface prompts during the cmdlet execution. Currently these include 'Multiple default servers' and 'Invalid certificate action'"
            $oVIServer = Connect-VIServer $strThisVMHostName -Credential $Credential

            ## if connecting to VMHost failed, write warning and exit
            if (-not $oVIServer) {Write-Warning "Did not connect to VMHost '$strThisVMHostName' -- not proceeding"}
            else {
                ## array with PortID to vSwitch info, for determining vSwitch name from PortID
                ## get vSwitch ("PortsetName") and PortID info, grouped by vSwitch
                #$arrNetPortsetEntries = (Get-EsxTop -TopologyInfo NetPortset).Entries
                ## or, get vSwitch ("PortsetName") and PortID info, not grouped
                $arrNetPortEntries = (Get-EsxTop -Server $strThisVMHostName -TopologyInfo NetPort).Entries

                ## calculated property for vSwitch name
                $hshVSwitchInfo = @{n="vSwitch"; e={$oNetportCounterValue = $_; ($arrNetPortEntries | Where-Object {$_.PortId -eq $oNetportCounterValue.PortId}).PortsetName}}

                ## get the VM, uplink NIC, vSwitch, and VMHost info
                Get-EsxTop -Server $strThisVMHostName -CounterName NetPort | Select-Object ClientName, TeamUplink, $hshVSwitchInfo, @{n="VMHost"; e={$_.Server}}

                Disconnect-VIServer $strThisVMHostName -Confirm:$false
            } ## end else
        } ## end else
    } ## end process
} ## end fn



function Get-VNVMDiskAndRDM {
<#  .Description
    Function to get a VM's hard disk and RDM information.

    .Example
    Get-VM someVM | Get-VNVMDiskAndRDM
    VMName            : someVM
    HardDiskName      : Hard disk 1
    ScsiId            : 0:0
    DeviceDisplayName :
    SizeGB            : 50
    ScsiCanonicalName :

    VMName            : someVM
    HardDiskName      : Hard disk 2
    ScsiId            : 1:0
    DeviceDisplayName : someVM-/log_dir
    SizeGB            : 20
    ScsiCanonicalName : naa.60000111111115615641111111111111

    Get the disks (including RDMs) for "someVM". Note, the ScsiCanonicalName property is only valid (and only populated for) RDM disks.

    .Example
    Get-VNVMDiskAndRDM -VMName someVM | ft -a
    VMName   HardDiskName ScsiId DeviceDisplayName SizeGB ScsiCanonicalName
    ------   ------------ ------ ----------------- ------ -----------------
    someVM0  Hard disk 1  0:0                          50
    someVM0  Hard disk 2  1:0    someVM0-/log_dir      20 naa.60000111111115615641111111111111
    someVM1  Hard disk 1  0:0                         180
    someVM1  Hard disk 2  1:0    someVM1-/log_dir     120 naa.60000111111115615641111111111112

    Get the disks (including RDMs) for VMs matching the name regular expression pattern "someVM", formatting output in auto-sized table. Note, the ScsiCanonicalName property is only valid (and only populated for) RDM disks.

    .Link
    http://vNugglets.com

    .Outputs
    System.Management.Automation.PSCustomObject
#>
    [CmdletBinding(DefaultParameterSetName="NameAsRegEx")]
    [OutputType([System.Management.Automation.PSCustomObject])]
    param(
        ## Name pattern of VM for which to get information. This is a regular expression
        [parameter(Mandatory=$true,ParameterSetName="NameAsRegEx",Position=0)][String[]]$VMName,

        ## Literal name of VM for which to get information.  This RegEx-escapes the string and adds start/end anchors ("^" and "$") so that the only match is an exact match
        [parameter(Mandatory=$true,ParameterSetName="NameAsLiteral",Position=0)][String[]]$VMLiteralName,

        ## MoRef/Id of VM for which to get disk information -- most useful when passing VM or VirtualMachine object via pipeline
        [parameter(ParameterSetName="ById",ValueFromPipelineByPropertyName=$true,Position=0)][Alias("MoRef")][string[]]$Id,

        ## Switch: Also return the VMDK's datastore path?
        [switch]$ShowVMDKDatastorePath
    ) ## end param

    begin {
        $hshParamForGetViewForVMachine = @{Property = Write-Output Name Config.Hardware.Device Runtime.Host}
    } ## end begin

    process {
        ## get the VM object(s) (the cool, FaF way using .NET View objects)
        Switch ($PSCmdlet.ParameterSetName) {
            {"NameAsRegEx","NameAsLiteral" -contains $_} {
                $strThisParamSetName = $_
                $hshParamForGetViewForVMachine["ViewType"] = "VirtualMachine"

                ## make a temporary hashtable to be used for creating the Get-View filter string value, and the message for the warning (if any warning)
                $hshParamForNewRegExPattern = Switch ($strThisParamSetName) {
                    "NameAsRegEx" {
                        @{String = $VMName; EscapeAsLiteral = $false}
                        break
                    } ## end case
                    ## if literal, do escape as literal
                    "NameAsLiteral" {
                        @{String = $VMLiteralName; EscapeAsLiteral = $true}
                    } ## end case
                } ## end inner switch
                ## make the actual RegEx pattern for the Get-View filter, joining all values, and escaping if strings are to be literal
                $strVirtualMachineNameFilter = _New-RegExJoinedOrPattern @hshParamForNewRegExPattern
                ## message for warning, if any warning
                $strMessageForWarning = "name pattern '$strVirtualMachineNameFilter'"
                $hshParamForGetViewForVMachine["Filter"] = @{"Name" = $strVirtualMachineNameFilter}
                break
            } ## end case
            "ById" {
                $hshParamForGetViewForVMachine["Id"] = $Id
                $strMessageForWarning = "Id '$Id'"
            } ## end case
        } ## end outer switch
        $arrVMViewsForStorageInfo = Get-View @hshParamForGetViewForVMachine
        if (($arrVMViewsForStorageInfo | Measure-Object).Count -eq 0) {Throw "No VirtualMachine objects found matching $strMessageForWarning"} ## end if

        $arrVMViewsForStorageInfo | Foreach-Object {
            $viewVMForStorageInfo = $_
            ## get the view of the HostSystem on which the VM currently resides
            $viewHostWithStorage = Get-View -Id $viewVMForStorageInfo.Runtime.Host -Property Config.StorageDevice.ScsiLun

            $viewVMForStorageInfo.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualDisk]} | Foreach-Object {
                $hdThisDisk = $_
                $oScsiLun = $viewHostWithStorage.Config.StorageDevice.ScsiLun | Where-Object {$_.UUID -eq $hdThisDisk.Backing.LunUuid}
                ## the properties to return in new object
                $hshThisVMProperties = ([ordered]@{
                    VMName = $viewVMForStorageInfo.Name
                    ## the disk's "name", like "Hard disk 1"
                    HardDiskName = $hdThisDisk.DeviceInfo.Label
                    ## get device's SCSI controller and Unit numbers (1:0, 1:3, etc)
                    ScsiId = &{$strControllerKey = $_.ControllerKey.ToString(); "{0}`:{1}" -f $strControllerKey[$strControllerKey.Length - 1], $_.Unitnumber}
                    DeviceDisplayName = $oScsiLun.DisplayName
                    SizeGB = [Math]::Round($_.CapacityInKB / 1MB, 0)
                    ScsiCanonicalName = $oScsiLun.CanonicalName
                }) ## end hsh
                ## add property for VMDKDStorePath if desired
                if ($ShowVMDKDatastorePath) {$hshThisVMProperties["VMDKDStorePath"] = $hdThisDisk.Backing.Filename}
                New-Object -Type PSObject -Property $hshThisVMProperties
            } ## end foreach-object
        } ## end foreach-object
    } ## end process
} ## end fn



function Invoke-VNEvacuateDatastore {
<#  .Description
    Script to evacuate virtual disks and/or VM config files from a given datastore; does not move the entire VM and all its disks if they reside elsewhere

    .Example
    Invoke-VNEvacuateDatastore -SourceDatastore datastoreToEvac -Destination destinationDatastore -RunAsync -OutVariable arrMyMoveTasks
    Move virtual disks and/or VM config files (if any) from source datastore to the destination datastore, running asynchronously. This also saves the resulting tasks' MoRefs into the output variable $arrMyMoveTasks. One can then check status on these particular tasks like:  Get-Task -Id $arrMyMoveTasks

    .Example
    Invoke-VNEvacuateDatastore -SourceDatastore datastoreToEvac -Destination (Get-DatastoreCluster my_datastoreCluster) -Verbose
    Synchronously and serially moves VM disks and files from source datastore to datastores in given datastore cluster, with a bit of Verbose output

    .Link
    http://vNugglets.com

    .Outputs
    If running asynchronously, returns the VMware.Vim.ManagedObjectReference for each RelocateVM task. Else, returns nothing
#>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param(
        ## The name of the source datastore (the one to evacuate)
        [parameter(Mandatory=$true)][string]$SourceDatastore,

        ## The name of the destination datastore or datastore cluster, or a datastore cluster itself
        [parameter(Mandatory=$true)]$Destination,

        ## Name(s) of VM/template to exclude from evacuation activities (exact name)
        [string[]]$ExcludeVMName,

        ## Switch:  exclude all templates on the source datastore from this evacuation effort?
        [Switch]$ExcludeAllTemplate,

        ## Switch:  Run asynchonously?  If not, this cmdlet runs synchronously, waiting for each virtual disk relocation before starting the next.
        [switch]$RunAsync
    ) ## end parameter

    Begin {
        ## get the datastore View object, either from one of the datastore IDs in the datastorecluster (if passed), or by the datastore that matches the datastore name given
        $arrDestDatastoreView = if ($Destination -is [VMware.VimAutomation.ViCore.Types.V1.DatastoreManagement.DatastoreCluster]) {
            Get-View -Id ($Destination.ExtensionData.ChildEntity) -Property Name
        } else {Get-View -ViewType Datastore -Property Name -Filter @{"Name" = "^${Destination}$"}}
    } ## end begin

    Process {
        ## Set proper variable name from the supplied parameter
        $strSrcDatastore = $SourceDatastore

        ## Get the .NET view of the source datastore
        $viewSrcDatastore = Get-View -ViewType Datastore -Property Name -Filter @{"Name" = "^${strSrcDatastore}$"}
        ## Get the linked view that contains the list of VMs on the source datastore
        $viewSrcDatastore.UpdateViewData("Vm.Config.Files.VmPathName", "Vm.Config.Hardware.Device", "Vm.Config.Template", "Vm.Runtime.Host", "Vm.Name")

        ## Create a VirtualMachineMovePriority object for the RelocateVM task; 0 = defaultPriority, 1 = highPriority, 2 = lowPriority (per http://pubs.vmware.com/vsphere-51/index.jsp?topic=%2Fcom.vmware.wssdk.apiref.doc%2Fvim.VirtualMachine.MovePriority.html)
        $specVMMovePriority = New-Object VMware.Vim.VirtualMachineMovePriority -Property @{"value__" = 1}

        ## For each VM View object, initiate the RelocateVM_Task() method; for each template object, initiate the RelocateVM() method
        $viewSrcDatastore.LinkedView.Vm | Foreach-Object {
            $viewVMToMove = $_
            ## if this machine was to be excluded, do not move its files
            if (($ExcludeAllTemplate -and ($viewVMToMove.Config.Template -eq "True")) -or ($ExcludeVMName -contains $viewVMToMove.Name)) {Write-Verbose -Verbose "not moving files for excluded machine '$($viewVMToMove.Name)'"}
            ## else, doit
            else {
                ## Create a VirtualMachineRelocateSpec object for the RelocateVM task
                $specVMRelocate = New-Object Vmware.Vim.VirtualMachineRelocateSpec
                ## Create an array containing all the virtual disks for the current VM/template
                $arrVirtualDisks = $viewVMToMove.Config.Hardware.Device | Where-Object {$_ -is [VMware.Vim.VirtualDisk]}
                ## If the VM/template's config files reside on the source datastore, set this to the destination datastore (if not specified, the config files are not moved)
                if ($viewVMToMove.Config.Files.VmPathName.Split("]")[0].Trim("[") -eq $strSrcDatastore) {
                    $specVMRelocate.Datastore = ($arrDestDatastoreView | Get-Random).MoRef
                } ## end if

                ## For each VirtualDisk for this VM/template, make a VirtualMachineRelocateSpecDiskLocator object (to move disks that are on the source datastore, and leave other disks on their current datastore)
                ## But first, make sure the VM/template actually has any disks
                if ($arrVirtualDisks) {
                    foreach($oVirtualDisk in $arrVirtualDisks) {
                        $oVMReloSpecDiskLocator = New-Object VMware.Vim.VirtualMachineRelocateSpecDiskLocator -Property @{
                            ## If this virtual disk's filename matches the source datastore name, set the VMReloSpecDiskLocator Datastore property to the destination datastore's MoRef, else, set this property to the virtual disk's current datastore MoRef
                            DataStore = if ($oVirtualDisk.Backing.Filename -match $strSrcDatastore) {($arrDestDatastoreView | Get-Random).MoRef} else {$oVirtualDisk.Backing.Datastore}
                            DiskID = $oVirtualDisk.Key
                        } ## end new-object
                        $specVMRelocate.disk += $oVMReloSpecDiskLocator
                    } ## end foreach
                } ## end if

                if ($PSCmdlet.ShouldProcess("VM '$($viewVMToMove.Name)'", "Relocate files from datastore '$($viewSrcDatastore.Name)', with '$($arrDestDatastoreView.Name -join ", ")' as potential destination")) {
                    ## Determine if template or VM, then perform necessary relocation steps
                    if ($viewVMToMove.Config.Template -eq "True") {
                        ## Gather necessary objects to mark template as a VM (VMHost where template currently resides and default, root resource pool of the cluster)
                        $viewTemplateVMHost = Get-View -Id $_.Runtime.Host -Property Parent
                        $viewTemplateResPool = Get-View -ViewType ResourcePool -Property Name -SearchRoot $viewTemplateVMHost.Parent -Filter @{"Name" = "^Resources$"}
                        ## Mark the template as a VM
                        $_.MarkAsVirtualMachine($viewTemplateResPool.MoRef, $viewTemplateVMHost.MoRef)
                        ## Relocate the template synchronously (i.e. one at a time)
                        Write-Verbose -Verbose "moving template '$($viewVMToMove.Name)' synchronously (template -> VM -> move datastores -> template)"
                        $oThisReloTask_moref = $viewVMToMove.RelocateVM_Task($specVMRelocate, $specVMMovePriority)
                        Write-Verbose "migrate task Id: '$oThisReloTask_moref'"
                        Get-Task -Id $oThisReloTask_moref | Wait-Task
                        ## Convert VM back to template
                        $viewVMToMove.MarkAsTemplate()
                    } ## end if
                    else {
                        ## Initiate the RelocateVM task (asynchronously), if RunAsync switch is $true
                        if ($RunAsync) {$viewVMToMove.RelocateVM_Task($specVMRelocate, $specVMMovePriority)}
                        ## else, invoke the RelocateVM method (synchronously)
                        else {$viewVMToMove.RelocateVM($specVMRelocate, $specVMMovePriority)}
                    } ## end else
                } ## end if
            } ## end else
        } ## end foreach-object
    } ## end process
} ## end fn
