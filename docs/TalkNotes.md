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


# Demo instructions

- Draw out what we're going to do in MS Whiteboard

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
  - Show ARM template
  - `bicep decompile .\webapp-for-containers.json`
- Show Bicep on screen
- Add task for deploy of Bicep - Azure CLI has direct support for Bicep now!

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

- Deploy
- http://lgdonedemo-prod.azurewebsites.net/
- Update index.html
- http://lgdonedemo-dev.azurewebsites.net/
- Commit and wait

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

- http://lgdonedemo-prod.azurewebsites.net/
- Update index.html
- http://lgdonedemo-prod.azurewebsites.net/
- Commit and wait
- Add Trivy version variable

```yaml
  trivyVersion: 0.16.0
```

- Add script for installing Trivy on the build agent

```yaml
    - script: |
        sudo apt-get install rpm
        wget https://github.com/aquasecurity/trivy/releases/download/v$(trivyVersion)/trivy_$(trivyVersion)_Linux-64bit.deb
        sudo dpkg -i trivy_$(trivyVersion)_Linux-64bit.deb
        trivy -v
      displayName: 'Download and install Trivy'
```      

- Between docker build and run, add task for running Trivy

```yaml
    - task: CmdLine@2
      displayName: "Run trivy scan"
      inputs:
        script: |
            trivy image --exit-code 0 --severity LOW,MEDIUM $(imageName):$(Build.BuildNumber)
            trivy image --exit-code 1 --severity HIGH,CRITICAL $(imageName):$(Build.BuildNumber)
```

- Show results to on screen
- Add template file - talk about AzD supported output types
- Output to JUnit for Trivy instead
- Add publish test results tasks
  - Talk about conditions

```yaml
    - task: PublishTestResults@2
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: '**/junit-report-low-med.xml'
        mergeTestResults: true
        failTaskOnFailedTests: false
        testRunTitle: 'Trivy - Low and Medium Vulnerabilities'
      condition: 'always()'   

    - task: PublishTestResults@2
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: '**/junit-report-high-crit.xml'
        mergeTestResults: true
        failTaskOnFailedTests: true
        testRunTitle: 'Trivy - High and Critical Vulnerabilities'
      condition: 'always()'  
```      

# Complete Pipeline

```yaml
trigger:
- main

pool:
  vmImage: ubuntu-latest

variables:
  imageName: 'liamgu/simpleapp'
  trivyVersion: 0.16.0

stages:
- stage: Build
  displayName: Build
  jobs:  
  - job: Build
    pool:
      vmImage: ubuntu-latest      
      
    steps:
    - script: |
        sudo apt-get install rpm
        wget https://github.com/aquasecurity/trivy/releases/download/v$(trivyVersion)/trivy_$(trivyVersion)_Linux-64bit.deb
        sudo dpkg -i trivy_$(trivyVersion)_Linux-64bit.deb
        trivy -v
      displayName: 'Download and install Trivy'

    - task: Docker@2
      displayName: 'docker build'
      inputs:
        containerRegistry: 'Docker Hub'
        repository: '$(imageName)'
        command: 'build'
        Dockerfile: '$(System.DefaultWorkingDirectory)/src/simpleApp/Dockerfile'
        tags: |
          $(Build.BuildNumber)
          latest

    - task: CmdLine@2
      displayName: "Run trivy scan"
      inputs:
        script: |
            trivy image --severity LOW,MEDIUM --format template --template "@cicd/tools/templates/junit.tpl" -o junit-report-low-med.xml $(imageName):$(Build.BuildNumber)
            trivy image --severity HIGH,CRITICAL --format template --template "@cicd/tools/templates/junit.tpl" -o junit-report-high-crit.xml $(imageName):$(Build.BuildNumber)

    - task: PublishTestResults@2
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: '**/junit-report-low-med.xml'
        mergeTestResults: true
        failTaskOnFailedTests: false
        testRunTitle: 'Trivy - Low and Medium Vulnerabilities'
      condition: 'always()'   

    - task: PublishTestResults@2
      inputs:
        testResultsFormat: 'JUnit'
        testResultsFiles: '**/junit-report-high-crit.xml'
        mergeTestResults: true
        failTaskOnFailedTests: true
        testRunTitle: 'Trivy - High and Critical Vulnerabilities'
      condition: 'always()'  

    - task: Docker@2
      displayName: 'docker push'
      inputs:
        containerRegistry: 'Docker Hub'
        repository: '$(imageName)'
        command: 'push'
        tags: '$(Build.BuildNumber)'

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