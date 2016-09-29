# PowerShell
PowerShell nugglets from [vNugglets.com](http://vNugglets.com).  This repo is meant to be a place where the vNugglets.com code can reside, separate from the blog, for easier/central consumption and collaboration.

Tips:

- files of naming pattern `Verb-Noun.ps1` are meant to be called as-is, and generally take parameters
- the `Verb-Noun.ps1` files include help, too, and so you can get the help on a given file like:
    `Get-Help -Full Verb-Noun.ps1`
- files of naming pattern `fn_SomeDescriptionHere.ps1` contain one or more function definitions, and you would dot-source them in order to bring those function definitions into your current PowerShell session, like:  
    `. drive:\path\to\fn_SomeDescriptionHere.ps1`
    (these are not quite module-worthy, and are designed for you to consume by dot-sourcing)

Inventory of nugglets in this repo:

Name|Added|Description
----|-----|-----------
<a id="inv_Get-VNNetworkClusterInfo.ps1"></a>Get-VNNetworkClusterInfo.ps1|29 Sep 2016|Get information about the VMware HA Cluster(s) in which the given virtual network (virtual portgroup) is defined


A few notes on updates to this repo:

Sep 2016
- created repository, populated with first nugglet, [`Get-VNNetworkClusterInfo.ps1`](#inv_Get-VNNetworkClusterInfo.ps1)
