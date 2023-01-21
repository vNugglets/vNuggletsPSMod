### ChangeLog for vNugglets.Utility PowerShell module

#### v1.3, released 21 Jan 2023

- \[new] added function `Get-VNInventoryType` for getting more future-safer vSphere object types (follwing guidance from VMware)

#### v1.2, released 18 Jun 2017

- \[improvement] updated function `Get-VNVMByAddress`:
  - greatly increased speed by using `VMware.Vim.SearchIndex` for by-IP searches (`SearchIndex` search methods do not support wildcard, though, so getting VM by wildcard address still uses slower mechanism); example speed increase for searching for VM by specific IP: went from 13s to about 0.25s in a vCenter with about 7,500 VMs -- woo-hoo!
  - added new parameters `-GuestHostname` and `-UUID` to support for searching by guest DNS name or VM BIOS UUID, respectively (these also use methods of `VMware.Vim.SearchIndex` object, so the searches are super fast)
- \[improvement] updated function `Copy-VNVIRole`:
  - takes new parameter, `-SourceRole`, for passing VIRole object itself as value, and this parameter accepts value from pipeline, for more natural use of cmdlet
  - deduces source vCenter server from `-SourceRole` value, simplifying use of cmdlet (no need to specify `-SourceVCName` parameter when providing the source VIRole object)
  - `-DestinationVCName` parameter now optional, further simplifying use of cmdlet; if parameter not specified, destination vCenter will be the same as the source vCenter
- \[internal improvement] updated module prepartion to use `Update-ModuleManifest` for keeping module manifest in shape
  - added manifest entries for tags and for URIs for project, release notes, license, etc.
  - prepared for publishing to the [PowerShellGallery](https://www.powershellgallery.com/))


#### v1.1, released 20 Dec 2016

- \[new] added function `Find-VNVMWithDuplicateMACAddress` for finding duplicate VM NIC MAC address in vCenter
- \[improvement] updated function `Get-VNVMEVCInfo` to take Cluster object from pipeline, and to take VM object instead of VMId (far better usability)

#### v1.0, released 05 Dec 2016

- created module from many of the juicy snippets/functions that we shared at [vNugglets.com](http://vNugglets.com) over the years
- updated `Copy-VNVIRole` to be a safer function overall by removing old `Invoke-Expression` methodology
- standardized parameter names across cmdlets in the module and expanded some previously truncated/cryptic parameter names (go, usability and discoverability!)
- added/updated "by name regular expression pattern" and "by literal name string" parameters to several cmdlets
- modernized cmdlets to use capabilities of somewhat newer PowerShell releases (like ordered hashtables) and built-in property return iteration, breaking PowerShell v2.0 compatibility (it's time to upgrade, right?)
- updated `Invoke-VNEvacuateDatastore`:
  - added feature that uses any/all datastores in datastore cluster (when specifying a datastore cluster for Destination parameter value) for potential destination _per object_ (this allows for a potentially different datastore for each virtual disk on a VM)
  - added ability to exclude a VM/template's files from evacuation process (via parameter)
  - added `-WhatIf` support
- updated cmdlet names to use standard/approved verbs where they were not already in use. Renamed functions/snippets as follows:
  - `Get-VNVMByRDM` was "Get-VMWithGivenRDM"
  - `Get-VNVMByVirtualPortGroup` was "Get-VMOnNetworkPortGroup"
  - `Get-VNVMHostBrokenUplink` was "Get-BustedVmnic"
  - `Invoke-VNEvacuateDatastore` was "Evacuate-Datastore"
- started writing the Pester tests for the cmdlets (many more to go, still)
- added proper comment-based help to all cmdlets (as described in PowerShell Help topic `about_Comment_Based_Help`)
- included "about" help topic, `about_vNugglets.Utility`
