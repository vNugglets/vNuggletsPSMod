### ChangeLog for vNugglets.Utility PowerShell module

#### Release v1.0

- created module from many of the juicy snippets/functions that we shared at [vNugglets.com](http://vNugglets.com) over the years
- updated `Copy-VNVIRole` to be a safer function overall by removing old `Invoke-Expression` methodology
- standardized parameter names across cmdlets in the module and expanded some previously truncated/cryptic parameter names (go, usability and discoverability!)
- added/updated "by name regular expression pattern" and "by liternal name string" parameters to several cmdlets
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
