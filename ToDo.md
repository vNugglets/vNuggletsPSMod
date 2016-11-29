### ToDo for vNugglets.Utility PowerShell module

- update function `Get-VNVMHostBrokenUplink` to include:
  - support for virtual distributed switches ("vDS" or "vDSwitches"); currently only supports virtual standard switches ("vSS")
  - support for accepting VMHost ID from pipeline (by property), so that the following works tip top:  
  `Get-Cluster myCluster | Get-VMHost | Get-VNVMHostBrokenUplink`
- update function `Get-VNVMByAddress` to:
  - use `VMware.Vim.SearchIndex` for speed for FindAllByIp (does support wildcard, though)
  - support searching by guest DNS name (also using `VMware.Vim.SearchIndex`, via the `FindAllByDnsName` method)
- update function `Get-VNVMByVirtualPortGroup` to:
  - add support for taking a standard- or distributed virtual portgroup as a parameter (and, from pipeline)





### Doing

\[feat_InitialModuleCreation]
- function-ize the snippets on vNugglets, improving them as suitable

### Done
- improved:
  - `Get-VNVMHostBrokenUplink` -- added more properties to returned object for more easily relating the given vmnic to the VMHost and vSwitch of which it is a part
