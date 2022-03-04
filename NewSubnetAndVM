//Creates a new subnet and GitHub runner VM
//This bicep is derived from https://github.com/Gordonby/AzureBicepVM/blob/main/main.bicep

param location string = resourceGroup().location
param resourceName string

@description('The local admin username')
param adminUsername string

@secure()
@description('The local admin password')
param adminPassword string

param vnetName string
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' existing = {
  name:vnetName
}

param runnerSubnetAddressPrefix string =  '10.10.4.0/24'
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-05-01' = {
  name: 'runnersubnet'
  parent: vnet
  properties: {
    addressPrefix: runnerSubnetAddressPrefix
  }
}

param nicName string ='nic-01-vm${resourceName}'
resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnet.id
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableAcceleratedNetworking: true
  }
}

param vmName string ='vm-${resourceName}'
param virtualMachineSize string = 'Standard_D2s_v3'
param osDiskType string = 'Premium_LRS'
var vmComputerName = length(resourceName) > 15 ? substring(resourceName,0,15) : resourceName
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: virtualMachineSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: osDiskType
        }
      }
      imageReference: {
        'publisher': 'canonical'
        'offer': '0001-com-ubuntu-server-focal'
        'sku': '20_04-lts'
        'version': 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      linuxConfiguration:   {
        'patchSettings': {
          'patchMode': 'ImageDefault'
        }
      }
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${uai.id}': {}
    }
  }
}

resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' =  {
  name: 'id-${vmName}'
  location: location
}

param RBACRolesNeeded array = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' //Reader
  '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8' //AksClusterRBACAdmin
]

resource vmIdRBAC 'Microsoft.Authorization/roleAssignments@2020-03-01-preview' =  [for roleId in RBACRolesNeeded: {
  scope: resourceGroup()
  name: '${guid(vm.id, roleId)}' //guid(resourceGroup().name,vm.name,roleId)
  properties: {
    principalId: uai.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
  }
}]

resource ghRunnerInstall 'Microsoft.Compute/virtualMachines/extensions@2021-04-01'  = {
  name: 'githubrunner-install'
  location: location
  parent: vm
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    protectedSettings: {
      fileUris : [
        'https://github.com/Gordonby/AzureBicepVM/blob/main/customscripts/githubrunner-install.sh?raw=true'
      ]
      commandToExecute: 'sh githubrunner-install.sh'
    }
  }
}
