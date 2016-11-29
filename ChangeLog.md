### ChangeLog for vNugglets.Utility PowerShell module

#### for release v1.x

- created module from many of the juicy snippets/functions that we shared at [vNugglets.com](http://vNugglets.com) over the years
- updated `Copy-VNVIRole` to be a safer function overall by removing old `Invoke-Expression` methodology
- standardized parameter names across cmdlets in the module and expanded some previously truncated/cryptic parameter names (go, usability and discoverability!)
- added/updated "by name regular expression pattern" and "by liternal name string" parameters to several cmdlets
- modernized cmdlets to use capabilities of somewhat newer PowerShell releases (like ordered hashtables) and built-in property return iteration, breaking PowerShell v2.0 compatibility (it's time to upgrade, right?)
- updated cmdlet names to use standard/approved verbs where they were not already in use
- added proper comment-based help to all cmdlets (see PowerShell Help topic `about_Comment_Based_Help`)
