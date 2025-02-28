<#
----------------------------------------------------------------------------------
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.

THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
----------------------------------------------------------------------------------
#>

<#
  .SYNOPSIS
    Runs CanadaPubSecALZ workflows.

  .DESCRIPTION
    This script is used to run one or more workflows for management groups, roles,
    logging, policies, networking, and subscriptions.

  .PARAMETER DeployManagementGroups
    If true, run the management group workflow.

  .PARAMETER DeployRoles
    If true, run the role workflow.

  .PARAMETER RoleNames
    An array of role definitions to deploy.  Role name must match the file names (without .bicep extension) in ./roles directory.  When not set, defaults to 'la-vminsights-readonly', 'lz-appowner', 'lz-netops', 'lz-secops', 'lz-subowner'.

  .PARAMETER DeployLogging
    If true, run the logging workflow.

  .PARAMETER DeployCustomPolicyDefinitions
    If true, run the policy workflow for deploying custom policy definitions

  .PARAMETER DeployCustomPolicySetDefinitions
    If true, run the policy workflow for deploying custom policy set definitions

  .PARAMETER CustomPolicySetDefinitionNames
    An array of custom policy set definitions to deploy.  When not set, defaults to 'AKS', 'DefenderForCloud', 'LogAnalytics', 'Network', 'DNSPrivateEndpoints', 'Tags'.

  .PARAMETER DeployCustomPolicySetAssignments
    If true, run the policy workflow for deploying custom policy set assignments

  .PARAMETER CustomPolicySetAssignmentManagementGroupId
    The management group ID to assign custom policy set assignments to.  When not set, defaults to top level management group (e.g. pubsec) based on management group hierarchy configuration.

  .PARAMETER CustomPolicySetAssignmentNames
    An array of custom policy set assignments to deploy.  When not set, defaults to 'AKS', 'DefenderForCloud', 'LogAnalytics', 'Network', 'Tags'.

  .PARAMETER DeployBuiltinPolicySetAssignments
    If true, run the policy workflow for deploying builtin policy definitions and assignments such as regulatory compliances.

  .PARAMETER BuiltinPolicySetAssignmentManagementGroupId
    The management group ID to assign built-in policy set assignments to.  When not set, defaults to top level management group (e.g. pubsec) based on management group hierarchy configuration.

  .PARAMETER BuiltinPolicySetAssignmentNames
    An array of built-in policy set assignments to deploy.  When not set, defaults to 'asb', 'nist80053r4', 'nist80053r5', 'pbmm', 'cis-msft-130', 'fedramp-moderate', 'hitrust-hipaa', 'location'.

  .PARAMETER DeployHubNetworkWithAzureFirewall
    If true, run the Azure Firewall hub network workflow.

  .PARAMETER DeployHubNetworkWithNVA
    If true, run the NVA hub network workflow.
  
  .PARAMETER DeployIdentity
    If true, run the Identity workflow.

  .PARAMETER DeploySubscriptionIds
    Comma separated list of quoted subscription ids to run the subscription workflow against.

  .PARAMETER EnvironmentName
    The name of the environment to run the workflow against.
    Used primarily for running interactively.

  .PARAMETER GitHubRepo
    The GitHub repo to use for the workflow.

  .PARAMETER GitHubRef
    The GitHub ref to use for the workflow.

  .PARAMETER LoginInteractiveTenantId
    If set, prompt for credentials and login to the specified tenant.

  .PARAMETER LoginServicePrincipalJson
    If set, login using the JSON credentials for the specified service principal.

  .PARAMETER WorkingDirectory
    The directory to use for the workflow.

  .PARAMETER NvaUsername
    The firewall username to use for the Hub network with NVA workflow.

  .PARAMETER NvaPassword
    The firewall password to use for the Hub Network with NVA workflow.

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -LoginInteractiveTenantId '8188040d-6c67-4c5c-b112-36a304b66dad' -DeployManagementGroups

    Deploy management groups interactively.

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -LoginInteractiveTenantId '8188040d-6c67-4c5c-b112-36a304b66dad' -DeployManagementGroups -DeployRoles -DeployLogging -DeployCustomPolicyDefinitions -DeployCustomPolicySetDefinitions -DeployCustomPolicySetAssignments -DeployBuiltinPolicySetAssignments -DeployAzureFirewallPolicy -DeployHubNetworkWithAzureFirewall

    Deploy all platform components interactively, with Azure Firewall.

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -LoginInteractiveTenantId '8188040d-6c67-4c5c-b112-36a304b66dad' -DeploySubscriptionIds 'a188040e-6c67-4c5c-b112-36a304b66dad,7188030d-6c67-4c5c-b112-36a304b66dac'

    Deploy 2 subscriptions interactively.

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -DeployCustomPolicyDefinitions -DeployCustomPolicySetDefinitions -DeployCustomPolicySetAssignments -DeployBuiltinPolicySetAssignments

    Deploy Built-In & Custom Policy Sets, including all default custom policy/policy set definitions.
  
  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -DeployCustomPolicyDefinitions

    Deploy Custom Policy Definitions only.

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -DeployCustomPolicySetAssignments -CustomPolicySetAssignmentManagementGroupId pubsec -CustomPolicySetAssignmentNames DefenderForCloud

    Deploy one Custom Policy Set Assignment at management group
  
  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -DeployBuiltinPolicySetAssignments

    Deploy Built In Policy Assignments

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -EnvironmentName CanadaPubSecALZ-main -DeployBuiltinPolicySetAssignments -BuiltinPolicySetAssignmentManagementGroupId pubsec -BuiltinPolicySetAssignmentNames asb

    Deploy one Built In Policy Assignment at management group

  .EXAMPLE
    PS> .\RunWorkflows.ps1 -GitHubRepo 'Azure/CanadaPubSecALZ' -GitHubRef 'refs/head/main' -LoginServicePrincipalJson (ConvertTo-SecureString -String '<output from: az ad sp create-for-rbac>' -AsPlainText -Force) -DeployManagementGroups

    Deploy management groups using service principal authentication.

    The action in the GitHub workflow could look like this:

    - name: Deploy Management Groups
      run: |
        ./RunWorkflows.ps1 `
          -DeployManagementGroups `
          -LoginServicePrincipalJson (ConvertTo-SecureString -String '${{secrets.ALZ_CREDENTIALS}}' -AsPlainText -Force) `
          -GitHubRepo ${env:GITHUB_REPOSITORY} `
          -GitHubRef ${env:GITHUB_REF}
#>

[CmdletBinding()]
Param(
  # What to deploy
  [switch]$DeployManagementGroups,

  [switch]$DeployRoles,
  [string[]]$RoleNames=@('la-vminsights-readonly', 'lz-appowner', 'lz-netops', 'lz-secops', 'lz-subowner'),

  [switch]$DeployLogging,

  [switch]$DeployCustomPolicyDefinitions,

  [switch]$DeployCustomPolicySetDefinitions,
  [string[]]$CustomPolicySetDefinitionNames=$('AKS', 'DefenderForCloud', 'LogAnalytics', 'Network', 'DNSPrivateEndpoints', 'Tags'),

  [switch]$DeployCustomPolicySetAssignments,
  [string]$CustomPolicySetAssignmentManagementGroupId=$null,
  [string[]]$CustomPolicySetAssignmentNames=$('AKS', 'DefenderForCloud', 'LogAnalytics', 'Network', 'Tags'),

  [switch]$DeployBuiltinPolicySetAssignments,
  [string]$BuiltinPolicySetAssignmentManagementGroupId=$null,
  [string[]]$BuiltinPolicySetAssignmentNames=$('asb', 'nist80053r4', 'nist80053r5', 'pbmm', 'cis-msft-130', 'fedramp-moderate', 'hitrust-hipaa', 'location'),

  [switch]$DeployAzureFirewallPolicy,
  [switch]$DeployHubNetworkWithNVA,
  [switch]$DeployHubNetworkWithAzureFirewall,
  [switch]$DeployVWANNetworkWithNVA,

  [switch]$DeployIdentity,

  [string[]]$DeploySubscriptionIds=@(),

  # How to deploy
  [string]$EnvironmentName="",
  [string]$GitHubRepo=$null,
  [string]$GitHubRef=$null,
  [string]$LoginInteractiveTenantId=$null,
  [SecureString]$LoginServicePrincipalJson=$null,
  [string]$WorkingDirectory=(Resolve-Path "../.."),
  [SecureString]$NvaUsername=$null,
  [SecureString]$NvaPassword=$null
)

$ErrorActionPreference = "Stop"

# In order to use this End to End script, you must configure ARM template configurations for Logging, Networking and Subscriptions.
# Please follow the instructions on https://github.com/Azure/CanadaPubSecALZ/blob/main/docs/onboarding/azure-devops-pipelines.md
# to setup the configuration files.  Once the configuration files are setup, you can choose to run this script or use Azure DevOps.

# Use $EnvironmentName parameter if specified, otherwise derive from GitHub or Azure DevOps environment.
if ([string]::IsNullOrEmpty($EnvironmentName)) {

  # Construct environment name from GitHub repo and ref (result: <repo>-<branch>)
  if ((-not [string]::IsNullOrEmpty($GitHubRepo)) -and (-not [string]::IsNullOrEmpty($GitHubRef))) {
    $EnvironmentName = `
      $GitHubRepo.Split('/')[1] + '-' + `
      $GitHubRef.Split('/')[$GitHubRef.Split('/').Count-1]
    Write-Host "Environment name: $EnvironmentName"
  }

  # Construct environment name from Azure DevOps (result: <repo>-<branch>)
  <#
    TO BE IMPLEMENTED
  #>
}
else {
  # Construct environment name from GitHub repo and ref (result: <repo>-<branch>)
  if ((-not [string]::IsNullOrEmpty($GitHubRepo))) {
    $EnvironmentName = `
      $GitHubRepo.Split('/')[1] + '-' + `
      $EnvironmentName
    Write-Host "Environment name: $EnvironmentName"
  }

  # Construct environment name from Azure DevOps (result: <repo>-<branch>)
  <#
    TO BE IMPLEMENTED
  #>
}

# Load functions
Write-Host "Loading functions..."
. ".\Functions\EnvironmentContext.ps1"
. ".\Functions\ManagementGroups.ps1"
. ".\Functions\Roles.ps1"
. ".\Functions\Logging.ps1"
. ".\Functions\Policy.ps1"
. ".\Functions\HubNetworkWithNVA.ps1"
. ".\Functions\HubNetworkWithAzureFirewall.ps1"
. ".\Functions\HubWVANNetworkWithNVA.ps1"
. ".\Functions\Identity.ps1"
. ".\Functions\Subscriptions.ps1"

# Az Login interactively
if (-not [string]::IsNullOrEmpty($LoginInteractiveTenantId)) {
  Write-Host "Logging in to Azure interactively..."
  Connect-AzAccount `
    -UseDeviceAuthentication `
    -TenantId $LoginInteractiveTenantId
}

# Az Login via Service Principal
if ($LoginServicePrincipalJson -ne $null) {
  Write-Host "Logging in to Azure using service principal..."
  $ServicePrincipal = ($LoginServicePrincipalJson | ConvertFrom-SecureString -AsPlainText) | ConvertFrom-Json
  $Password = ConvertTo-SecureString $ServicePrincipal.password -AsPlainText -Force
  $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ServicePrincipal.appId, $Password
  Connect-AzAccount -ServicePrincipal -TenantId $ServicePrincipal.tenant -Credential $Credential
}

# Set Azure Landing Zones Context
Write-Host "Setting Azure Landing Zones Context..."
$Context = New-EnvironmentContext -Environment $EnvironmentName -WorkingDirectory $WorkingDirectory

# Deploy Management Groups
if ($DeployManagementGroups) {
  Write-Host "Deploying Management Groups..."
  Set-ManagementGroups `
    -Context $Context `
    -ManagementGroupHierarchy $Context.ManagementGroupHierarchy
}

# Deploy Roles
if ($DeployRoles) {
  Write-Host "Deploying Roles..."
  Set-Roles `
    -Context $Context `
    -RolesDirectory $Context.RolesDirectory `
    -RoleNames $RoleNames `
    -ManagementGroupId $Context.Variables['var-FHA-managementGroupId']
}

# Deploy Logging
if ($DeployLogging) {
  Write-Host "Deploying Logging..."
  Set-Logging `
    -Context $Context `
    -Region $Context.Variables['var-logging-region'] `
    -ManagementGroupId $Context.Variables['var-logging-managementGroupId'] `
    -SubscriptionId $Context.Variables['var-logging-subscriptionId'] `
    -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])"
}

# Deploy Policy
if ($DeployCustomPolicyDefinitions) {
  Write-Host "Deploying custom policy definitions ..."

  Set-Policy-Definitions `
    -PolicyDefinitionsDirectory $Context.PolicyCustomDefinitionDirectory `
    -ManagementGroupId $Context.TopLevelManagementGroupId
}

if ($DeployCustomPolicySetDefinitions) {
  Write-Host "Deploying custom policy set definitions ..."

  Set-PolicySet-Defintions `
  -Context $Context `
  -PolicySetDefinitionsDirectory $Context.PolicySetCustomDefinitionDirectory `
  -ManagementGroupId $Context.TopLevelManagementGroupId `
  -PolicySetDefinitionNames $CustomPolicySetDefinitionNames
}

if ($DeployCustomPolicySetAssignments) {
  Write-Host "Deploying custom policy set assignments ..."

  # Get Logging information using logging config file
  $LoggingConfiguration = Get-LoggingConfiguration `
    -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])" `
    -SubscriptionId $Context.Variables['var-logging-subscriptionId']

  $AssignmentScope = $Context.TopLevelManagementGroupId
  if ([string]::IsNullOrEmpty($CustomPolicySetAssignmentManagementGroupId) -eq $false) {
    $AssignmentScope = $CustomPolicySetAssignmentManagementGroupId
  }

  Set-PolicySet-Assignments `
    -Context $Context `
    -PolicySetAssignmentsDirectory $Context.PolicySetCustomAssignmentsDirectory `
    -PolicySetAssignmentManagementGroupId $AssignmentScope `
    -PolicySetAssignmentNames $CustomPolicySetAssignmentNames `
    -LogAnalyticsWorkspaceResourceGroupName $LoggingConfiguration.ResourceGroupName `
    -LogAnalyticsWorkspaceResourceId $LoggingConfiguration.LogAnalyticsWorkspaceResourceId `
    -LogAnalyticsWorkspaceId $LoggingConfiguration.LogAnalyticsWorkspaceId `
    -LogAnalyticsWorkspaceRetentionInDays $LoggingConfiguration.LogRetentionInDays
}

if ($DeployBuiltinPolicySetAssignments) {
  Write-Host "Deploying built-in policy set assignments ..."

  # Get Logging information using logging config file
  $LoggingConfiguration = Get-LoggingConfiguration `
    -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])" `
    -SubscriptionId $Context.Variables['var-logging-subscriptionId']

  $AssignmentScope = $Context.TopLevelManagementGroupId
  if ([string]::IsNullOrEmpty($BuiltinPolicySetAssignmentManagementGroupId) -eq $false) {
    $AssignmentScope = $BuiltinPolicySetAssignmentManagementGroupId
  }

  # Built In Policy Set Assignments
  Set-PolicySet-Assignments `
    -Context $Context `
    -PolicySetAssignmentsDirectory $Context.PolicySetBuiltInAssignmentsDirectory `
    -PolicySetAssignmentManagementGroupId $AssignmentScope `
    -PolicySetAssignmentNames $BuiltinPolicySetAssignmentNames `
    -LogAnalyticsWorkspaceResourceGroupName $LoggingConfiguration.ResourceGroupName `
    -LogAnalyticsWorkspaceResourceId $LoggingConfiguration.LogAnalyticsWorkspaceResourceId `
    -LogAnalyticsWorkspaceId $LoggingConfiguration.LogAnalyticsWorkspaceId `
    -LogAnalyticsWorkspaceRetentionInDays $LoggingConfiguration.LogRetentionInDays
}

# Azure Firewall Policy
if ($DeployAzureFirewallPolicy) {
  # Create Azure Firewall Policy
  Set-AzureFirewallPolicy `
    -Context $Context `
    -Region $Context.Variables['var-hubnetwork-region'] `
    -SubscriptionId $Context.Variables['var-hubnetwork-subscriptionId'] `
    -ConfigurationFilePath "$($Context.NetworkingDirectory)/$($Context.Variables['var-hubnetwork-azfwPolicy-configurationFileName'])"
}

# Hub Networking with Azure Firewall
if ($DeployHubNetworkWithAzureFirewall) {
  Write-Host "Deploying Hub Networking with Azure Firewall..."
  # Get Logging information using logging config file
  $LoggingConfiguration = Get-LoggingConfiguration `
    -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])" `
    -SubscriptionId $Context.Variables['var-logging-subscriptionId']
  
  # Retrieve Azure Firewall Policy
  $AzureFirewallPolicyConfiguration = Get-AzureFirewallPolicy `
    -SubscriptionId $Context.Variables['var-hubnetwork-subscriptionId'] `
    -ConfigurationFilePath "$($Context.NetworkingDirectory)/$($Context.Variables['var-hubnetwork-azfwPolicy-configurationFileName'])"

  # Create Hub Networking with Azure Firewall
  Set-HubNetwork-With-AzureFirewall `
    -Context $Context `
    -Region $Context.Variables['var-hubnetwork-region'] `
    -ManagementGroupId $Context.Variables['var-hubnetwork-managementGroupId'] `
    -SubscriptionId $Context.Variables['var-hubnetwork-subscriptionId'] `
    -ConfigurationFilePath "$($Context.NetworkingDirectory)/$($Context.Variables['var-hubnetwork-azfw-configurationFileName'])" `
    -AzureFirewallPolicyResourceId $AzureFirewallPolicyConfiguration.AzureFirewallPolicyResourceId `
    -LogAnalyticsWorkspaceResourceId $LoggingConfiguration.LogAnalyticsWorkspaceResourceId
}

# Deploy Identity Subscription
if ($DeployIdentity) {
  Write-Host "Deploying Identity Subscription..."
  # Get Logging information using logging config file
  $LoggingConfiguration = Get-LoggingConfiguration `
    -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])" `
    -SubscriptionId $Context.Variables['var-logging-subscriptionId']
  
  #Create Identity Subscription
  Set-Identity `
    -Context $Context `
    -Region $Context.Variables['var-identity-region'] `
    -ManagementGroupId $Context.Variables['var-identity-managementGroupId'] `
    -SubscriptionId $Context.Variables['var-identity-subscriptionId'] `
    -ConfigurationFilePath "$($Context.IdentityDirectory)/$($Context.Variables['var-identity-configurationFileName'])" `
    -LogAnalyticsWorkspaceResourceId $LoggingConfiguration.LogAnalyticsWorkspaceResourceId
}

# Deploy Subscription archetypes
if (($null -ne $DeploySubscriptionIds) -and ($DeploySubscriptionIds.Count -gt 0)) {
  Write-Host "Deploying Subscriptions..."
  # Get Logging information using logging config file
  $LoggingConfiguration = Get-LoggingConfiguration `
    -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])" `
    -SubscriptionId $Context.Variables['var-logging-subscriptionId']

  # Deploy archetypes
  # Replace subscription id example below with your subscription ids
  Set-Subscriptions `
    -Context $Context `
    -Region $Context.DeploymentRegion `
    -SubscriptionIds $DeploySubscriptionIds `
    -LogAnalyticsWorkspaceResourceId $LoggingConfiguration.LogAnalyticsWorkspaceResourceId
}

# Deploy vHub Networking with NVA
if ($DeployVWANNetworkWithNVA) {
  Write-Host "Deploying vWAN Networking with NVA..."
 # Get Logging information using logging config file
 $LoggingConfiguration = Get-LoggingConfiguration `
 -ConfigurationFilePath "$($Context.LoggingDirectory)/$($Context.Variables['var-logging-configurationFileName'])" `
 -SubscriptionId $Context.Variables['var-logging-subscriptionId']


  Set-VWANNetwork-With-NVA `
    -Context $Context `
    -Region $Context.Variables['var-vhubnetwork-region'] `
    -ManagementGroupId $Context.Variables['var-vhubnetwork-managementGroupId'] `
    -SubscriptionId $Context.Variables['var-vhubnetwork-subscriptionId'] `
    -ConfigurationFilePath "$($Context.NetworkingDirectory)/$($Context.Variables['var-vhubnetwork-nva-configurationFileName'])" `
    -LogAnalyticsWorkspaceResourceId $LoggingConfiguration.LogAnalyticsWorkspaceResourceId `
    -NvaUsername $NvaUsername `
    -NvaPassword $NvaPassword
}
