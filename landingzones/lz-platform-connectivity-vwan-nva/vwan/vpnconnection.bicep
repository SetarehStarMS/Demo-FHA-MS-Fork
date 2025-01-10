param vpnConnectionName string
param vpnSiteName string
//param vpnSiteId string
param vpnsitelinkName string
param sharedKey string
param enableBgp bool
param vHUBName string

resource VPNGatewayConnection 'Microsoft.Network/vpnGateways/vpnConnections@2023-06-01' = {
  name: vpnConnectionName
  properties: {
    remoteVpnSite: {
      id: resourceId('Microsoft.Network/vpnSites',vpnSiteName)
      //id: vpnSiteId
    }
    vpnLinkConnections: [
      {
        name: vpnsitelinkName
        properties: {
          vpnSiteLink: {
            id: resourceId('Microsoft.Network/vpnSites/vpnSiteLinks', vpnSiteName, vpnsitelinkName)
          }
          enableBgp: enableBgp
          sharedKey: sharedKey
        }
      }
    ]
    routingConfiguration: {
      associatedRouteTable: {
        id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vHUBName, 'defaultRouteTable')
      }
      propagatedRouteTables: {
        labels: [
          'default'
        ]
        ids: [
          {
            id: resourceId('Microsoft.Network/virtualHubs/hubRouteTables', vHUBName, 'defaultRouteTable')
          }
        ]
      }
    }
  }  
}
