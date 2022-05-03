# Azure Bicep VM

Bicep code file to deploy a Windows or Linux VM to an existing subnet.
No private IP is assigned, therefore Azure Bastion should be used for RDP/SSH access.

Installs development tools via a bash/powershell scripts.

## Parameter file

Many of the parameter values in the bicep code are defaulted.
The mandatory parameters can be provided via a parameters file.
Azure Key Vault references can be used in your parameter file to more securely pass information to the Azure control plane.

EG.

```json
{
    "$schema": "https://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#",
    "contentVersion": "1.0.0.0",
    "parameters": {
        "subnetId": {
            "reference": {
                "keyVault": {
                "id": "/subscriptions//resourceGroups//providers/Microsoft.KeyVault/vaults/"
                },
                "secretName": "SubnetId"
            }
        },
        "adminPassword": {
            "reference": {
                "keyVault": {
                "id": "/subscriptions//resourceGroups//providers/Microsoft.KeyVault/vaults/"
                },
                "secretName": "vmadminpassword"
            }
        },
        "adminUsername": {
            "reference": {
                "keyVault": {
                "id": "/subscriptions//resourceGroups//providers/Microsoft.KeyVault/vaults/"
                },
                "secretName": "vmadminusername"
            }
        }
    }
}

```

## AZ CLI Commands

```powershell
az login --use-device-code
az account set -s your-subscription-name

$rg="your-resource-group"

az group show -g $rg -o table

#Create a windows vm jumpbox
$vmnameseed="winjump"
az deployment group create -g $rg -f ./main.bicep -p ./parameters.json -p resourceNameSeed=$vmnameseed

#Create a linux vm jumpbox
$vmnameseed="ubujump"
az deployment group create -g $rg -f ./main.bicep -p ./parameters.json -p os=Ubuntu2004 resourceNameSeed=$vmnameseed


#Create a windows vm jumpbox in a different subnet
$vmnameseed="winjumpsub"
$subnetId="/subscriptions/###/resourceGroups/###/providers/Microsoft.Network/virtualNetworks/###/subnets/###"
az deployment group create -g $rg -f ./main.bicep -p ./parameters.json -p resourceNameSeed=$vmnameseed subnetId=$subnetId
```
