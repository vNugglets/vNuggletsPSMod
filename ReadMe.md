# vNugglets PowerShell Module
This is the PowerShell module created from the  nugglets from [vNugglets.com](http://vNugglets.com).  This repo is meant to be a place where the vNugglets.com code can reside, separate from the blog, for easier/central consumption and collaboration.

Some of the functionality provided by the cmdlets in this module:
- VIRole management (copying/duplicating)
- Finding VMs in inventory by attributes other than "name", like by the guest IP address, by the RDMs it may have, by the virtual portgroup to which it is connected
- Mining VMHost information, like host and peripheral firmware information, HBA WWNs, logical drive information, information about "broken" vmnics
- Establishing VM network to virtual portgroup physical uplink relationship information (which of the active uplinks is VM0 actually currently using?)
- Mining VM information, like standard and RDM disks, EVC setting
- vCenter connection information (in title of PowerShell window)
- Datastore evacuation, template evacuation from VMHosts
- Mining virtual portgroup information (cluster-locations)


The cmdlets in this module all have proper help, so you can learn and discover just as you would and do with any other legitimate PowerShell module:  
- `Get-Command -Module <moduleName>`
- `Get-Help -Full <cmdlet-name>`

A few notes on updates to this repo:

Nov 2016
- started whole hog on creating PowerShell module to try to contain all of this goodness

Sep 2016
- created repository, populated with first nugglet
