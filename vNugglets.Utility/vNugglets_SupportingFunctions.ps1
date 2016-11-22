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
