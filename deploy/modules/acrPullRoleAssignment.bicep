@description('The principal id to grant the ACR Pull role to')
param principalId string

@description('The id of the app to grant the ACR Pull role to.')
param appId string

@description('The name of the Container Registry to authenticate to')
param containerRegistryName string

// This is the ACR Pull Role Definition Id: https://docs.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#acrpull
var acrPullRoleDefinitionId = subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d')


resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' existing = {
  name: containerRegistryName
}

resource containerAppAcrPullAssignment 'Microsoft.Authorization/roleAssignments@2020-10-01-preview' = {
  name: guid(containerRegistry.id, appId, acrPullRoleDefinitionId)
  scope: containerRegistry
  properties: {
    principalId: principalId
    roleDefinitionId: acrPullRoleDefinitionId
    principalType: 'ServicePrincipal'
  }
}
