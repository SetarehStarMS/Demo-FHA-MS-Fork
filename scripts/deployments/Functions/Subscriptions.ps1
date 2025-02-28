<#
----------------------------------------------------------------------------------
Copyright (c) Microsoft Corporation.
Licensed under the MIT license.

THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, 
EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES 
OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.
----------------------------------------------------------------------------------
#>

function Set-Subscriptions {
  param (
    [Parameter(Mandatory=$true)]
    $Context,

    [Parameter(Mandatory = $true)]
    [String] $Region,
    
    [Parameter(Mandatory = $true)]
    [String[]] $SubscriptionIds,

    [Parameter(Mandatory = $true)]
    [String] $LogAnalyticsWorkspaceResourceId
  )

  foreach ($subscriptionId in $SubscriptionIds) {   
    # Find the ARM JSON parameters, ensure there's only 1 parameters file for each subscription
    # $SubscriptionConfigurations = Get-ChildItem -Path $Context.SubscriptionsDirectory -Filter "*$subscriptionId*.json" -Recurse
    $pattern = "^$subscriptionId.*(_.*)(_.*)?\.json"
    $SubscriptionConfigurations = @(Get-ChildItem -Path $Context.SubscriptionsDirectory -Filter "*$subscriptionId*.json" -File -Recurse | ? { $_.Name -match $pattern })    

    if ($SubscriptionConfigurations.Count -eq 0) {
      Write-Output "No Subscription JSON parameters files found in $($Context.SubscriptionsDirectory) for $subscriptionId"
      continue
    } elseif ($SubscriptionConfigurations.Count -gt 1) {
      Write-Output "Multiple Subscription JSON paramters files found in $($Context.SubscriptionsDirectory) for $subscriptionId.  There must only be one."
      continue
    }

    $DirectoryName = $SubscriptionConfigurations[0].DirectoryName
    $FilePath = $SubscriptionConfigurations[0].FullName
    $FileName = $SubscriptionConfigurations[0].Name

    # Parse the file name to get subscription id, archetype and region (optional).
    # If region is not available in the file name, the use the default region provided
    $FileNameParts = ([System.IO.Path]::GetFileNameWithoutExtension($FilePath)) -Split "_"
    $SubscriptionId = $FileNameParts[0]
    $ArchetypeName = $FileNameParts[1]
    $DeploymentRegion = $FileNameParts.Count -eq 3 ? $FileNameParts[2] : $Region

    # Compute the management group id from the folder structure
    $FilePathWithoutBaseDirectory = $DirectoryName -Replace [regex]::Escape($Context.SubscriptionsDirectory), ""
    $ManagementGroupId = $FilePathWithoutBaseDirectory -Replace [regex]::Escape([IO.Path]::DirectorySeparatorChar.ToString()), ""

    Write-Output "Deploying Subscription: $SubscriptionId"
    Write-Output "  - Management Group: $ManagementGroupId"
    Write-Output "  - Archetype: $ArchetypeName"
    Write-Output "  - Region: $DeploymentRegion"

    Set-AzContext -Subscription $SubscriptionId

    $SchemaFile = (Resolve-Path -Path "$($Context.SchemaDirectory)/landingzones/lz-$ArchetypeName.json").Path
    
    Write-Output "Validation JSON parameter configuration using $SchemaFilePath"
    Get-Content -Raw $FilePath | Test-Json -SchemaFile $SchemaFile

    $Configuration = Get-Content $FilePath | ConvertFrom-Json -Depth 100

    #region Check if Log Analytics Workspace Id is provided.  Otherwise set it.
    $LogAnalyticsWorkspaceResourceIdInFile = $Configuration.parameters | Get-Member -Name logAnalyticsWorkspaceResourceId
  
    if ($null -eq $LogAnalyticsWorkspaceResourceIdInFile -or $Configuration.parameters.logAnalyticsWorkspaceResourceId.value -eq "") {
      $LogAnalyticsWorkspaceIdElement = @{
        logAnalyticsWorkspaceResourceId = @{
          value = $LogAnalyticsWorkspaceResourceId
        }
      }

      $Configuration.parameters | Add-Member $LogAnalyticsWorkspaceIdElement -Force
    }
    #endregion

    $PopulatedParametersFilePath = $DirectoryName + [IO.Path]::DirectorySeparatorChar + "populated-" + $FileName

    Write-Output "Creating new file with runtime populated parameters: $PopulatedParametersFilePath"
    $Configuration | ConvertTo-Json -Depth 100 | Set-Content $PopulatedParametersFilePath

    $MoveDeploymentName="move-subscription-$SubscriptionId-$DeploymentRegion"
    $MoveDeploymentName=-join $MoveDeploymentName[0..63] 

    # Write-Output "Moving Subscription ($SubscriptionId) to Management Group ($ManagementGroupId)"
    # $TemplateFile = (Resolve-Path -Path "$($Context.WorkingDirectory)/landingzones/utils/mg-move/move-subscription.bicep").Path
    # New-AzManagementGroupDeployment `
    #   -Name $MoveDeploymentName `
    #   -ManagementGroupId $ManagementGroupId `
    #   -Location $Context.DeploymentRegion `
    #   -TemplateFile $TemplateFile `
    #   -TemplateParameterObject @{
    #     managementGroupId = $ManagementGroupId
    #     subscriptionId = $SubscriptionId
    #   } `
    #   -Verbose

    Write-Output "Deploying $PopulatedParametersFilePath to $SubscriptionId in $Region"

    Set-AzContext -Subscription $SubscriptionId
    $TemplateFile = (Resolve-Path -Path "$($Context.WorkingDirectory)/landingzones/lz-$ArchetypeName/main.bicep").Path
    New-AzSubscriptionDeployment `
      -Name "main-$DeploymentRegion" `
      -Location $DeploymentRegion `
      -TemplateFile $TemplateFile `
      -TemplateParameterFile $PopulatedParametersFilePath `
      -Verbose

    Remove-Item $PopulatedParametersFilePath
  }
}