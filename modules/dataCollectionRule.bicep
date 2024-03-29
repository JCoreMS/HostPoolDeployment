targetScope = 'resourceGroup'

param DCRNewName string
param Location string
param LogAnalyticsWorkspaceId string
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

// Configure NEW DCR
resource dataCollectionRuleNew 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: DCRNewName
  location: Location
  tags: Tags
  kind: 'Windows'
  properties: {
    dataSources: {
      performanceCounters: PerfCounters
      windowsEventLogs: WinEvents
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: LogAnalyticsWorkspaceId
          name: 'la-workspace'
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-Perf'
          'Microsoft-Event'
        ]
        destinations: [
          'la-workspace'
        ]
      }
    ]
  }
}



output dataCollectionRuleId string = dataCollectionRuleNew.id
