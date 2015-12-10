function Get-DscConfigurationData
{
    [cmdletbinding(DefaultParameterSetName='NoFilter')]
    param (
        [parameter()]
        [ValidateNotNullOrEmpty()]
        [string] $Path,

        [ValidateNotNullOrEmpty()]
        [string] $CertificateThumbprint,

        # [parameter(ParameterSetName = 'NameFilter')]
        # [string] $Name,

        # [parameter(ParameterSetName = 'NodeNameFilter')]
        # [string] $NodeName,

        [parameter()]
        [switch] $Force
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
        if (($script:ConfigurationData -eq $null) -or $force)
        {
            $nodeNames = Get-ChildItem -Path $Path -Directory | ForEach-Object {$_.Name} | Where-Object {$_.Name -ne 'Configuration'}

            $script:ConfigurationData = $null

            foreach ($name in $nodeNames)
            {
                $script:ConfigurationData += @{$Name = @{}}
            }
        }

        foreach ($key in $script:ConfigurationData.Keys)
        {
            if ($key -eq 'Credentials')
            {
                $credPath = Join-Path -Path $script:ConfigurationDataPath -ChildPath "$key\*.psd1.encrypted"
                foreach ($item in (Get-ChildItem $credPath))
                {
                    $storeName = $item.Name -replace '\.encrypted' -replace '\.psd1'
                    $script:ConfigurationData.$key.Add($storeName,(Get-DscEncryptedPassword -StoreName $storeName))
                }
            }
            else
            {
                $nodePath = Join-Path -Path $script:ConfigurationDataPath -ChildPath "$key\*.psd1"
                foreach ( $item in (Get-ChildItem $nodePath) )
                {
                    Write-Verbose "Loading data for site $($item.basename) from $($item.fullname)."
                    $script:ConfigurationData.$key.Add($item.BaseName, (Get-Hashtable $item.FullName))
                }
            }
        }

        $breakvar = $true;
        return $script:ConfigurationData
    }
}

Set-Alias -Name 'Get-ConfigurationData' -Value 'Get-DscConfigurationData'
