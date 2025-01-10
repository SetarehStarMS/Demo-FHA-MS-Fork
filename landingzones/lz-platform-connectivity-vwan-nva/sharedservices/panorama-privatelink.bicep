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

param LBname string

@description('Key/Value pair of tags.')
param tags object = {}

param frontendIPConfigurationsName string
param frontendIPConfigSubnetID string
param backendAddressPoolName string
param frontendIPConfigurationsPrivateIPAddress string

param frontendIPConfigurationID string
param backendAddressPoolID string
param probeID string

resource ilb 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: LBname
  location: location
  tags: tags
  sku: {
    name: 'Standard'
    tier: 'Regional'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: frontendIPConfigurationsName
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: frontendIPConfigurationsPrivateIPAddress
          subnet: {
            id: frontendIPConfigSubnetID
          }
        }
      }
    ]
    backendAddressPools: [
      {
        name: backendAddressPoolName
      }
    ]
    probes: [
      {
        name: 'HealthProbe'
        properties: {
          port: 22
          protocol: 'Tcp'
          intervalInSeconds: 15 
        }
      }
    ]
    loadBalancingRules: [
      {
        name: '443'
        properties: {
          frontendPort: 443
          protocol: 'Tcp'
          backendPort: 443
          frontendIPConfiguration: {
            id: frontendIPConfigurationID
          }
          backendAddressPool: {
            id: backendAddressPoolID
          }
          probe: {
            id: probeID
          }
          idleTimeoutInMinutes: 4
          loadDistribution: 'SourceIPProtocol'
        }
      }
      {
        name: '3978'
        properties: {
          frontendPort: 3978
          protocol: 'Tcp'
          backendPort: 3978
          frontendIPConfiguration: {
            id: frontendIPConfigurationID
          }
          backendAddressPool: {
            id: backendAddressPoolID
          }
          probe: {
            id: probeID
          }
          idleTimeoutInMinutes: 4
          loadDistribution: 'SourceIPProtocol'
        }
      }
      {
        name: '28443'
        properties: {
          frontendPort: 28443
          protocol: 'Tcp'
          backendPort: 28443
          frontendIPConfiguration: {
            id: frontendIPConfigurationID
          }
          backendAddressPool: {
            id: backendAddressPoolID
          }
          probe: {
            id: probeID
          }
          idleTimeoutInMinutes: 4
          loadDistribution: 'SourceIPProtocol'
        }
      }
    ]
  }
}

param PrivateLinkName string
param PrivateLinkNameIP string
param PrivateLinkPrivateIPAddress string
param PrivateLinkPrivateSubnetID string

//Deploy Private Link Service Resource
resource PrivateLinkService 'Microsoft.Network/privateLinkServices@2023-06-01' = {
  name: PrivateLinkName
  dependsOn:[
    ilb
  ]
  location: location
  tags: tags
  properties: {
    loadBalancerFrontendIpConfigurations: [
      {
        name: frontendIPConfigurationsName
        id: frontendIPConfigurationID
      }
    ]
    ipConfigurations: [
      {
        name: PrivateLinkNameIP 
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddressVersion: 'IPv4'
          privateIPAddress: PrivateLinkPrivateIPAddress
          subnet: {
            id: PrivateLinkPrivateSubnetID
          }
        }
      }
    ]
  }
}

output backendAddressPoolID string = ilb.properties.backendAddressPools[0].id
output frontendIPConfigurationID string = ilb.properties.frontendIPConfigurations[0].id
output probeID string = ilb.properties.probes[0].id
