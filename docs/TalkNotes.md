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
