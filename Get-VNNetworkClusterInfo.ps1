<#    .Description
    Get information about the VMware HA Cluster(s) in which the given virtual network (virtual portgroup) is defined. May 2015

    .Synopsis
    Get VMware HA Cluster info for a virtual network

    .Example
    Get-VNNetworkClusterInfo.ps1 101,234
    Name           ClusterName  ClusterId           Type                                    MoRef
    ----           -----------  ---------           ----                                    -----
    my.Portgrp101  myCluster0   ClusterCom...n-c94  VMware.Vim.Network                      Network-network-3588
    my.Portgrp234  myCluster20  ClusterCom...n-c99  VMware.Vim.DistributedVirtualPortgroup  Network-network-4687

    Gets information about virtual networks whose names match the (very simple) regular expressions, "101" and "121", returning an object for each matching network with network name and cluster name/ID properties

    .Example
    Get-VNNetworkClusterInfo.ps1 -LiteralName my.Portgroup0 | ft -a
    Name           ClusterName  ClusterId                          Type                MoRef
    ----           -----------  ---------                          ----                -----
    my.Portgroup0  myCluster0   ClusterComputeResource-domain-c94  VMware.Vim.Network  Network-network-3588

    Gets information about virtual networks whose names are literally "my.Portgroup0" (not matching "my.Portgroup01" or "test_myXPortgroup0" -- just a literal match only), returning an object with network name and cluster name/ID properties

    .Link
    http://vNugglets.com

    .Notes
    This code also gives a nice example of using LinkedViews in .NET View objects to most quickly/efficiently get information about related objects in the vSphere environment.

    .Inputs
    String -- network (virtual portgroup) name pattern(s) or literal name(s)

    .Outputs
    System.Management.Automation.PSCustomObject
#>

[CmdletBinding(DefaultParameterSetName="NameAsRegEx")]
[OutputType([System.Management.Automation.PSCustomObject])]
Param (
    ## Name pattern of virtual network for which to get information. This is a regular expression
    [parameter(ParameterSetName="NameAsRegEx",Position=1)][String[]]$Name,

    ## Literal name of virtual network for which to get information.  This RegEx-escapes the string and adds start/end anchors ("^" and "$") so that the only match is an exact match
    [parameter(ParameterSetName="NameAsLiteral",Position=1)][String[]]$LiteralName
) ## end param

process {
    $strNetworkNameFilter = Switch ($PsCmdlet.ParameterSetName) {
        "NameAsRegEx" {$Name -join "|"}
        ## if literal, RegEx escape the string and add start/end anchors
        "NameAsLiteral" {($LiteralName | Foreach-Object {"^{0}$" -f [System.Text.RegularExpressions.Regex]::Escape($_)}) -join "|"}
    } ## end switch

    Get-View -ViewType Network -Property Name,Host -Filter @{Name = $strNetworkNameFilter} | Foreach-Object {
        ## get the updated View data for the network's hosts' parent's name
        $_.UpdateViewData("Host.Parent.Name")
        New-Object -Type PSObject -Property ([ordered]@{
            Name = $_.Name
            ## the name(s) of the cluster(s) in which this network is defined
            ClusterName = $_.LinkedView.Host.LinkedView.Parent.Name | Select-Object -Unique
            ## the ID(s) of the cluster(s) in which this network is defined
            ClusterId = $_.LinkedView.Host.LinkedView.Parent.MoRef | Select-Object -Unique
            Type = ($_ | Get-Member).TypeName | Select-Object -Unique
            ## the network's MoRef (for ease of getting the exact network object subsequently)
            MoRef = $_.MoRef
        })
    } ## end foreach-object
} ## end process