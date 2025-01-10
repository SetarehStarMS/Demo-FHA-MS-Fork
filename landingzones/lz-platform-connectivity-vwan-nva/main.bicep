// ----------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation.
// Licensed under the MIT license.
//
// THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
// EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
// OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
// ----------------------------------------------------------------------------------

targetScope = 'subscription'

@description('Location for the deployment.')
param location string = deployment().location

/*

This is a platform archetype to support deployment of Azure VWAN with Virtual HUBs.  
This archetype will provide:

* Feature1
* Feature2
* Feature2 (optional)

*/

// Service Health
// Example (JSON)
// -----------------------------
// "serviceHealthAlerts": {
//   "value": {
//     "incidentTypes": [ "Incident", "Security", "Maintenance", "Information", "ActionRequired" ],
//     "regions": [ "Global", "Canada East", "Canada Central" ],
//     "receivers": {
//       "app": [ "email-1@company.com", "email-2@company.com" ],
//       "email": [ "email-1@company.com", "email-3@company.com", "email-4@company.com" ],
//       "sms": [ { "countryCode": "1", "phoneNumber": "1234567890" }, { "countryCode": "1",  "phoneNumber": "0987654321" } ],
//       "voice": [ { "countryCode": "1", "phoneNumber": "1234567890" } ]
//     },
//     "actionGroupName": "ALZ action group",
//     "actionGroupShortName": "alz-alert",
//     "alertRuleName": "ALZ alert rule",
//     "alertRuleDescription": "Alert rule for Azure Landing Zone"
//   }
// }
@description('Service Health alerts')
param serviceHealthAlerts object = {}

// Subscription Role Assignments
// Example (JSON)
// -----------------------------
// [
//   {
//       "comments": "Built-in Contributor Role",
//       "roleDefinitionId": "b24988ac-6180-42a0-ab88-20f7382dd24c",
//       "securityGroupObjectIds": [
//           "38f33f7e-a471-4630-8ce9-c6653495a2ee"
//       ]
//   }
// ]

// Example (Bicep)
// -----------------------------
// [
//   {
//     comments: 'Built-In Contributor Role'
//     roleDefinitionId: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
//     securityGroupObjectIds: [
//       '38f33f7e-a471-4630-8ce9-c6653495a2ee'
//     ]
//   }
// ]
@description('Array of role assignments at subscription scope.  The array will contain an object with comments, roleDefinitionId and array of securityGroupObjectIds.')
param subscriptionRoleAssignments array = []

// Subscription Budget
// Example (JSON)
// ---------------------------
// "subscriptionBudget": {
//   "value": {
//       "createBudget": false,
//       "name": "MonthlySubscriptionBudget",
//       "amount": 1000,
//       "timeGrain": "Monthly",
//       "contactEmails": [ "alzcanadapubsec@microsoft.com" ]
//   }
// }

// Example (Bicep)
// ---------------------------
// {
//   createBudget: true
//   name: 'MonthlySubscriptionBudget'
//   amount: 1000
//   timeGrain: 'Monthly'
//   contactEmails: [
//     'alzcanadapubsec@microsoft.com'
//   ]
// }
@description('Subscription budget configuration containing createBudget flag, name, amount, timeGrain and array of contactEmails')
param subscriptionBudget object

// Tags
// Example (JSON)
// -----------------------------
// "subscriptionTags": {
//   "value": {
//       "ISSO": "isso-tag"
//   }
// }

// Example (Bicep)
// ---------------------------
// {
//   ISSO: 'isso-tag'
// }
@description('A set of key/value pairs of tags assigned to the subscription.')
param subscriptionTags object

// Example (JSON)
// -----------------------------
// "resourceTags": {
//   "value": {
//       "ClientOrganization": "client-organization-tag",
//       "CostCenter": "cost-center-tag",
//       "DataSensitivity": "data-sensitivity-tag",
//       "ProjectContact": "project-contact-tag",
//       "ProjectName": "project-name-tag",
//       "TechnicalContact": "technical-contact-tag"
//   }
// }

// Example (Bicep)
// -----------------------------
// {
//   ClientOrganization: 'client-organization-tag'
//   CostCenter: 'cost-center-tag'
//   DataSensitivity: 'data-sensitivity-tag'
//   ProjectContact: 'project-contact-tag'
//   ProjectName: 'project-name-tag'
//   TechnicalContact: 'technical-contact-tag'
// }
@description('A set of key/value pairs of tags assigned to the resource group and resources.')
param resourceTags object

// central VWAN resource
@description('Reserved for description')
param VWAN object

// Virtual HUB resources
@description('Reserved for description')
param VirtualWanHUBs array


@description('Microsoft Defender for Cloud configuration.  It includes email and phone.')
param securityCenter object

// Log Analytics
@description('Log Analytics Resource Id to integrate Microsoft Defender for Cloud.')
param logAnalyticsWorkspaceResourceId string

/*
  Scaffold the subscription which includes:
    * Role Assignments to Security Groups
    * Service Health Alerts
    * Subscription Budget
    * Subscription Tags
*/
module subScaffold '../scaffold-subscription.bicep' = {
  name: 'configure-subscription'
  scope: subscription()
  params: {
    location: location
    serviceHealthAlerts: serviceHealthAlerts
    subscriptionRoleAssignments: subscriptionRoleAssignments
    subscriptionBudget: subscriptionBudget
    subscriptionTags: subscriptionTags
    resourceTags: resourceTags

    logAnalyticsWorkspaceResourceId: logAnalyticsWorkspaceResourceId
    securityCenter: securityCenter
  }
}

// Create VWAN Resource Group
resource rgVWAN 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: VWAN.resourceGroupName
  location: location
  tags: resourceTags
}

// Create VWAN resource
module resVWAN 'vwan/vwan.bicep' = {
  name: 'deploy-vwan-${VWAN.name}'
  scope:  rgVWAN
  params:{
    name: VWAN.name
    location: rgVWAN.location
    tags:resourceTags
  }
}

//Create Virtual HUB resources
module resVHUB 'vwan/vhubs.bicep' = [for hub in VirtualWanHUBs: if (hub.DeployVWANHUB) {
  scope: rgVWAN
  name: 'deploy-vhub-${hub.VirtualWanHUBName}'
  params: {
    VirtualWanHUBName: hub.VirtualWanHUBName
    location: hub.HubLocation
    tags: resourceTags
    VWANId: resVWAN.outputs.resourceId
    VirtualHubAddressPrefix: hub.VirtualHubAddressPrefix
    HubRoutingPreference: hub.HubRoutingPreference
    VirtualRouterAutoScaleConfiguration: hub.VirtualRouterAutoScaleConfiguration
  }
}]

// Get built-in route tableIds
module builtInRouteTables 'vwan/defaultRouteTable.bicep' = [for (hub, i) in VirtualWanHUBs: if (hub.DeployVWANHUB) {
  scope: rgVWAN
  name: 'defaultRouteTable-${hub.HubLocation}-Ids'
  params: {
    hubName: hub.DeployVWANHUB ? resVHUB[i].outputs.resourceName : ''
  }
}]

//Create ExpressRoute Gateways inside of the Virtual HUBs
module resERGateway 'vwan/ergw.bicep' = [for (hub, i) in VirtualWanHUBs: if ((hub.DeployVWANHUB) && (hub.ExpressRouteConfig.ExpressRouteGatewayEnabled)) {
  name: 'deploy-vhub-${hub.VirtualWanHUBName}-ergw'
  scope: rgVWAN
  params: {
    name: '${hub.VirtualWanHUBName}-ergw'
    tags: resourceTags
    vHUBId: hub.DeployVWANHUB ? resVHUB[i].outputs.resourceId : ''
    location: hub.HubLocation
    scaleUnits: hub.ExpressRouteConfig.ExpressRouteGatewayScaleUnits
  }
}]

//Create VPN Gateways inside of the Virtual HUBs
module resVPNGateway 'vwan/vpngw.bicep' = [for (hub, i) in VirtualWanHUBs: if ((hub.DeployVWANHUB) && (hub.VPNConfig.VPNGatewayEnabled)) {
  name: 'deploy-vhub-${hub.VirtualWanHUBName}-vpngw'
  scope: rgVWAN
  params: {
    name: '${hub.VirtualWanHUBName}-vpngw'
    tags: resourceTags
    vHUBId: hub.DeployVWANHUB ? resVHUB[i].outputs.resourceId : ''
    location: hub.HubLocation
    scaleUnits: hub.VPNConfig.VPNGatewayScaleUnits
  }
}]

//Create VPN site inside of the VPN Gateway
module resVPNSite 'vwan/vpnsite.bicep' = [for (hub, i) in VirtualWanHUBs: if ((hub.DeployVWANHUB) && (hub.VPNConfig.VPNGatewayEnabled)) {
  name: hub.VPNConfig.VPNSiteName
  scope: rgVWAN
  params: {
    vpnSiteName: hub.VPNConfig.VPNSiteName
    tags: resourceTags
    VWANId: resVWAN.outputs.resourceId
    location: hub.HubLocation
    deviceVendor: hub.VPNConfig.VPNDeviceVendors
    deviceModel: hub.VPNConfig.VPNDeviceModel
    linkSpeedInMbps: hub.VPNConfig.linkSpeedInMbps
    addressPrefixes:hub.VPNConfig.addressPrefixes
    vpnsitelinkName: hub.VPNConfig.vpnsitelinkName
    linkIPAddress: hub.VPNConfig.linkIPAddress
    linkProviderName: hub.VPNConfig.linkProviderName
  }
  dependsOn: [
    resVPNGateway
  ]
}]

//Create VPN connection for VPN site
module resVPNConnection 'vwan/vpnconnection.bicep' = [for (hub, i) in VirtualWanHUBs: if ((hub.DeployVWANHUB) && (hub.VPNConfig.VPNGatewayEnabled)) {
  name: hub.VPNConfig.VPNConnectionName
  scope: rgVWAN
  params: {
    vpnConnectionName: hub.VPNConfig.VPNGatewayEnabled ? '${resVPNGateway[i].outputs.resourceName}/${hub.VPNConfig.vpnConnectionName}' : ''
    vpnSiteName: hub.VPNConfig.VPNGatewayEnabled ? hub.VPNConfig.VPNSiteName: ''
    vpnsitelinkName: hub.VPNConfig.vpnsitelinkName
    sharedKey: hub.VPNConfig.sharedKey
    enableBgp: hub.VPNConfig.enableBGP
    vHUBName: hub.DeployVWANHUB ? resVHUB[i].outputs.resourceName : ''    
  }
  dependsOn: [
    resVPNSite
  ]
}]

param FirewallPublicIPsConfig object

//Create Resource Group for Firewall's Public IP Addresses
resource rgFWPIPs 'Microsoft.Resources/resourceGroups@2020-06-01' = if (FirewallPublicIPsConfig.DeployPublicIPs) {
  name: FirewallPublicIPsConfig.ResourceGroupName
  tags: resourceTags
  location: location
}

//Create Public IPs for NGFW Firewall
module NGFWPIPs '../../azresources/network/custom-public-ip.bicep' = [for PIPName in FirewallPublicIPsConfig.PublicIPNames: if (FirewallPublicIPsConfig.DeployPublicIPs) {
  scope: rgFWPIPs
  name: 'Deploy-${PIPName}'
  params: {
    PubIPName: PIPName
    location: FirewallPublicIPsConfig.DeployPublicIPs ? rgFWPIPs.location : 'null'
    tags: resourceTags
  }
}]

param SharedConnServicesPrimaryRegionConfig object
param SharedConnServicesSecondaryRegionConfig object

// Create Shared Connectivity Services Resource Group for VNET in Primary Region
resource rgVNETPrimary 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: SharedConnServicesPrimaryRegionConfig.ResourceGroupName
  tags: resourceTags
  location: SharedConnServicesPrimaryRegionConfig.DeploymentRegion
}

// Create Shared Connectivity Services Resource Group for VNET in Secondary Region
resource rgVNETSecondary 'Microsoft.Resources/resourceGroups@2020-06-01' = if (SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) {
  name: SharedConnServicesSecondaryRegionConfig.ResourceGroupName
  tags: resourceTags
  location: SharedConnServicesSecondaryRegionConfig.DeploymentRegion
}

// Create & configure virtual network in Primary Region
module vnetPrimary 'sharedservices/networking.bicep' = {
  name: 'deploy-networking'
  scope: resourceGroup(rgVNETPrimary.name)
  params: {
    SharedConnServicesNetwork:SharedConnServicesPrimaryRegionConfig.NetworkConfig
    location: rgVNETPrimary.location
  }
}

// Create & configure Bastion virtual network in Primary Region
module bastionVnetPrimary 'sharedservices/bastion-networking.bicep' = {
  name: 'deploy-bastion-networking'
  scope: resourceGroup(rgVNETPrimary.name)
  params: {
    SharedConnServicesBastionNetwork:SharedConnServicesPrimaryRegionConfig.BastionNetworkConfig
    location: rgVNETPrimary.location
  }
}
 
// Create & configure virtual network in Secondary Region
module vnetSecondary 'sharedservices/networking.bicep' = if (SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) {
  name: 'deploy-networking-secondary'
  scope: resourceGroup(SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? rgVNETSecondary.name : rgVNETPrimary.name)
  params: {
    SharedConnServicesNetwork:SharedConnServicesSecondaryRegionConfig.NetworkConfig
    location: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? rgVNETSecondary.location : rgVNETPrimary.location
  }
}

// Create & configure Bastion virtual network in Secondary Region
module bastionVnetSecondary 'sharedservices/bastion-networking.bicep' = if (SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) {
  name: 'deploy-bastion-networking-secondary'
  scope: resourceGroup(SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? rgVNETSecondary.name : rgVNETPrimary.name)
  params: {
    SharedConnServicesBastionNetwork:SharedConnServicesSecondaryRegionConfig.BastionNetworkConfig
    location: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? rgVNETSecondary.location : rgVNETPrimary.location
  }
}

//Connect Shared Connectivity Services VNET (PrimaryRegion) with First HUB
module vNetConnPrimary 'vwan/hubVirtualNetworkConnections.bicep' = {
  scope: rgVWAN
  name: 'deploy-vhub-connection-primary'
  params: {
    vHubName: resVHUB[0].outputs.resourceName
    vHubConnName: '${vnetPrimary.outputs.vnetName}-to-${resVHUB[0].outputs.resourceName}'
    remoteVirtualNetworkId: vnetPrimary.outputs.vnetId
  }
}

//Connect Shared Connectivity Services VNET (PrimaryRegion) with First HUB
module bastionVNetConnPrimary 'vwan/hubVirtualNetworkConnectionsNoInternetSecurity.bicep' = {
  scope: rgVWAN
  name: 'deploy-bastion-to-vhub-connection-primary'
  params: {
    vHubName: resVHUB[0].outputs.resourceName
    vHubConnName: '${bastionVnetPrimary.outputs.vnetName}-to-${resVHUB[0].outputs.resourceName}'
    remoteVirtualNetworkId: bastionVnetPrimary.outputs.vnetId
  }
}

//Connect Shared Connectivity Services VNET (SecondaryRegion) with First HUB
module vNetConnSecondary 'vwan/hubVirtualNetworkConnections.bicep' = if (SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) {
  scope: rgVWAN
  name: 'deploy-vhub-connection-Secondary'
  params: {
    vHubName: resVHUB[0].outputs.resourceName
    vHubConnName: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? '${vnetSecondary.outputs.vnetName}-to-${resVHUB[0].outputs.resourceName}' : ''
    remoteVirtualNetworkId: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? vnetSecondary.outputs.vnetId : ''
  }
}

//Connect Shared Connectivity Services VNET (PrimaryRegion) with First HUB
module bastionVNetConnSecondary 'vwan/hubVirtualNetworkConnectionsNoInternetSecurity.bicep' = if (SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) {
  scope: rgVWAN
  name: 'deploy-bastion-to-vhub-connection-secondary'
  params: {
    vHubName: resVHUB[0].outputs.resourceName
    vHubConnName: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? '${bastionVnetSecondary.outputs.vnetName}-to-${resVHUB[0].outputs.resourceName}' : ''
    remoteVirtualNetworkId: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? bastionVnetSecondary.outputs.vnetId : ''
  }
}

// Create Bastion Resource Group in Primary Region
resource rgBastionPrimary 'Microsoft.Resources/resourceGroups@2020-06-01' = if (SharedConnServicesPrimaryRegionConfig.BastionConfig.enabled) {
  name: SharedConnServicesPrimaryRegionConfig.BastionConfig.resourceGroupName
  location: SharedConnServicesPrimaryRegionConfig.DeploymentRegion
  tags: resourceTags
}

// Create Bastion Resource Group in Secondary Region
resource rgBastionSecondary 'Microsoft.Resources/resourceGroups@2020-06-01' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.BastionConfig.enabled)){
  name: SharedConnServicesSecondaryRegionConfig.BastionConfig.resourceGroupName
  location: SharedConnServicesSecondaryRegionConfig.DeploymentRegion
  tags: resourceTags
}

// Azure Bastion for Primary Region
module bastionPrimary '../../azresources/network/custom-bastion.bicep' = if (SharedConnServicesPrimaryRegionConfig.BastionConfig.enabled) {
  name: 'deploy-bastionPrimary'
  scope: rgBastionPrimary
  params: {
    location: SharedConnServicesPrimaryRegionConfig.BastionConfig.enabled ? rgBastionPrimary.location : null
    name: SharedConnServicesPrimaryRegionConfig.BastionConfig.name
    sku: SharedConnServicesPrimaryRegionConfig.BastionConfig.sku
    scaleUnits: SharedConnServicesPrimaryRegionConfig.BastionConfig.scaleUnits
    subnetId: bastionVnetPrimary.outputs.AzureBastionSubnetId
  }
}

// Azure Bastion for Secondary Region
module bastionSecondary '../../azresources/network/custom-bastion.bicep' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.BastionConfig.enabled)) {
  name: 'deploy-bastionSecondary'
  scope: rgBastionSecondary
  params: {
    location: SharedConnServicesSecondaryRegionConfig.BastionConfig.enabled ? rgBastionSecondary.location : null
    name: SharedConnServicesSecondaryRegionConfig.BastionConfig.name
    sku: SharedConnServicesSecondaryRegionConfig.BastionConfig.sku
    scaleUnits: SharedConnServicesSecondaryRegionConfig.BastionConfig.scaleUnits
    subnetId: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? bastionVnetSecondary.outputs.AzureBastionSubnetId : ''
  }
}

// Create Jumpbox Resource Group in Primary Region
resource rgJumpboxPrimary 'Microsoft.Resources/resourceGroups@2020-06-01' = if (SharedConnServicesPrimaryRegionConfig.JumpboxConfig.enabled) {
  name: SharedConnServicesPrimaryRegionConfig.JumpboxConfig.resourceGroupName
  location: SharedConnServicesPrimaryRegionConfig.DeploymentRegion
  tags: resourceTags
}

// Create Jumpbox Resource Group in Secondary Region
resource rgJumpboxSecondary 'Microsoft.Resources/resourceGroups@2020-06-01' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.JumpboxConfig.enabled)) {
  name: SharedConnServicesSecondaryRegionConfig.JumpboxConfig.resourceGroupName
  location: SharedConnServicesSecondaryRegionConfig.DeploymentRegion
  tags: resourceTags
}

// Temporary VM Credentials
@description('Temporary username for firewall virtual machines.')
@secure()
param fwUsername string

@description('Temporary password for firewall virtual machines.')
@secure()
param fwPassword string

// Create Jumpbox VM in Primary Region
module jumpboxPrimary 'sharedservices/management-vm.bicep' = if (SharedConnServicesPrimaryRegionConfig.JumpboxConfig.enabled) {
  scope: rgJumpboxPrimary
  name: 'deploy-jumpboxPrimary'
  params: {
    location: SharedConnServicesPrimaryRegionConfig.JumpboxConfig.enabled ? rgJumpboxPrimary.location : null
    password: fwPassword
    subnetId: vnetPrimary.outputs.ManagementSubnetId
    username: fwUsername
    vmName: SharedConnServicesPrimaryRegionConfig.JumpboxConfig.name
    vmSize: SharedConnServicesPrimaryRegionConfig.JumpboxConfig.VMSize
  }
}

// Create Jumpbox VM in Secondary Region
module jumpboxSecondary 'sharedservices/management-vm.bicep' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.JumpboxConfig.enabled)) {
  scope: rgJumpboxSecondary
  name: 'deploy-jumpboxSecondary'
  params: {
    location: SharedConnServicesSecondaryRegionConfig.JumpboxConfig.enabled ? rgJumpboxSecondary.location : null
    password: fwPassword
    subnetId: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? vnetSecondary.outputs.ManagementSubnetId : ''
    username: fwUsername
    vmName: SharedConnServicesSecondaryRegionConfig.JumpboxConfig.name
    vmSize: SharedConnServicesSecondaryRegionConfig.JumpboxConfig.VMSize
  }
}

// // Create Panorama Resource Group in Primary Region
// resource rgPanoramaPrimary 'Microsoft.Resources/resourceGroups@2020-06-01' = if (SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled) {
//   name: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.resourceGroupName
//   location: SharedConnServicesPrimaryRegionConfig.DeploymentRegion
//   tags: resourceTags
// }

// // Create Panorama Resource Group in Secondary Region
// resource rgPanoramaSecondary 'Microsoft.Resources/resourceGroups@2020-06-01' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled)) {
//   name: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.resourceGroupName
//   location: SharedConnServicesSecondaryRegionConfig.DeploymentRegion
//   tags: resourceTags
// }

// // Create Panorama VM in Primary Region
// module PanoramaPrimary 'sharedservices/panorama-vm.bicep' = if (SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled) {
//   scope: rgPanoramaPrimary
//   name: 'deploy-panoramaPrimary-VM'
//   // dependsOn: [
//   //   ILBPrimary
//   // ]
//   params: {
//     location: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled ? rgPanoramaPrimary.location : null
//     password: fwPassword
//     subnetId: vnetPrimary.outputs.PanoramaSubnetId
//     username: fwUsername
//     vmName: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName
//     vmSize: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmSize
//     privateIPAddress: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.privateIPAddress
//     // loadBalancerBackendAddressPoolID: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled ? ILBPrimary.outputs.backendAddressPoolID: ''
//   }
// }

// // Create Panorama VM in Secondary Region
// module PanoramaSecondary 'sharedservices/panorama-vm.bicep' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled)) {
//   scope: rgPanoramaSecondary
//   name: 'deploy-panoramaSecondary-VM'
//   // dependsOn: [
//   //   ILBSecondary
//   // ]
//   params: {
//     location: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled ? rgPanoramaSecondary.location: null
//     password: fwPassword
//     subnetId: SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion ? vnetSecondary.outputs.PanoramaSubnetId : ''
//     username: fwUsername
//     vmName: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName
//     vmSize: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmSize
//     privateIPAddress: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.privateIPAddress
//     // loadBalancerBackendAddressPoolID: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled ? ILBSecondary.outputs.backendAddressPoolID: ''
//   }
// }

// //Create Resource Group for Private Link Solution in Primary Region
// resource rgPrivateLinkPrimary 'Microsoft.Resources/resourceGroups@2020-06-01' = if (SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled) {
//   name: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.ResourceGroupNameForPrivateLink
//   location: SharedConnServicesPrimaryRegionConfig.DeploymentRegion
//   tags: resourceTags
// }

// //Create Resource Group for Private Link Solution in Secondary Region
// resource rgPrivateLinkSecondary 'Microsoft.Resources/resourceGroups@2020-06-01' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled)) {
//   name: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.ResourceGroupNameForPrivateLink
//   location: SharedConnServicesSecondaryRegionConfig.DeploymentRegion
//   tags: resourceTags
// }

// //Create Internal Load Balancer for PrivateLink Support in Privary Region
// module ILBPrimary 'sharedservices/panorama-privatelink.bicep' = if (SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled) {
//   scope: rgPrivateLinkPrimary
//   name: 'Deploy-ILB-Primary'
//   params: {
//     tags: resourceTags
//     location: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled ? rgPrivateLinkPrimary.location: null
//     LBname: '${SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName}-ILB'
//     frontendIPConfigurationsName: 'ILBConfig'
//     frontendIPConfigSubnetID: vnetPrimary.outputs.PanoramaSubnetId
//     frontendIPConfigurationsPrivateIPAddress: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.privateIPAddressForILB
//     backendAddressPoolName: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName
//     backendAddressPoolID: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled ? resourceId(subscription().subscriptionId,rgPrivateLinkPrimary.name,'Microsoft.Network/loadBalancers/backendAddressPools', '${SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName}-ILB', SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName): null
//     frontendIPConfigurationID: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled ? resourceId(subscription().subscriptionId,rgPrivateLinkPrimary.name,'Microsoft.Network/loadBalancers/frontendIpConfigurations', '${SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName}-ILB', 'ILBConfig'): null
//     probeID: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.enabled ? resourceId(subscription().subscriptionId,rgPrivateLinkPrimary.name,'Microsoft.Network/loadBalancers/probes', '${SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName}-ILB', 'HealthProbe'): null
//     PrivateLinkName: '${SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName}-PrivateLinkService'
//     PrivateLinkNameIP: '${SharedConnServicesPrimaryRegionConfig.PanoramaConfig.vmName}-PrivateLink'
//     PrivateLinkPrivateIPAddress: SharedConnServicesPrimaryRegionConfig.PanoramaConfig.privateIPAddressForPrivateLink
//     PrivateLinkPrivateSubnetID: vnetPrimary.outputs.PanoramaSubnetId
//   }
// }

// //Create Internal Load Balancer for PrivateLink Support in Secondary Region
// module ILBSecondary 'sharedservices/panorama-privatelink.bicep' = if ((SharedConnServicesSecondaryRegionConfig.DeploySharedConnServicesSecondaryRegion) && (SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled)) {
//   scope: rgPrivateLinkSecondary
//   name: 'Deploy-ILB-Secondary'
//   params: {
//     tags: resourceTags
//     location: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled ? rgPrivateLinkSecondary.location: null
//     LBname: '${SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName}-ILB'
//     frontendIPConfigurationsName: 'ILBConfig'
//     frontendIPConfigSubnetID: vnetSecondary.outputs.PanoramaSubnetId
//     frontendIPConfigurationsPrivateIPAddress: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.privateIPAddressForILB
//     backendAddressPoolName: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName
//     backendAddressPoolID: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled ? resourceId(subscription().subscriptionId,rgPrivateLinkSecondary.name,'Microsoft.Network/loadBalancers/backendAddressPools', '${SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName}-ILB', SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName): null
//     frontendIPConfigurationID: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled ? resourceId(subscription().subscriptionId,rgPrivateLinkSecondary.name,'Microsoft.Network/loadBalancers/frontendIpConfigurations', '${SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName}-ILB', 'ILBConfig') : null
//     probeID: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.enabled ? resourceId(subscription().subscriptionId,rgPrivateLinkSecondary.name,'Microsoft.Network/loadBalancers/probes', '${SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName}-ILB', 'HealthProbe') : null
//     PrivateLinkName: '${SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName}-PrivateLinkService'
//     PrivateLinkNameIP: '${SharedConnServicesSecondaryRegionConfig.PanoramaConfig.vmName}-PrivateLink'
//     PrivateLinkPrivateIPAddress: SharedConnServicesSecondaryRegionConfig.PanoramaConfig.privateIPAddressForPrivateLink
//     PrivateLinkPrivateSubnetID: vnetSecondary.outputs.PanoramaSubnetId
//   }
// }
