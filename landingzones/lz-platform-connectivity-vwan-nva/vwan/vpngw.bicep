param name string
param scaleUnits int = 1

@description('Location for the deployment.')
param location string = resourceGroup().location

@description('A set of key/value pairs of tags assigned to the resource group and resources.')
param tags object

param vHUBId string

resource resVPNGW 'Microsoft.Network/vpnGateways@2023-06-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    virtualHub: {
      id: vHUBId
    }
    vpnGatewayScaleUnit: scaleUnits
    
  }
}

output resourceId string = resVPNGW.id
output resourceName string = resVPNGW.name
