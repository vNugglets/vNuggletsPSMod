### vNugglets.Utility PowerShell module

Some examples and their sample output (see each cmdlet's help for more examples):

#### `Connect-VNVIServer`: Connects to the given vCenters, update window's title bar

```powershell
PS C:\> Connect-VNVIServer -Credential $myCred -Server myVC0.dom.com, myVC1.dom.com
Name                 Port  User
----                 ----  ----
myVC0.dom.com        443   DOM\USER0
myVC1.dom.com        443   DOM\USER0
```

#### `Copy-VNVIRole`: Copy VIRoles from here to there

Copy the VIRole "SysAdm" from the given source vCenter to a new VIRole named "SysAdm_copyTest" in the given destination vCenter

```powershell
PS C:\> Copy-VNVIRole -SourceRoleName SysAdm -DestinationRoleName SysAdm_copyTest -SourceVCName `
>> vcenter.dom.com -DestinationVCName othervcenter.dom.com
Name                 IsSystem
----                 --------
SysAdm_copyTest      False
```

Copy the given VIRole from the given source vCenter to a new VIRole named "SysAdm_copyTest" in the _same_ vCenter

```powershell
PS C:\> Copy-VNVIRole -SourceRoleName MyTestRole0 -DestinationRoleName SomeRole_copyTest `
>> -SourceVCName vcenter.dom.com -DestinationVCName vcenter.dom.com
Name                 IsSystem
----                 --------
SomeRole_copyTest    False
```

#### `Get-VNNetworkClusterInfo`: Get VMware HA Cluster info for a virtual network

Gets information about virtual networks whose names match the (very simple) regular expressions, "101" and "121"

```powershell
PS C:\> Get-VNNetworkClusterInfo -Name 101,234
Name           ClusterName  ClusterId      Type                                    MoRef
----           -----------  ---------      ----                                    -----
my.Portgrp101  myCluster0   ClusterCom...  VMware.Vim.Network                      Network-ne...
my.Portgrp234  myCluster20  ClusterCom...  VMware.Vim.DistributedVirtualPortgroup  Network-ne...
```

Gets information about virtual networks whose names are literally "my.Portgroup0" (not matching "my.Portgroup01"or "test_myXPortgroup0" -- just a literal match only)

```powershell
PS C:\> Get-VNNetworkClusterInfo -LiteralName my.Portgroup0 | ft -a
Name           ClusterName  ClusterId                          Type                MoRef
----           -----------  ---------                          ----                -----
my.Portgroup0  myCluster0   ClusterComputeResource-domain-c94  VMware.Vim.Network  Network-ne...
```

#### `Get-VNUplinkNicForVM`: Get the vmnic uplink used by VMs on given VMHost

Gets the Netports on given VMHost, and returns their client name, uplink vmnic, vSwitch, etc.

```powershell
PS C:\> Get-VNUplinkNicForVM -VMHost myhost0.dom.com -Credential (Get-Credential root)
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
```

#### `Get-VNVMByAddress`: Get VMs by various addresses

Get VMs with given MAC address, return VM name and its MAC addresses

```powershell
PS C:\> Get-VNVMByAddress -MAC 00:50:56:b0:00:01
Name     MacAddress                              MoRef
------   ------------                            -----
myvm0    {00:50:56:b0:00:01,00:50:56:b0:00:18}   VirtualMachine-vm-2155
```

Get VMs with given IP as reported by VMware Tools, return VM name and its IP addresses

```powershell
PS C:\> Get-VNVMByAddress -IP 10.37.31.12
Name     IP                                         MoRef
------   ---                                        -----
myvm10   {192.16.13.1, 10.37.31.12, fe80::000...}   VirtualMachine-vm-13
```

Use `-AddressWildcard` to find VMs with approximate IP

```powershell
PS C:\> Get-VNVMByAddress -AddressWildcard 10.0.0.*
Name           IP                                      MoRef
----           --                                      -----
myvm3          {10.0.0.20, fe80::000:5600:fe00:6007}   VirtualMachine-vm-153
mytestVM001    10.0.0.200                              VirtualMachine-vm-162
```

#### `Get-VNVMByRDM`: Get VMs by RDM

Find VM using the given LUN as an RDM, returning an object with the information about that RDM harddisk on the VM

```powershell
PS C:\> Get-VNVMByRDM -CanonicalName naa.60000112233445501000000000000001 -Cluster someCluster
VMName            : myvm002
HardDiskName      : Hard disk 7
CompatibilityMode : physicalMode
CanonicalName     : naa.60000112233445501000000000000001
DeviceDisplayName : myvm002-logs
MoRef             : VirtualMachine-vm-174
```

Find VMs using the given LUN as an RDM, formatting output in auto-sized table with just the given properties

```powershell
PS C:\> Get-VNVMByRDM -CanonicalName naa.60000112233445501000000000000002 -Cluster someCluster | `
>> ft -a VMName, HardDiskName, DeviceDisplayName, CanonicalName
VMName    HardDiskName  DeviceDisplayName   CanonicalName
------    ----------    -----------------   -------------
myvm0050  Hard disk 10  myMSCluster-quorum  naa.60000112233445501000000000000002
myvm0051  Hard disk 10  myMSCluster-quorum  naa.60000112233445501000000000000002
```

#### `Get-VNVMByVirtualPortGroup`: Get VMs by virtual portgroup

Get networks matching "VLAN19", and get their VMs' names and some other VM information

```powershell
PS C:\> Get-VNVMByVirtualPortGroup -NetworkName VLAN19 | ft VMName,Network,VMHost,Cluster
VMName          Network         VMHost            Cluster
------          -----------     ------            -------
vm0.dom.com     VLAN19.Sekurr   vmhost0.dom.com   myCluster0
vm10.dom.com    VLAN19.Sekurr   vmhost3.dom.com   myCluster0
vm32.dom.com    VLAN19.Sekurr   vmhost2.dom.com   myCluster0
...
```

Get network named exactly "VLAN3", and get its VMs' names and some other VM information

```powershell
PS C:\> Get-VNVMByVirtualPortGroup -NetworkLiteralName VLAN3 | ft -a
VMName   Network  VMHost            Cluster     PowerState   MoRef
------   -------  ------            -------     ----------   -----
myVM0    VLAN3    myVMHost.dom.com  myCluster2  poweredOn    VirtualMachine-vm-142
...
```

#### `Get-VNVMDiskAndRDM`: Get the disks (including RDMs) for VMs

Get the disks (including RDMs) for "someVM". Note, the ScsiCanonicalName property is only valid (and only populated for) RDM disks

```powershell
PS C:\> Get-VM someVM | Get-VNVMDiskAndRDM
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
```

Get the disks (including RDMs) for VMs matching the name regular expression pattern "someVM", formatting output in auto-sized table. Note, the ScsiCanonicalName property is only valid (and only populated for) RDM disks

```powershell
PS C:\>Get-VNVMDiskAndRDM -VMName someVM | ft -a
VMName   HardDiskName ScsiId DeviceDisplayName SizeGB ScsiCanonicalName
------   ------------ ------ ----------------- ------ -----------------
someVM0  Hard disk 1  0:0                          50
someVM0  Hard disk 2  1:0    someVM0-/log_dir      20 naa.60000111111115615641111111111111
someVM1  Hard disk 1  0:0                         180
someVM1  Hard disk 2  1:0    someVM1-/log_dir     120 naa.60000111111115615641111111111112
```

#### `Get-VNVMEVCInfo`: Get VM EVC configuration information for VMs with different EVC mode than the cluster

```powershell
PS C:\> Get-VNVMEVCInfo -Cluster myCluster | Where-Object {$_.VMEVCMode -ne $_.ClusterEVCMode}
Name        PowerState   VMEVCMode   ClusterEVCMode   ClusterName
----        ----------   ---------   --------------   -----------
myvm001     poweredOff               intel-nehalem    myCluster0
myvm100     poweredOff               intel-nehalem    myCluster0
```

#### `Get-VNVMHostBrokenUplink`: Get information for all VMHost's vSSwitches' uplinks (ones used as uplinks, but with no apparent link)

```powershell
PS C:\> Get-VNVMHostBrokenUplink
VMHost            vSwitch   BustedVmnic  BitRatePerSec
------            -------   -----------  -------------
myhost03.dom.com  vSwitch0  vmnic1                   0
myhost22.dom.com  vSwitch5  vmnic7                   0
myhost24.dom.com  vSwitch1  vmnic3                   0
```

#### `Get-VNVMHostFirmwareInfo`: Get some HP VMHosts' firmware information

```powershell
PS C:\> Get-VMHost myhost01.dom.com,myhost02.dom.com | Get-VNVMHostFirmwareInfo
VMHostName   : myhost01.dom.com
SystemBIOS   : HP System BIOS P65 2015-08-16 00:00:00.000
HPSmartArray : HP Smart Array Controller HPSA1 Firmware 6.64
iLOFirmware  : Hewlett-Packard BMC Firmware (node 0) 46:10000 1.88
Model        : ProLiant DL580 G7

VMHostName   : myhost02.dom.com
SystemBIOS   : HP System BIOS P65 2015-08-16 00:00:00.000
HPSmartArray : HP Smart Array Controller HPSA1 Firmware 6.64
iLOFirmware  : Hewlett-Packard BMC Firmware (node 0) 46:10000 1.88
Model        : ProLiant DL580 G7
```

#### `Get-VNVMHostHBAWWN`: Get VMHost HBA WWNs on the quick

```powershell
PS C:\> Get-VMHost myVMHost.dom.com | Get-VMHostHBAWWN
VMHostName        DeviceName  HBAPortWWN               HBANodeWWN               HBAStatus
----------        ----------  ----------               ----------               ---------
myVMHost.dom.com  vmhba2      10:00:00:00:aa:bb:cc:53  20:00:00:00:aa:bb:cc:53  online
myVMHost.dom.com  vmhba3      10:00:00:00:aa:bb:cc:86  20:00:00:00:aa:bb:cc:86  online
```

#### `Get-VNVMHostLogicalVolumeInfo`: Get VMHosts' logical volume information

```powershell
PS C:\>Get-Cluster myCluster0 | Get-VMHost | Get-VNVMHostLogicalVolumeInfo
VMHostName          LogicalVolume
----------          -------------
myhost20.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 136GB : Disk 1,2
myhost21.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 136GB : Disk 1,2
myhost22.dom.com    Logical Volume 1 on HPSA1 : RAID 1 : 279GB : Disk 1,2,3
```

#### `Get-VNVMHostNICFirmwareAndDriverInfo`: Grab NIC driver- and firmware version(s) for NICs on VMHosts

```powershell
PS C:\>Get-Cluster myCluster0 | Get-VMHost | Get-VNVMHostNICFirmwareAndDriverInfo | sort VMHostName
VMHostName         NicDriverVersion        NicFirmwareVersion
----------         ----------------        ------------------
myhost0.dom.com    nx_nic driver 5.0.619   nx_nic device firmware 4.0.588
myhost1.dom.com    nx_nic driver 5.0.619   nx_nic device firmware 4.0.588
myhost2.dom.com    nx_nic driver 5.0.619   nx_nic device firmware 4.0.588
...
```

Other cmdlets in module, for which sample output not provided here:

- `Invoke-VNEvacuateDatastore`
- `Move-VNTemplateFromVMHost`
- `Update-VNTitleBarForPowerCLI`
