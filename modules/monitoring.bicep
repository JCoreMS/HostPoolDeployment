param HostPoolName string
param LogAnalyticsWorkspaceId string
param HostPoolWorkspaceName string

var HostPoolLogsComm = [
  {
    category: 'Checkpoint'
    enabled: true
  }
  {
    category: 'Error'
    enabled: true
  }
  {
    category: 'Management'
    enabled: true
  }
  {
    category: 'Connection'
    enabled: true
  }
  {
    category: 'HostRegistration'
    enabled: true
  }
  {
    category: 'AgentHealthStatus'
    enabled: true
  }
  {
    category: 'ConnectionGraphicsData'
    enabled: true
  }
]

var HostPoolLogsGov = [
  {
    category: 'Checkpoint'
    enabled: true
  }
  {
    category: 'Error'
    enabled: true
  }
  {
    category: 'Management'
    enabled: true
  }
  {
    category: 'Connection'
    enabled: true
  }
  {
    category: 'HostRegistration'
    enabled: true
  }
  {
    category: 'AgentHealthStatus'
    enabled: true
  }
]

var HostPoolLogs = environment().name == 'AzureCloud' ? HostPoolLogsComm : HostPoolLogsGov

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-07-12' existing = {
  name: HostPoolWorkspaceName
}

// Name is the same as WVD Insights created to avoid conflict
resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2017-05-01-preview' = if (HostPoolWorkspaceName != 'none') {
  name: 'WVDInsights'
  scope: workspace
  properties: {
    logs: [
      {
        category: 'Checkpoint'
        enabled: true
      }
      {
        category: 'Error'
        enabled: true
      }
      {
        category: 'Management'
        enabled: true
      }
      {
        category: 'Feed'
        enabled: true
      }
    ]
    workspaceId: LogAnalyticsWorkspaceId
  }
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-04-01-preview' existing = {
  name: HostPoolName
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  name: 'WVDInsights'
  scope: hostPool
  properties: {
    logs: HostPoolLogs
    workspaceId: LogAnalyticsWorkspaceId
  }
}


