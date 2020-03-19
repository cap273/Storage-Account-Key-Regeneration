<#
    .DESCRIPTION
        Regenerates storage account keys of target Azure storage account.

        Note that an Azure storage account has two keys. This script only regenerates one of the two keys.
        The parameter $keyNumber specifies whether to regenerate the 1st or the 2nd key.

        This PowerSchell script runs as a runbook in an Azure Automation Account, and authenticates to Azure
        through a Service Principal using certificate authentication. This service principal is *not* created
        or configured as part of this script.

        The following modules should have already been imported into the Azure Automation Account for this runbook to execute:
        - Az.Accounts, version >= 1.7.3
        - Az.Storage, version >= 1.13.0

    .NOTES
        AUTHOR: Carlos Patiño
        LASTEDIT: March 19, 2020
#>

param(
    [Parameter(Mandatory=$true)]
    [string]$resourceGroupName,

    [Parameter(Mandatory=$true)]
    [string]$storageAccountName,

    [Parameter(Mandatory=$true)]
    [ValidateSet('1','2')]
    [string]$keyNumber
)

$ErrorActionPreference= "Stop"

$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection"
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

    "Logging in to Azure..."
    Login-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}

# Validate access to the storage account
Write-Output "Getting key names from storage account [$storageAccountName] in resource group [$resourceGroupName]..."
$storageAccountKeyNames = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName).KeyName
Write-Output "Key names acquired. Key 1 Name: [$($storageAccountKeyNames[0])]. Key 2 Name: [$($storageAccountKeyNames[1])]."

# Determine which key to regenerate
if ($keyNumber -eq '1') {$index=0}
elseif ($keyNumber -eq '2') {$index=1}
else {throw "Error: parameter 'keyNumber' is not valid"}

# Regenerate single key
Write-Output "Regenerating key: [$($storageAccountKeyNames[$index])]..."
New-AzStorageAccountKey -ResourceGroupName $resourceGroupName `
    -Name $storageAccountName `
    -KeyName $storageAccountKeyNames[$index]
Write-Output "Key [$($storageAccountKeyNames[$index])] regenerated."