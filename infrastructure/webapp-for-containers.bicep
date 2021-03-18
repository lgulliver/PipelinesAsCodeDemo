@description('The name of the function app that you wish to create.')
param siteName string

var servicePlanName_var = '${siteName}-ServicePlan'

resource servicePlanName 'Microsoft.Web/serverfarms@2018-02-01' = {
  kind: 'linux'
  name: servicePlanName_var
  location: resourceGroup().location
  properties: {
    name: servicePlanName_var
    reserved: true
    numberOfWorkers: '1'
  }
  sku: {
    tier: 'Standard'
    name: 'S1'
  }
  dependsOn: []
}

resource siteName_resource 'Microsoft.Web/sites@2018-11-01' = {
  name: siteName
  location: resourceGroup().location
  properties: {
    siteConfig: {
      name: siteName
      appSettings: [
        {
          name: 'WEBSITES_ENABLE_APP_SERVICE_STORAGE'
          value: 'false'
        }
      ]
      linuxFxVersion: 'DOCKER|nginx:alpine'
    }
    serverFarmId: servicePlanName.id
  }
}