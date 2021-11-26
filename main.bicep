@description('Used to name the VM')
param resourceNameSeed string

@description('The full resourceId of the subnet you want to deploy the VM into')
param subnetId string

@allowed([
  'Windows2019'
  'Ubuntu2004'
])
param os string = 'Windows2019'
var isWindows = substring(os,0,7) == 'Windows'

@allowed([
  'DevMachine'
])
param role string = 'DevMachine'

@description('The local admin username')
param adminUsername string

@secure()
@description('The local admin password')
param adminPassword string

param RBACRolesNeeded array = [
  'acdd72a7-3385-48ef-bd42-f606fba81ae7' //Reader
  '0ab0b1a8-8aac-4efd-b8c2-3ee1fb270be8' //AksClusterAdmin
  //'b24988ac-6180-42a0-ab88-20f7382dd24c' //Contributor
]
param doRBACAssignments bool = true

param location string = resourceGroup().location
param enableAcceleratedNetworking bool =true
param osDiskType string = 'Premium_LRS'
param osDiskDeleteOption string = 'Delete'
param virtualMachineSize string = 'Standard_D2s_v3'
param nicDeleteOption string = 'Delete'
param patchMode string = 'AutomaticByOS'
param enableHotpatching bool =false
param zone string = '1'
param autoShutdownStatus string = 'Enabled'
param autoShutdownTime string = '19:00'
param autoShutdownTimeZone string = 'UTC'

var vnetRG = split(subnetId, '/')[4]
var vnetName = split(subnetId, '/')[8]
var subnetName = split(subnetId, '/')[10]

var vmName='vm-${resourceNameSeed}'
var nicName='nic-01-vm${resourceNameSeed}'
var vmComputerName = length(resourceNameSeed) > 15 ? substring(resourceNameSeed,0,15) : resourceNameSeed

var osmap = {
  Windows2019: {
    publisher: 'MicrosoftWindowsServer'
    offer: 'WindowsServer'
    sku: '2019-Datacenter-smalldisk'
    version: 'latest'
  }
  Ubuntu2004: {
    'publisher': 'canonical'
    'offer': '0001-com-ubuntu-server-focal'
    'sku': '20_04-lts'
    'version': 'latest'
  }
}

var windowsConfig = {
  enableAutomaticUpdates: true
  provisionVMAgent: true
  patchSettings: {
    enableHotpatching: enableHotpatching
    patchMode: patchMode
  }
}

var linuxConfig = {
  'patchSettings': {
      'patchMode': 'ImageDefault'
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2021-03-01' existing = {
  name: vnetName
  scope: resourceGroup(vnetRG)
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2021-02-01' existing = {
  parent: vnet
  name: subnetName
}

resource nic 'Microsoft.Network/networkInterfaces@2021-03-01' = {
  name: nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: 'Dynamic'
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
  }
}

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
        deleteOption: osDiskDeleteOption
      }
      imageReference: osmap[os]
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
          properties: {
            deleteOption: nicDeleteOption
          }
        }
      ]
    }
    osProfile: {
      computerName: vmComputerName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: isWindows ? windowsConfig : json('null')
      linuxConfiguration: ! isWindows ? linuxConfig : json('null')
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
  zones: [
    zone
  ]
}

resource uai 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' =  {
  name: 'id-${vmName}'
  location: location
}

resource vmIdRBAC 'Microsoft.Authorization/roleAssignments@2020-03-01-preview' =  [for roleId in RBACRolesNeeded: if(doRBACAssignments) {
  scope: resourceGroup()
  name: '${guid(vm.id, roleId)}' //guid(resourceGroup().name,vm.name,roleId)
  properties: {
    principalId: uai.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', roleId)
  }
}]

resource shutdownSchedule 'Microsoft.DevTestLab/schedules@2018-09-15' = {
  name: 'shutdown-computevm-${vmName}'
  location: location
  properties: {
    status: autoShutdownStatus
    taskType: 'ComputeVmShutdownTask'
    dailyRecurrence: {
      time: autoShutdownTime
    }
    timeZoneId: autoShutdownTimeZone
    targetResourceId: vm.id
    notificationSettings: {
      status: 'Disabled'
    }
  }
}

resource winDevTools 'Microsoft.Compute/virtualMachines/extensions@2021-04-01'  = if(isWindows && role=='DevMachine') {
  name: 'WindowsDevTools'
  location: location
  parent: vm
  properties: {
    publisher: 'Microsoft.Compute'
    type: 'CustomScriptExtension'
    typeHandlerVersion: '1.7'
    autoUpgradeMinorVersion: true
    settings: {
      fileUris : [
        'https://github.com/Gordonby/AzureBicepVM/blob/main/customscripts/windowsdevtools.ps1?raw=true'
      ]
      commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -File DevVMTools.ps1'
    }
  }
}

resource linuxDevTools 'Microsoft.Compute/virtualMachines/extensions@2021-04-01'  = if(! isWindows && role=='DevMachine') {
  name: 'LinuxDevTools'
  location: location
  parent: vm
  properties: {
    publisher: 'Microsoft.Azure.Extensions'
    type: 'CustomScript'
    typeHandlerVersion: '2.1'
    autoUpgradeMinorVersion: true
    settings: {
    }
    protectedSettings: {
      fileUris : [
        'https://github.com/Gordonby/AzureBicepVM/blob/main/customscripts/linuxdevtools.sh?raw=true'
      ]
      commandToExecute: 'sh DevVMTools.sh'
    }
  }
}

output adminUsername string = adminUsername
