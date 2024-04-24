targetScope = 'resourceGroup'

param DCRStatus string
param DCRNewName string
param DCRExisting string
param HostPoolStatus string
param HostPoolName string
param HostPoolWorkspaceName string
param LogAnalyticsWorkspaceId string
param ResGroupIdMonitor string
param Location string
param Tags object


var PerfCounters = [
  {
    streams: [
      'Microsoft-Perf'
    ]
    samplingFrequencyInSeconds: 30
    counterSpecifiers: [
      '\\LogicalDisk(C:)\\Avg. Disk Queue Length'
      '\\LogicalDisk(C:)\\Current Disk Queue Length'
      '\\Memory\\Available Mbytes'
      '\\Memory\\Page Faults/sec'
      '\\Memory\\Pages/sec'
      '\\Memory\\% Committed Bytes In Use'
      '\\PhysicalDisk(*)\\Avg. Disk Queue Length'
      '\\PhysicalDisk(*)\\Avg. Disk sec/Read'
      '\\PhysicalDisk(*)\\Avg. Disk sec/Transfer'
      '\\PhysicalDisk(*)\\Avg. Disk sec/Write'
      '\\Processor Information(_Total)\\% Processor Time'
      '\\User Input Delay per Process(*)\\Max Input Delay'
      '\\User Input Delay per Session(*)\\Max Input Delay'
      '\\RemoteFX Network(*)\\Current TCP RTT'
      '\\RemoteFX Network(*)\\Current UDP Bandwidth'
    ]
    name: 'perfCounterDataSource10'
  }
  {
    streams: [
      'Microsoft-Perf'
    ]
    samplingFrequencyInSeconds: 60
    counterSpecifiers: [
      '\\LogicalDisk(C:)\\% Free Space'
      '\\LogicalDisk(C:)\\Avg. Disk sec/Transfer'
      '\\Terminal Services(*)\\Active Sessions'
      '\\Terminal Services(*)\\Inactive Sessions'
      '\\Terminal Services(*)\\Total Sessions'
    ]
    name: 'perfCounterDataSource30'
  }
]

var WinEvents = [
  {
    streams: [
      'Microsoft-Event'
    ]
    xPathQueries: [
      'Microsoft-Windows-TerminalServices-RemoteConnectionManager/Admin!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
      'Microsoft-Windows-TerminalServices-LocalSessionManager/Operational!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
      'System!*'
      'Microsoft-FSLogix-Apps/Operational!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
      'Application!*[System[(Level=2 or Level=3)]]'
      'Microsoft-FSLogix-Apps/Admin!*[System[(Level=2 or Level=3 or Level=4 or Level=0)]]'
    ]
    name: 'eventLogsDataSource'
  }
]

resource workspace 'Microsoft.DesktopVirtualization/workspaces@2021-07-12' existing = {
  name: HostPoolWorkspaceName
}

// Name is the same as WVD Insights created to avoid conflict with AVD Conifuguration Workbook
resource workspaceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (HostPoolWorkspaceName != 'none') {
  name: 'WVDInsights'
  scope: workspace
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    workspaceId: LogAnalyticsWorkspaceId
  }
}

resource hostPool 'Microsoft.DesktopVirtualization/hostPools@2022-10-14-preview' existing = if(HostPoolStatus != 'Existing') {
  name: HostPoolName
}

resource hostPoolDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if(HostPoolStatus != 'Existing') {
  name: 'WVDInsights'
  scope: hostPool
  properties: {
    logs: [
      {
        categoryGroup: 'AllLogs'
        enabled: true
      }
    ]
    workspaceId: LogAnalyticsWorkspaceId
  }
}


