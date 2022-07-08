@description('The location to deploy our application to. Default is location of resource group')
param location string = resourceGroup().location

@description('Name of our application.')
param applicationName string = uniqueString(resourceGroup().id)

var containerRegistryName = '${applicationName}acr'
var logAnalyticsWorkspaceName = '${applicationName}law'
var appInsightsName = '${applicationName}ai'
var containerAppEnvironmentName = '${applicationName}env'
var siloAppName = 'hello-silo'
var clientAppName = 'hello-client'
var targetPort = 80

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-02-01-preview' = {
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    adminUserEnabled: true
  }
}

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-12-01-preview' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: {
   sku: {
    name: 'PerGB2018'
   } 
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id 
  }
}

resource environment 'Microsoft.App/managedEnvironments@2022-03-01' = {
  name: containerAppEnvironmentName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource siloApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: siloAppName
  location: location
  properties: {
    managedEnvironmentId: environment.id
    configuration: {
      activeRevisionsMode: 'Multiple'
      secrets: [
        {
          name: 'container-registry-password'
          value: containerRegistry.listCredentials().passwords[0].value
        }
      ]
      registries: [
        {
          server: '${containerRegistry.name}.azurecr.io'
          username: containerRegistry.listCredentials().username
          passwordSecretRef: 'container-registry-password'
        }
      ]
    }
    template: {
      containers: [
        {
          name: clientAppName
          image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 10
      }
     }
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource clientApp 'Microsoft.App/containerApps@2022-03-01' = {
  name: clientAppName
  location: location
  properties: {
   managedEnvironmentId: environment.id
   configuration: {
    activeRevisionsMode: 'Multiple'
    secrets: [
      {
        name: 'container-registry-password'
        value: containerRegistry.listCredentials().passwords[0].value
      }
    ]
    registries: [
      {
        server: '${containerRegistry.name}.azurecr.io'
        username: containerRegistry.listCredentials().username
        passwordSecretRef: 'container-registry-password'
      }
    ]
    ingress: {
      external: true
      targetPort: targetPort
      transport: 'http'
      allowInsecure: false
    }
   }
   template: {
    containers: [
      {
        name: clientAppName
        image: 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'
      }
    ]
    scale: {
      minReplicas: 1
      maxReplicas: 10
    }
   } 
  }
  identity: {
    type: 'SystemAssigned'
  }
}
