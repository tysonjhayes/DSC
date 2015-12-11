Remove-Module 'DscConfiguration' -Force -ErrorAction SilentlyContinue
Import-Module -Name $PSScriptRoot\DscConfiguration.psd1 -Force -ErrorAction Stop

Describe 'how Resolve-DscConfigurationProperty responds' {
    $ConfigurationData = @{
        AllNodes = @();
        SiteData = @{ NY = @{ PullServerPath = 'ConfiguredBySite' } };
        Services = @{};
        Applications = @{};
    }

    Context 'when a node has an override for a site property' {
        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
            PullServerPath = 'ConfiguredByNode'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName 'PullServerPath'

        It "should return the node's override" {
            $result | should be 'ConfiguredByNode'
        }
    }

    Context 'when a node does not override the site property' {
        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName 'PullServerPath'

        It "should return the site's default value" {
            $result | should be 'ConfiguredBySite'
        }
    }

    Context 'when a specific site does not have the property but the base configuration data does' {
        $ConfigurationData.SiteData = @{
            All = @{ PullServerPath = 'ConfiguredByDefault' }
            NY = @{ PullServerPath = 'ConfiguredBySite' }
        }

        $Node = @{
            Name = 'TestBox'
            Location = 'OR'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName 'PullServerPath'

        It "should return the site's default value" {
            $result | should be 'ConfiguredByDefault'
        }
    }

    Context 'When a value is not found in the configuration data' {
        $Node = @{
            Name = 'TestBox'
            Location = 'OR'
        }

        It 'Throws an error if -DefaultValue is not used' {
            { Resolve-DscConfigurationProperty -Node $Node -PropertyName DoesNotExist } | Should Throw
        }

        It 'Does not throw an error if a -DefaultValue is specified' {
            $result = [PSCustomObject] @{ Value = $null }
            $scriptBlock = { $result.Value = Resolve-DscConfigurationProperty -Node $Node -PropertyName DoesNotExist -DefaultValue Default }

            $scriptBlock | Should Not Throw
            $result.Value | Should Be 'Default'
        }
    }
}

Describe 'how Resolve-DscConfigurationProperty (services) responds' {
    $ConfigurationData = @{AllNodes = @(); SiteData = @{} ; Services = @{}; Applications = @{}}

    $ConfigurationData.Services = @{
        MyTestService = @{
            Nodes = @('TestBox')
            DataSource = 'MyDefaultValue'
        }
    }

    Context 'when a default value is supplied for a service and node has a property override' {

        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
            Services = @{
                MyTestService = @{
                    DataSource = 'MyCustomValue'
                }
            }
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource

        It 'should return the override from the node' {
            $result | should be 'MyCustomValue'

        }
    }

    Context 'when a site level override is present' {
        $ConfigurationData.SiteData = @{
            NY = @{
                Services = @{
                    MyTestService = @{
                        DataSource = 'MySiteValue'
                    }
                }
            }
        }
        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource

        It 'should return the override from the site' {
            $result | should be 'MySiteValue'
        }
    }

    Context 'when no node or site level override is present' {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes = @('TestBox')
                DataSource = 'MyDefaultValue'
            }
        }
        $ConfigurationData.SiteData = @{
            All = @{ DataSource = 'NotMyDefaultValue'}
            NY = @{
                Services = @{
                    MyTestService = @{}
                }
            }
        }
        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource

        It 'should return the default value from the service' {
            $result | should be 'MyDefaultValue'

        }
    }

    Context 'when no service default is specified' {

        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
            MissingFromFirstServiceConfig = 'FromNodeWithoutService'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName MissingFromFirstServiceConfig
        It 'should fall back to checking for the parameter outside of Services' {
            $result | should be 'FromNodeWithoutService'
        }
    }

    Context 'When multiple services exist, but only one contains the desired property' {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes = @('TestBox')
            }
            MySecondTestService = @{
                Nodes = @('TestBox')
                MissingFromFirstServiceConfig = 'FromSecondServiceConfig'
            }
        }
        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName MissingFromFirstServiceConfig

        It 'should retrieve the parameter from the second service' {
            $result | should be 'FromSecondServiceConfig'
        }
    }

    Context 'When a service-to-node relationship is defined from the Node instead of the Service' {
        $ConfigurationData.Services = @{
            MyTestService = @{
                MyTestKey = 'From MyTestService'
            }
        }

        $Node = @{
            Name = 'TestBox'
            Location = 'NY'
            MemberOfServices = 'MyTestService'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName MyTestKey

        It 'Should still resolve data from the service' {
            $result | Should Be 'From MyTestService'
        }
    }
}

Describe 'Resolving multiple values' {
    $ConfigurationData = @{
        AllNodes = @();

        Services = @{
            TestService1 = @{
                ServiceLevel1 = @{
                    Property = 'Service Value'
                }

                NodeLevel1 = @{
                    Property = 'Service Value'
                }

                Nodes = @(
                    'TestNode'
                )
            }

            TestService2 = @{
                ServiceLevel1 = @{
                    Property = 'Service Value'
                }

                NodeLevel1 = @{
                    Property = 'Service Value'
                }

                Nodes = @(
                    'TestNode'
                )
            }

            BogusService = @{
                ServiceLevel1 = @{
                    Property = 'Should Not Resolve'
                }

                Nodes = @()
            }
        }

        SiteData = @{
            All = @{
                NodeLevel1 = @{
                    Property = 'Global Value'
                }
            }

            NY = @{
                NodeLevel1 = @{
                    Property = 'Site Value'
                }
            }
        }
    }

    $Node = @{
        Name = 'TestNode'
        Location = 'NY'

        NodeLevel1 = @{
            Property = 'Node Value'
        }
    }

    It 'Throws an error if multiple services return a value and command is using default behavior' {
        $scriptBlock = { Resolve-DscConfigurationProperty -Node $Node -PropertyName 'ServiceLevel1\Property' }
        $scriptBlock | Should Throw 'More than one result was returned'
    }

    It 'Returns the proper results for multiple services' {
        $scriptBlock = { Resolve-DscConfigurationProperty -Node $Node -PropertyName 'ServiceLevel1\Property' -ResolutionBehavior OneLevel }
        $scriptBlock | Should Not Throw

        $result = (& $scriptBlock) -join ', '
        $result | Should Be 'Service Value, Service Value'
    }

    It 'Returns the property results for all scopes' {
        $scriptBlock = { Resolve-DscConfigurationProperty -Node $Node -PropertyName 'NodeLevel1\Property' -ResolutionBehavior AllValues }
        $scriptBlock | Should Not Throw

        $result = (& $scriptBlock) -join ', '
        $result | Should Be 'Service Value, Service Value, Node Value, Site Value, Global Value'
    }
}

Describe -Name 'how Resolve-DscConfigurationProperty (services with REGEX and Wildcard) responds' -Fixture {
    $ConfigurationData = @{
        AllNodes     = @()
        SiteData     = @{}
        Services     = @{}
        Applications = @{}
    }

    $Node = @{
        Name     = 'TestBox'
        Location = 'NY'
    }

    Context -Name 'WhenNode list contains a WildCard' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('Test*')
                DataSource = 'MyDefaultValue'
            }
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource

        It -name 'should return the default value from the service' -test {
            $result | Should be 'MyDefaultValue'
        }
    }

    Context -Name 'When Node list contains a REGEX (Box$)' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('Box$')
                DataSource = 'ServiceValue'
            }
        }
        $Node = @{
            Name     = 'TestBox'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource  -DefaultValue 'DefaultIfNotFound'

        It -name 'should return the value from the service' -test {
            $result | Should be 'ServiceValue'
        }
        It -name 'should NOT return the DefaultValue from Resolve-DscConfigurationProperty' -test {
            $result | Should NOT be 'DefaultIfNotFound'
        }
    }

    Context -Name 'When Node list contains a REGEX (TestBox\d{2}$)' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('TestBox\d{2}$')
                DataSource = 'ServiceValue'
            }
        }
        $Node = @{
            Name     = 'TestBox03'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource  -DefaultValue 'DefaultIfNotFound'

        It -name 'should return the value from the service' -test {
            $result | Should be 'ServiceValue'
        }
        It -name 'should NOT return the DefaultValue from Resolve-DscConfigurationProperty' -test {
            $result | Should NOT be 'DefaultIfNotFound'
        }
    }

    Context -Name 'When Node list contains a REGEX (TestBox[0-9][0-9])' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('TestBox[0-9][0-9]')
                DataSource = 'ServiceValue'
            }
        }
        $Node = @{
            Name     = 'TestBox03'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource  -DefaultValue 'DefaultIfNotFound'

        It -name 'should return the value from the service' -test {
            $result | Should be 'ServiceValue'
        }
        It -name 'should NOT return the DefaultValue from Resolve-DscConfigurationProperty' -test {
            $result | Should NOT be 'DefaultIfNotFound'
        }
    }

    Context -Name 'When Node list contains a REGEX ([^(\-hv|\-hv4)]$) and Name TestBox03' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('[^(\-hv|\-hv4)]$')
                DataSource = 'ServiceValue'
            }
        }
        $Node = @{
            Name     = 'TestBox03'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource  -DefaultValue 'DefaultIfNotFound'

        It -name 'should return the value from the service' -test {
            $result | Should be 'ServiceValue'
        }
        It -name 'should NOT return the DefaultValue from Resolve-DscConfigurationProperty' -test {
            $result | Should NOT be 'DefaultIfNotFound'
        }
    }

    Context -Name 'When Node list contains a REGEX ([^(\-hv|\-hv4)]$) and Name TestBox-HV4' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('[^(\-hv|\-hv4)]$')
                DataSource = 'ServiceValue'
            }
        }
        $Node = @{
            Name     = 'TestBox-HV4'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource  -DefaultValue 'DefaultIfNotFound'

        It -name 'should return the value from the service' -test {
            $result | Should NOT be 'ServiceValue'
        }
        It -name 'should NOT return the DefaultValue from Resolve-DscConfigurationProperty' -test {
            $result | Should be 'DefaultIfNotFound'
        }
    }

    Context -Name 'When Node list contains a REGEX (^TestBox\d{2}$)' -Fixture {
        $ConfigurationData.Services = @{
            MyTestService = @{
                Nodes      = @('^TestBox\d{2}$')
                DataSource = 'ServiceValue'
            }
        }
        $Node = @{
            Name     = 'TestBox02'
            Location = 'NY'
        }

        $result = Resolve-DscConfigurationProperty -Node $Node -PropertyName DataSource  -DefaultValue 'DefaultIfNotFound'

        It -name 'should return the value from the service' -test {
            $result | Should be 'ServiceValue'
        }
        It -name 'should NOT return the DefaultValue from Resolve-DscConfigurationProperty' -test {
            $result | Should NOT be 'DefaultIfNotFound'
        }
    }
}

Describe 'how Resolve-DscConfigurationProperty responds to new ordering overrides' {
    $ConfigurationData = @{
        AllNodes = @();

        Services = @{
            TestService1 = @{
                ServiceLevel1 = @{
                    Property = 'Service Value'
                }

                NodeLevel1 = @{
                    Property = 'Service Value'
                }

                Nodes = @(
                    'TestNode'
                )
            }

            TestService2 = @{
                ServiceLevel1 = @{
                    Property = 'Service Value'
                }

                NodeLevel1 = @{
                    Property = 'Service Value'
                }

                Nodes = @(
                    'TestNode'
                )
            }

            BogusService = @{
                ServiceLevel1 = @{
                    Property = 'Should Not Resolve'
                }

                Nodes = @()
            }
        }

        SiteData = @{
            All = @{
                NodeLevel1 = @{
                    Property = 'Global Value'
                }
            }

            NY = @{
                NodeLevel1 = @{
                    Property = 'Site Value'
                }
            }
        }

        Applications = @{
            NY = @{
                NodeLevel1 = @{
                    Property = 'App Value'
                }
            }
        }
    }

    $Node = @{
        Name = 'TestNode'
        Location = 'NY'

        NodeLevel1 = @{
            Property = 'Node Value'
        }
    }

    Context 'Override Order is modified but is just the default scopes' {
        It 'Returns the property results for all default scopes' {
            $scriptBlock = { Resolve-DscConfigurationProperty -Node $Node -PropertyName 'NodeLevel1\Property' -ResolutionBehavior AllValues -OverrideOrder @('AllNodes','Services','All', 'SiteData') }
            $scriptBlock | Should Not Throw

            $result = (& $scriptBlock) -join ', '
            $result | Should Be 'Node Value, Service Value, Service Value, Global Value, Site Value'
        }
    }

    Context 'New Properties are Added to Override Order' {
        It 'Returns the property results for all scopes, including new ones' {
            $scriptBlock = { Resolve-DscConfigurationProperty -Node $Node -PropertyName 'NodeLevel1\Property' -ResolutionBehavior AllValues -OverrideOrder @('AllNodes','Services','All', 'SiteData', 'Applications') }
            $scriptBlock | Should Not Throw

            $result = (& $scriptBlock) -join ', '
            $result | Should Be 'Node Value, Service Value, Service Value, Global Value, Site Value, App Value'
        }
    }

    Context 'New properties are added and the default value is different' {
        It 'Returns the property results for a single scope' {
            $scriptBlock = { Resolve-DscConfigurationProperty -Node $Node -PropertyName 'NodeLevel1\Property' -ResolutionBehavior:SingleValue -OverrideOrder @('Applications','AllNodes','Services','All', 'SiteData') }
            $scriptBlock | Should Not Throw

            $result = (& $scriptBlock)
            $result | Should Be 'App Value'
        }
    }
}


# Describe 'how Resolve-DscConfigurationProperty does some stuff' {
#         $ConfigurationData = @{
#         AllNodes = @();

#         Services = @{
#             TestService1 = @{
#                 ServiceLevel1 = @{
#                     Property = 'Service Value'
#                 }

#                 NodeLevel1 = @{
#                     Property = 'Service Value'
#                 }

#                 Nodes = @(
#                     'TestNode'
#                 )
#             }

#             TestService2 = @{
#                 ServiceLevel1 = @{
#                     Property = 'Service Value'
#                 }

#                 NodeLevel1 = @{
#                     Property = 'Service Value'
#                 }

#                 Nodes = @(
#                     'TestNode'
#                 )
#             }

#             BogusService = @{
#                 ServiceLevel1 = @{
#                     Property = 'Should Not Resolve'
#                 }

#                 Nodes = @()
#             }
#         }

#         SiteData = @{
#             All = @{
#                 NodeLevel1 = @{
#                     Property = 'Global Value'
#                 }
#             }

#             NY = @{
#                 NodeLevel1 = @{
#                     Property = 'Site Value'
#                 }
#             }
#         }

#         Applications = @{
#             NY = @{
#                 NodeLevel1 = @{
#                     Property = 'App Value'
#                 }
#             }
#         }
#     }

#     Context 'Some Context' {
#         It 'Should do something useful' {
#             $false | should be $true
#         }
#     }
# }
