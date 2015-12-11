function Resolve-DscConfigurationProperty
{
    <#
        .Synopsis
            Searches DSC ConfigurationData metadata for a property.
        .DESCRIPTION
            Searches DSC ConfigurationData metadata for a property. Getting the value based on this precident:
                $ConfigurationData.AllNodes.Node.Services.Name.PropertyName
                $ConfigurationData.SiteData.SiteName.Services.Name.PropertyName
                $ConfigurationData.Services.Name.PropertyName
                $ConfigurationData.AllNodes.Node.PropertyName
                $ConfigurationData.Sites.Name.PropertyName
                $ConfigurationData.PropertyName

            If -RsolutionBehavior AllValues used then array of values returned.

        .EXAMPLE
            $ConfigurationData = @{
                AllNodes = @(
                    @{
                        Name='Web01'
                        DataSource = 'ValueFromNode'
                        Location = 'NY'
                    },
                    @{
                        Name='Web02'
                        DataSource = 'ValueFromNode'
                    },
                    @{
                        Name='Web03'
                        DataSource = 'ValueFromNode'
                    }

                )
                SiteData = @{
                    NY = @{
                        Services = @{
                            MyTestService = @{
                                DataSource = 'ValueFromSite'
                            }
                        }
                    }
                }
                Services = @{
                    MyTestService = @{
                        Nodes = @('Web01', 'Web03')
                        DataSource = 'ValueFromService'
                    }
                }
            }

            Foreach ($Node in $ConfigurationData.AllNodes) {

                $Node.Name
                Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource -ConfigurationData $ConfigurationData
            }

            Web01
            ValueFromSite
            Web02
            ValueFromNode
            Web03
            ValueFromService
        .EXAMPLE
            $ConfigurationData = @{
                AllNodes = @(
                    @{
                        Name='Web01'
                    },
                    @{
                        Name='Web02'
                    },
                     @{
                        Name='SQL01'
                    }

                )
                SiteData = @{ }
                Services = @{
                    MyTestService = @{
                        Nodes = @('Web[0-9][0-9]')
                        DataSource = 'ValueFromService'
                    }
                }
            }

            Foreach ($Node in $ConfigurationData.AllNodes) {

                $Node.Name
                Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource -ConfigurationData $ConfigurationData -DefaultValue 'ValueFromDefault'
            }


            Web01
            ValueFromService
            Web02
            ValueFromService
            SQL01
            ValueFromDefault
    #>

    [CmdletBinding(DefaultParameterSetName='DefaultOrder')]
    param
    (
        # The current node being evaluated for the specified property.
        [parameter(Mandatory)]
        [System.Collections.Hashtable] $Node,

        # The property that will be checked for.
        [parameter(Mandatory)]
        [string] $PropertyName,

        # If you want to override the default behavior of checking up-scope for configuration data,
        # it can be supplied here.
        [System.Collections.Hashtable] $ConfigurationData,

        # If the specified PropertyName is not found in the hashtable and you specify a default value,
        # that value will be returned.  If the specified PropertyName is not found and you have not specified
        # a default value, the function will throw an error.
        [object] $DefaultValue,

        # By default, all services associated with a Node are checked for the specified Property.
        # If you want to filter this down to specific service(s), pass one or more strings to this parameter.
        # Wildcards are allowed.
        [ValidateNotNullOrEmpty()]
        [string[]] $ServiceName = '*',

        # By default, all results must return just one entry.
        # If you want to fetch values from multiple services or from all scopes,
        # set this parameter to 'OneLevel' or 'AllValues', respectively.
        [ValidateSet('SingleValue', 'OneLevel', 'AllValues')]
        [string] $ResolutionBehavior = 'SingleValue',

        [parameter(ParameterSetName = 'FileOrder')]
        [string] $Path,

        [parameter(ParameterSetName = 'ParameterOrder')]
        [string[]] $OverrideOrder
    )

    Write-Verbose ''
    if ($null -eq $ConfigurationData)
    {
        Write-Verbose ''
        Write-Verbose 'Resolving ConfigurationData'

        $ConfigurationData = $PSCmdlet.GetVariableValue('ConfigurationData')

        if ($ConfigurationData -isnot [hashtable])
        {
            throw 'Failed to resolve ConfigurationData.  Please confirm that $ConfigurationData is property set in a scope above this Resolve-DscConfigurationProperty or passed to Resolve-DscConfigurationProperty via the ConfigurationData parameter.'
        }
    }

    $doGetAllResults = $ResolutionBehavior -eq 'AllValues'

    Write-Verbose "Starting to evaluate $($Node.Name) for PropertyName: $PropertyName and resolution behavior: $ResolutionBehavior"

    switch ($PSCmdlet.ParameterSetName)
    {
        'FileOrder' {
            $ResolutionOrder = @(Get-Content $Path)
        }
        'ParameterOrder' {
            $ResolutionOrder = $OverrideOrder
        }
        default {
            $ResolutionOrder = @('Services', 'AllNodes','SiteData','All')
        }
    }

    foreach ($resolution in $resolutionOrder)
    {
        if ($doGetAllResults -or $Value.count -eq 0)
        {
            $resolved = $null

            if ($Node.ContainsKey('Location'))
            {
                $Site = $Node.Location
            }

            switch ($resolution)
            {
                'All' {
                    Write-Verbose "    Checking Site All"
                    if (Resolve-HashtableProperty -Hashtable $ConfigurationData -PropertyName "SiteData\All\$PropertyName" -Value ([ref] $resolved))
                    {
                        Write-Verbose "        Found Site Value: $resolved"
                        $Value += @($resolved)
                    }

                    Write-Verbose "Value after checking the global is $Value"
                }
                'AllNodes' {
                    Write-Verbose "    Checking Node: $($Node.Name)"

                    if (Resolve-HashtableProperty -Hashtable $Node -PropertyName $PropertyName -Value ([ref] $resolved))
                    {
                        Write-Verbose "        Found Node Value: $resolved"
                        $value += @($resolved)
                    }
                    Write-Verbose "Value after checking the node is $Value"
                }
                'Services' {
                    $Value += @(Get-ServiceValue -Node $Node -ConfigurationData $ConfigurationData -PropertyName $PropertyName -ServiceName $ServiceName -AllValues:$doGetAllResults)
                    Write-Verbose "Value after checking services is $Value"
                }
                default {
                    if ( Resolve-HashtableProperty `
                        -Hashtable $ConfigurationData `
                        -PropertyName "$resolution\$Site\$PropertyName" `
                        -Value ([ref] $resolved) )
                    {
                        $value += $resolved
                    }
                }
            }
        }
    }

    if (($ResolutionBehavior -eq 'SingleValue') -and ($Value.count -gt 1))
    {
        throw "More than one result was returned for $PropertyName for $($Node.Name).  Verify that your property configurations are correct.  If multiples are to be allowed, set -ResolutionBehavior to OneLevel or AllValues."
    }

    if ($Value.count -eq 0)
    {
        if ($PSBoundParameters.ContainsKey('DefaultValue'))
        {
            $Value = $DefaultValue
        }
        else
        {
            throw "Failed to resolve $PropertyName for $($Node.Name).  Please update your node, service, site, or all sites with a default value."
        }
    }

    return $Value
}

Set-Alias -Name 'Resolve-ConfigurationProperty' -Value 'Resolve-DscConfigurationProperty'

function Get-ServiceValue
{
    [CmdletBinding()]
    param
    (
        [hashtable] $Node,
        [string] $PropertyName,
        [hashtable] $ConfigurationData,
        [string[]] $ServiceName = '*',
        [string[]] $ResolutionOrder,
        [switch] $AllValues
    )

    $servicesTable = $ConfigurationData['Services']
    if ($servicesTable -isnot [hashtable]) { return }

    $resolved = $null
    foreach ($keyValuePair in $servicesTable.GetEnumerator())
    {
        $name = $keyValuePair.Key
        $serviceValue = $keyValuePair.Value

        if (-not (ShouldProcessService -ServiceName $name -Service $serviceValue -Filter $ServiceName -Node $node))
        {
            continue
        }

        Write-Verbose "    Checking Service $name"

        $value = @()

        if ($value.Count -eq 0 -or $AllValues)
        {
            Write-Verbose "        Checking Node override for Service $name"
            if (Resolve-HashtableProperty -Hashtable $Node -PropertyName "Services\$name\$PropertyName" -Value ([ref] $resolved))
            {
                $value += $resolved
            }
        }

        if ($value.Count -eq 0 -or $AllValues)
        {
            Write-Verbose "        Checking Site override for Service $name"

            $siteName = $Node.Location
            if (Resolve-HashtableProperty -Hashtable $ConfigurationData -PropertyName "SiteData\$siteName\Services\$name\$PropertyName" -Value ([ref] $resolved))
            {
                $value += $resolved
            }
        }

        if (($value.Count -eq 0 -or $AllValues) -and $serviceValue -is [hashtable])
        {
            Write-Verbose "        Checking Global value for Service $name"
            if (Resolve-HashtableProperty -Hashtable $serviceValue -PropertyName $PropertyName -Value ([ref] $resolved))
            {
                $value += $resolved
            }
        }

        if ($value.Count -gt 0)
        {
            Write-Verbose "        Found Service Value: $value"
            $value
        }

        Write-Verbose "    Finished checking Service $name"
    }
}

function Find-NodeInService
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        # ConfigurationData Node Hashtable
        [hashtable]
        $Node,

        # ConfigurationData Service Node Array
        [String[]]
        $ServiceNodes
    )

    foreach ($serviceNode in $ServiceNodes)
    {
        if ($serviceNode.IndexOfAny('\.$^+?{}[]') -ge 0)
        {
            Write-Verbose   "Checking if Node [$($node.Name)] -match [$serviceNode]"
            if ($node.Name -Match $serviceNode)
            {
               return $true
            }
        }
        elseif ($serviceNode.contains('*'))
        {

            Write-Verbose   "Checking if Node [$($node.Name)] -like [$serviceNode]"
            if ($node.Name -like $serviceNode)
            {
               return $true
            }
        }
        else
        {
            Write-Verbose   "Checking if Node [$($node.Name)] -eq [$serviceNode]"
            if ($node.Name -eq $serviceNode)
            {
               return  $true
            }
        }
    }

    return $false
}

function ShouldProcessService
{
    param (
        [string] $ServiceName,
        [hashtable] $Service,
        [string[]] $Filter = '*',
        [hashtable] $Node
    )

    $isNodeAssociatedWithService = ($Node.Name -and (Find-NodeInService -Node $Node -ServiceNodes $Service.Nodes)) -or
                                   ($Node['MemberOfServices'] -contains $ServiceName)

    if ($isNodeAssociatedWithService)
    {
        foreach ($pattern in $Filter)
        {
            if ($ServiceName -like $pattern)
            {
                return $true
            }
        }
    }

    return $false
}

function Resolve-HashtableProperty
{
    [OutputType([bool])]
    param (
        [hashtable] $Hashtable,
        [string] $PropertyName,
        [ref] $Value
    )

    $properties = $PropertyName -split '\\'
    $currentNode = $Hashtable

    foreach ($property in $properties)
    {
        if ($currentNode -isnot [hashtable] -or -not $currentNode.ContainsKey($property)) { return $false }
        $currentNode = $currentNode[$property]
    }

    $Value.Value = $currentNode
    return $true
}
