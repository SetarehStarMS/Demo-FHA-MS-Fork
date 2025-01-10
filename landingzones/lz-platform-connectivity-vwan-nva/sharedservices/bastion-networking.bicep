// ----------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------

@description('Location for the deployment.')
param location string = resourceGroup().location

param SharedConnServicesBastionNetwork object

module nsgbastion '../../../azresources/network/nsg/nsg-bastion.bicep' = {
  name: 'deploy-nsg-AzureBastionNsg'
  params: {
    name: 'AzureBastion-Nsg'
    location: location
  }
}

var requiredSubnets = [
  {
    name: SharedConnServicesBastionNetwork.subnets.AzureBastionSubnet.name
    properties: {
      addressPrefix: SharedConnServicesBastionNetwork.subnets.AzureBastionSubnet.addressPrefix
      networkSecurityGroup: {
        id: nsgbastion.outputs.nsgId
      }
    }
  }
] 

resource SharedConnServicesBastionVNET 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  location: location
  name: SharedConnServicesBastionNetwork.name
  properties: {
    addressSpace: {
      addressPrefixes: SharedConnServicesBastionNetwork.addressPrefixes
    }
    dhcpOptions: {
      dnsServers: SharedConnServicesBastionNetwork.dnsServers
    }
    subnets: requiredSubnets
  }
}

output vnetName string = SharedConnServicesBastionVNET.name
output vnetId string = SharedConnServicesBastionVNET.id

output AzureBastionSubnetId string = '${SharedConnServicesBastionVNET.id}/subnets/${SharedConnServicesBastionNetwork.subnets.AzureBastionSubnet.name}'
