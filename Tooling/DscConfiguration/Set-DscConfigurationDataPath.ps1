function Set-DscConfigurationDataPath {
    param (
        [parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
    )
    $script:ConfigurationDataPath = (Resolve-Path $Path).Path
}
Set-Alias -Name 'Set-ConfigurationDataPath' -Value 'Set-DscConfigurationDataPath'
