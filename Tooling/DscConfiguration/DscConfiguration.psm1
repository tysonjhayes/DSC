param
(
    [string]
    $ConfigurationDataPath,

    [string]
    $LocalCertificateThumbprint
)

if ([string]::IsNullOrEmpty($LocalCertificateThumbprint))
{
    try
    {
        $LocalCertificateThumbprint = (Get-DscLocalConfigurationManager -ErrorAction Stop).CertificateId
    }
    catch { }
}

if ($LocalCertificateThumbprint)
{
    $LocalCertificatePath = "cert:\LocalMachine\My\$LocalCertificateThumbprint"
}
else
{
    $LocalCertificatePath = ''
}

# $ConfigurationData = @{AllNodes=@(); Credentials=@{}; Applications=@{}; Services=@{}; SiteData =@{}}

. $psscriptroot\Get-Hashtable.ps1
. $psscriptroot\Test-LocalCertificate.ps1

. $psscriptroot\New-ConfigurationDataStore.ps1
. $psscriptroot\New-DscNodeMetadata.ps1

. $psscriptroot\Get-DscConfigurationData.ps1
. $psscriptroot\Get-CredentialConfigurationData.ps1
. $psscriptroot\Get-DscEncryptedPassword.ps1

. $psscriptroot\Add-DscEncryptedPassword.ps1
. $psscriptroot\Import-DscCredentialFile.ps1
. $psscriptroot\Export-DscCredentialFile.ps1
. $psscriptroot\ConvertFrom-EncryptedFile.ps1
. $psscriptroot\ConvertTo-CredentialLookup.ps1
. $psscriptroot\New-Credential.ps1
. $psscriptroot\Remove-PlainTextPassword.ps1
. $psscriptroot\Get-DscConfigurationDataPath.ps1
. $psscriptroot\Set-DscConfigurationDataPath.ps1
. $psscriptroot\Resolve-DscConfigurationDataPath.ps1
. $psscriptroot\Set-DscConfigurationCertificate.ps1
. $psscriptroot\Get-DscConfigurationCertificate.ps1
. $psscriptroot\Resolve-DscConfigurationProperty.ps1
. $psscriptroot\Test-DscConfigurationPropertyExists.ps1
