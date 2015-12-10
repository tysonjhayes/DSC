function Resolve-DscConfigurationDataPath {
    param
    (
        [parameter()]
        [string]
        $Path
    )

    if ( -not ($psboundparameters.containskey('Path')) ) {
        if ([string]::isnullorempty($script:ConfigurationDataPath)) {
            if (test-path $env:ConfigurationDataPath) {
                $path = $env:ConfigurationDataPath
            }
        }
        else {
            $path = $script:ConfigurationDataPath
        }
    }

    if ( -not ([string]::isnullorempty($path)) ) {
        Set-DscConfigurationDataPath -path $path
    }
}
Set-Alias -Name 'Resolve-ConfigurationDataPath' -Value 'Resolve-DscConfigurationDataPath'
