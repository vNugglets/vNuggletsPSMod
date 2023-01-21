# vNugglets.Utility PowerShell Module
[![PSGallery Version](https://img.shields.io/powershellgallery/v/vNugglets.Utility.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/vNugglets.Utility) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/vNugglets.Utility.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/vNugglets.Utility)

Contents:

- [QuickStart](#quickStart)
- [Examples](#examplesSection)
- [ChangeLog](#changelog)

This is the PowerShell module created from the  nugglets from [vNugglets.com](http://vNugglets.com).  This repo is the place where the vNugglets.com code can reside, separate from the blog, for easier/central consumption and collaboration.

Some of the functionality provided by the cmdlets in this module:
- VIRole management (copying/duplicating)
- Finding VMs in inventory by attributes other than "name", like by the guest IP address, by the RDMs it may have, by the virtual portgroup to which it is connected
- Mining VMHost information, like host and peripheral firmware information, HBA WWNs, logical drive information, information about "broken" vmnics
- Establishing VM network to virtual portgroup physical uplink relationship information (which of the active uplinks is VM0 actually currently using?)
- Mining VM information, like standard and RDM disks, EVC setting
- vCenter connection information (in title of PowerShell window)
- Datastore evacuation, template evacuation from VMHosts
- Mining virtual portgroup information (cluster-locations)
- Determining parent/base vSphere object types for use in parameter type-ing in subsequent function development

<a id="quickStart"></a>
### QuickStart
Chomping at the bit to get going with using this module? Of course you are! Go like this:
Find and install the module from the PowerShell Gallery, installing for the Current User only (as specified by `-Scope`)
```PowerShell
Find-Module vNugglets.Utility | Install-Module -Scope CurrentUser
```

<a id="examplesSection"></a>
### Examples
There are examples of some of the usages of the cmdlets in this PowerShell module at the module's GitHub Pages page [https://vNugglets.github.io/vNuggletsPSMod](https://vNugglets.github.io/vNuggletsPSMod/)

### Getting Help
The cmdlets in this module all have proper help, so you can learn and discover just as you would and do with any other legitimate PowerShell module:
- `Get-Command -Module <moduleName>`
- `Get-Help -Full <cmdlet-name>`

<a id="changelog"></a>
### ChangeLog
The [ChangeLog](ChangeLog.md) for this module is, of course, a log of the major changes through the module's hitory.  Enjoy the story.

### Other Notes
#### Manual install if one were so inclined:
- download the module, either from the latest release's .zip file on the [vNugglets.Utility Releases](https://github.com/vNugglets/vNuggletsPSMod/releases) page, or by cloning the project to some local folder with Git via:
  `PS C:\> git clone https://github.com/vNugglets/vNuggletsPSMod.git C:\temp\MyVNuggsRepoCopy`
- put the actual PowerShell module directory in some place that you like to keep your modules, say, like this, which copies the module to your personal Modules directory:
  `PS C:\> Copy-Item -Recurse -Path C:\temp\MyVNuggsRepoCopy\vNugglets.Utility\ -Destination ~\Documents\PowerShell\Modules\vNugglets.Utility`
- import the PowerShell module into the current PowerShell session:
  `PS C:\> Import-Module -Name vNugglets.Utility`
  or, if the vNugglets.Utility module folder is not in your `Env:\PSModulePath`, specify the whole path to the module folder, like:
  `PS C:\> Import-Module -Name \\myserver.dom.com\PSModules\vNugglets.Utility`


A few notes on updates to this repo:

Dec 2016
- initial public release

Nov 2016
- started whole hog on creating PowerShell module to try to contain all of this goodness

Sep 2016
- created repository, populated with first nugglet
