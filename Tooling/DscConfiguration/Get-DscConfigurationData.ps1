function Get-DscConfigurationData
{
    [cmdletbinding(DefaultParameterSetName='NoFilter')]
    param (
        [parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateNotNullOrEmpty()]
        [string] $CertificateThumbprint,

        [parameter(ParameterSetName = 'NameFilter')]
        [string] $Name,

        [parameter(ParameterSetName = 'NodeNameFilter')]
        [string] $NodeName
    )

    begin {
        $ResolveConfigurationDataPathParams = @{}
        if ($psboundparameters.containskey('path'))
        {
            $ResolveConfigurationDataPathParams.Path = $path
        }

        Resolve-DscConfigurationDataPath @ResolveConfigurationDataPathParams

        if ($CertificateThumbprint)
        {
            Set-DscConfigurationCertificate -CertificateThumbprint $CertificateThumbprint
        }
    }
    end
    {
        # Filter out Configuration as we read it in else where.
        $nodeNames = Get-ChildItem -Path $Path -Directory | ForEach-Object {$_.Name} | Where-Object {$_ -ne 'Configuration'}

        $script:ConfigurationData = @{}

        foreach ($key in $nodeNames)
        {
            $nodePath = Join-Path -Path $script:ConfigurationDataPath -ChildPath "$key\*.psd1"

            switch ($key)
            {
                'Credentials' {
                    $credPath = Join-Path -Path $script:ConfigurationDataPath -ChildPath "$key\*.psd1.encrypted"

                    $credentials = @{}
                    foreach ($item in (Get-ChildItem $credPath))
                    {
                        $storeName = $item.Name -replace '\.encrypted' -replace '\.psd1'
                        $credentials.Add($storeName,(Get-DscEncryptedPassword -StoreName $storeName))
                    }

                    $script:ConfigurationData.Add($key, $credentials)
                }
                'AllNodes' {
                    $script:ConfigurationData.Add('AllNodes',@(
                        Get-ChildItem $nodePath |
                        Get-Hashtable |
                        ForEach-Object {
                            Write-Verbose "Adding Node: $($_.Name)"
                            $_
                        })
                    )
                }
                default {
                    $defaultHash = @{}
                    foreach ( $item in (Get-ChildItem $nodePath) )
                    {
                        Write-Verbose "Loading data for site $($item.BaseName) from $($item.FullName)."
                        $defaultHash.Add($item.BaseName, (Get-Hashtable $item.FullName))
                    }

                    $script:ConfigurationData.Add($key, $defaultHash)
                }
            }
        }

        Write-Verbose 'Checking for filters of AllNodes.'
        switch ($PSCmdlet.ParameterSetName)
        {
            'NameFilter' {
                Write-Verbose "Filtering for nodes with the Name $Name"
                $script:ConfigurationData.AllNodes = $script:ConfigurationData.AllNodes.Where({$_.Name -like $Name})
            }
            'NodeNameFilter' {
                Write-Verbose "Filtering for nodes with the GUID of $NodeName"
                $script:ConfigurationData.AllNodes = $script:ConfigurationData.AllNodes.Where({$_.NodeName -like $NodeName})
            }
            default {
            }
        }

        return $script:ConfigurationData
    }
}

Set-Alias -Name 'Get-ConfigurationData' -Value 'Get-DscConfigurationData'
