# What's needed

- Connection to Docker Hub
  - *Settings > Service Connections > Create Service Connection*
    - Docker Registry
    - Docker Hub
    - Docker ID and Password
    - Verify
    - Name connection "Docker Hub"
    - Save

- Connection to Azure


# Creating Pipeline for Simple App

- Pipelines > Create Pipeline > GitHub > PipelinesAsCodeDemo
- Set folder to `cicd`
- Name file simpleapp.yaml
- Use starter template
- Add variables

```yaml
variables:
  imageName: 'liamgu/simpleapp'
  tag: '$(Build.BuildNumber)'
```

- Add Docker task 

```yaml
- task: Docker@2
  inputs:
    containerRegistry: 'Docker Hub'
    repository: '$(imageName)'
    command: 'buildAndPush'
    Dockerfile: 'src/simpleApp/Dockerfile'
    tags: |
          $(Build.BuildNumber)
          latest
```

- Whole pipeline should look like this:

```yaml
trigger:
- main

pool:
  vmImage: ubuntu-latest

variables:
  imageName: 'liamgu/simpleapp'

stages:
- stage: Build
  displayName: Build
  jobs:  
  - job: Build
    pool:
      vmImage: ubuntu-latest
      
    steps:
    - task: Docker@2
      inputs:
        containerRegistry: 'Docker Hub'
        repository: '$(imageName)'
        command: 'buildAndPush'
        Dockerfile: '$(System.DefaultWorkingDirectory)/src/simpleApp/Dockerfile'
        tags: |
          $(Build.BuildNumber)
          latest
```

- Run Build
- Update `command` to be build
- Add Task for push

```yaml
    - task: Docker@2
      inputs:
        containerRegistry: 'Docker Hub'
        repository: '$(imageName)'
        command: 'push'
        tags: |
          $(Build.BuildNumber)
          latest
```        

- Add display name to Docker tasks
- Come back to docker later
- Add stage for `dev`

```yaml
- stage: Dev
  dependsOn: Build
  displayName: Dev

  variables:
    environment_name: dev
    siteName: lgdonedemo    
  
  jobs:  
  - job: Deploy
    pool:
      vmImage: ubuntu-latest  
```

- Cover Bicep briefly
- Show Bicep on screen
- Add task for deploy of Bicep

```yaml
    steps:
    - task: AzureCLI@2
      displayName: 'Deploy Bicep'
      inputs:
        azureSubscription: 'VS Sub'
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          az group create -l uksouth -n lg-done-$(environment_name)-rg
          az deployment group create -f $(System.DefaultWorkingDirectory)/infrastructure/webapp-for-containers.bicep -g lg-done-$(environment_name)-rg --parameters siteName=$(siteName)-$(environment_name)
        addSpnToEnvironment: true
```

- Add task to deploy docker container built in this run

```yaml
    - task: AzureRmWebAppDeployment@4
      displayName: 'Deploy simpleapp:$(Build.BuildNumber)'
      inputs:
        ConnectionType: 'AzureRM'
        azureSubscription: 'VS Sub'
        appType: 'webAppContainer'
        WebAppName: '$(siteName)-$(environment_name)'
        DockerNamespace: 'liamgu'
        DockerRepository: 'simpleapp'
        DockerImageTag: '$(Build.BuildNumber)'
```

- Add Prod stage

```yaml
- stage: Prod
  dependsOn: Dev
  displayName: Prod

  variables:
    environment_name: prod
    siteName: lgdonedemo    
  
  jobs:  
  - job: Deploy
    pool:
      vmImage: ubuntu-latest
  
    steps:
    - task: AzureCLI@2
      displayName: 'Deploy Bicep'
      inputs:
        azureSubscription: 'VS Sub'
        scriptType: 'bash'
        scriptLocation: 'inlineScript'
        inlineScript: |
          az group create -l uksouth -n lg-done-$(environment_name)-rg
          az deployment group create -f $(System.DefaultWorkingDirectory)/infrastructure/webapp-for-containers.bicep -g lg-done-$(environment_name)-rg --parameters siteName=$(siteName)-$(environment_name)
        addSpnToEnvironment: true
    
    - task: AzureRmWebAppDeployment@4
      displayName: 'Deploy simpleapp:$(Build.BuildNumber)'
      inputs:
        ConnectionType: 'AzureRM'
        azureSubscription: 'VS Sub'
        appType: 'webAppContainer'
        WebAppName: '$(siteName)-$(environment_name)'
        DockerNamespace: 'liamgu'
        DockerRepository: 'simpleapp'
        DockerImageTag: '$(Build.BuildNumber)'
```        