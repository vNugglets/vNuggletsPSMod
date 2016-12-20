\[feat_UpdateCmdlets]:

- added function `Find-VNVMWithDuplicateMACAddress` for finding duplicate VM NIC MAC address in vCenter
- updated function `Get-VNVMEVCInfo` to take Cluster object from pipeline, and to take VM object instead of VMId (far better usability)


\[feat_InitialModuleCreation]

- function-ize the snippets on vNugglets, improving them as suitable
- improved:
  - `Get-VNVMHostBrokenUplink` -- added more properties to returned object for more easily relating the given vmnic to the VMHost and vSwitch of which it is a part
- added about_vNugglets.Utility help topic
