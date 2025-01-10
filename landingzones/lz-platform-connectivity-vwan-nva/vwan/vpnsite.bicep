param vpnSiteName string
param deviceVendor string
param deviceModel string
param linkSpeedInMbps int
param addressPrefixes string
param vpnsitelinkName string
param linkIPAddress string
param linkProviderName string
@description('Location for the deployment.')
param location string = resourceGroup().location

@description('A set of key/value pairs of tags assigned to the resource group and resources.')
param tags object

param VWANId string
resource virtualGatewaySite 'Microsoft.Network/vpnSites@2020-05-01' = {
  name: vpnSiteName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefixes
      ]
    }
    deviceProperties: {
      deviceVendor: deviceVendor
      deviceModel: deviceModel
      linkSpeedInMbps: linkSpeedInMbps      
    }
    vpnSiteLinks: [
      {
        name: vpnsitelinkName
        properties: {
          linkProperties: {
            linkProviderName: linkProviderName
            linkSpeedInMbps: linkSpeedInMbps
          }
          ipAddress: linkIPAddress
        }
      }
    ]
    virtualWan: {
      id: VWANId
    }
  }
}
output resourceId string = virtualGatewaySite.id
