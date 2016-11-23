## helper functions internal to this module

function _New-RegExJoinedOrPattern {
<#	.Description
	Helper function to take one or more strings and return a "joined" OR string (join values with "|"), and optionally RegEx escaping the input strings if specified
	.Outputs
	String
#>
	param (
		## The string(s) for the regular expression pattern
		[parameter(Mandatory=$true)][String[]]$String,

		## Switch:  escape the string(s) and add expression start/end anchors ("^" and "$")?
		[switch]$EscapeAsLiteral
	) ## end parameter

	process {
		## if RegEx-escaping each string, do so and add line anchors "^" and "$" to each, then join all with "|"
		if ($EscapeAsLiteral) {($String | Foreach-Object {"^{0}$" -f [System.Text.RegularExpressions.Regex]::Escape($_)}) -join "|"}
		## else, just join all as-is with "|"
		else {$String -join "|"}
	} ## end process
} ## end fn



function _Format-AsHexWWNString {
<#	.Description
	Helper function for formatting WWN as hex string with colon-separators
	.Outputs
	String
#>
    param(
		## the WWN in [long] format (not in hex, yet)
    	[parameter(Mandatory=$true)][long]$WWN_long
    )
    ## convert to hex and then create a string with colons separating every two hex characters
    process {(("{0:x}" -f $WWN_long) -split "(\w{2})" | Where-Object {$_ -ne ""}) -join ":"}
} ## end function
