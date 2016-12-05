### ToDo for vNugglets.Utility PowerShell module

- add more tests
- update function `Get-VNVMHostBrokenUplink` to include:
  - support for virtual distributed switches ("vDS" or "vDSwitches"); currently only supports virtual standard switches ("vSS")
  - support for accepting VMHost ID from pipeline (by property), so that the following works tip top:  
  `Get-Cluster myCluster | Get-VMHost | Get-VNVMHostBrokenUplink`
- update function `Get-VNVMByAddress` to:
  - use `VMware.Vim.SearchIndex` for speed for FindAllByIp (does support wildcard, though)
  - support searching by guest DNS name (also using `VMware.Vim.SearchIndex`, via the `FindAllByDnsName` method)
- update function `Get-VNVMByVirtualPortGroup` to take a standard- or distributed virtual portgroup as a parameter (and, from pipeline)
- update function `Copy-VNVIRole` to take SourceVIRole as VIRole object, and to accept it from pipeline
- update function `Get-VNVMEVCInfo` to take Cluster object from pipeline
- update function `Get-VNUplinkNicForVM` to give more meaningful VDSwitch identification (currently returns something to the effect of `DvsPortset-1` for the VDSwitch name)
