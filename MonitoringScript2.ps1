

$performanceScript =  {

    $counters = @( 
    #CPU
    "\Processor(_Total)\% Processor Time", #CPU usage
    "\System\Processor Queue Length", #CPU delayed execution of prosesses
    
    #RAM
    "\Memory\Available MBytes", #RAM MB availability
    "\Memory\% Committed Bytes In Use", # RAM MB usage
    
    #Disk
    "\LogicalDisk(_Total)\% Free Space", #Disk capacity
    "\PhysicalDisk(_Total)\Disk Transfers/sec", #Disk activity level

    #Network
    "\Network Interface(*)\Bytes Total/sec", #Network trafic in bites
    "\Network Interface(*)\Packets Outbound Errors", #Network errors
    "\Network Interface(*)\Packets Received Errors" 
    )

    $counterData = Get-Counter -Counter $counters

    $PerformanceResults = $counterData.CounterSamples | Select-Object @{Name='Server'; Expression={$env:COMPUTERNAME.ToUpper()}},
                    @{Name='Counter'; Expression={($_.Path -split '\\')[-1].ToUpper()}},
                    @{Name='Value'; Expression={[math]::Round($_.CookedValue, 2)}},
                    @{Name='Timestamp'; Expression={Get-Date -Format "yyyy-MM-dd HH:mm:ss"}},
                    @{Name='Status'; Expression={
                                $counter = ($_.Path -split '\\')[-1]
                                $value = $_.CookedValue

                                switch -Wildcard ($counter) {
                                    "*Processor Time*" { if ($value -lt 80) { "✅" } else { "❌" } }
                                    "*Queue Length*"   { if ($value -lt 2) { "✅" } else { "❌" } }
                                    "*Available MBytes*" { if ($value -gt 1000) { "✅" } else { "❌" } }
                                    "*Committed Bytes*" { if ($value -lt 80) { "✅" } else { "❌" } }
                                    "*Free Space*" { if ($value -gt 15) { "✅" } else { "❌" } }
                                    "*Disk Transfers*" { if ($value -lt 200) { "✅" } else { "❌" } }
                                    "*Packets*" { if ($value -eq 0) { "✅" } else { "❌" } }
                                    default { "⚪" }}}}
    return $PerformanceResults

}

$serviceScript = {
    $Server = $env:COMPUTERNAME.ToLower()
    if ($Server -eq "dc1"){
        $Services = "NTDS", "DNS", "KDC", "DFSR", "Netlogon"

    }elseif ($Server -eq "srv1"){
        $Services = "DFS", "W3SVC"
    } else{
        $Services = @()
    }
    if ($Services.Count -gt 0){
        $servicesData = Get-Service -Name $Services

        $serviceResults = $servicesData | Select-Object @{Name='Server'; Expression={$env:COMPUTERNAME.ToUpper()}},
            @{Name='Name'; Expression={$_.Name}},
            @{Name='Status'; Expression={if ($_.Status -eq "Running") { "✅" } else { "❌" }}},
            @{Name='Timestamp'; Expression={Get-Date -Format "yyyy-MM-dd HH:mm:ss"}}
            return $serviceResults
    }else {
        return @()
    }


}

$logonScript = {
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        ID = 4625,4771,4776
        StartTime = (Get-Date).AddMinutes(-1.1)} -ErrorAction SilentlyContinue

    if ($events.Count -gt 0){
        $LogonResults = $events | Select-Object @{Name='Server'; Expression={$env:COMPUTERNAME.ToUpper()}},
        @{Name='Timestamp'; Expression={$_.TimeCreated}},
        @{Name='User'; Expression={$_.Properties[5].Value}},
        @{Name='IP'; Expression={$_.Properties[19].Value}},
        @{Name='Logontype'; Expression={$_.Properties[8].Value}},
        @{Name='Status'; Expression={"❌"}}
        return $LogonResults
    }else {
        return @()
    }
}

$CSVtoHTML = {
    $csvPath = "C:\dfsroots\files\Log\Performance.csv"
    $htmlPath = "C:\inetpub\wwwroot\PerformanceOverview.html"

    $data = Import-Csv $csvPath


$style = @"
<style>
body {
    font-family: Segoe UI;
    background-color: #0f172a;
    color: #e5e7eb;
}
h1 {
    text-align: center;
    color: #38bdf8;
}
table {
    margin: auto;
    border-collapse: collapse;
    width: 95%;
}
th {
    background-color: #1e293b;
    color: #38bdf8;
    padding: 10px;
}
td {
    padding: 8px;
    text-align: center;
}
tr:nth-child(even) {
    background-color: #020617;
}
</style>
<meta http-equiv='refresh' content='30'>
"@

    $html = $data | ConvertTo-Html `
        -Head $style `
        -Title "Performance Overview" `
        -PreContent "<h1>Performance Overview</h1><meta http-equiv='refresh' content='30'>" `
        -PostContent "<p>Last updated: $(Get-Date)</p>"

    $html | Out-File $htmlPath -Encoding UTF8


    $csvPath = "C:\dfsroots\files\Log\Service.csv"
    $htmlPath = "C:\inetpub\wwwroot\ServiceOverview.html"

    $data = Import-Csv $csvPath

    $html = $data | ConvertTo-Html `
        -Head $style `
        -Title "Service Status" `
        -PreContent "<h1>Service Status</h1><meta http-equiv='refresh' content='30'>" `
        -PostContent "<p>Last updated: $(Get-Date)</p>"

    $html | Out-File $htmlPath -Encoding UTF8
}

$dataCollection = {
    $filePathPerformance = "\\SRV1\Log\Performance.csv"
    $filePathService = "\\SRV1\Log\Service.csv"
    $filePathLogon = "\\SRV1\Log\Logon.csv"

    #Ønsket testmaskiner
    $perfVMs = @("SRV1", "DC1", "MGR", "CL1")
    $servVMs = @("SRV1", "DC1")

    #Få inn verdier
    $PerformanceResults = Invoke-Command -ComputerName $perfVMs -ScriptBlock $performanceScript
    $ServiceResults = Invoke-Command -ComputerName $servVMs -ScriptBlock $serviceScript
    $LogonResults = Invoke-Command -ComputerName dc1 -ScriptBlock $logonScript
    
    #Log dem i csv
    $PerformanceResults | Export-Csv -Path $filePathPerformance -NoTypeInformation -Append
    $ServiceResults | Export-Csv -Path $filePathService -NoTypeInformation -Append
    $LogonResults | Export-Csv -Path $filePathLogon -NoTypeInformation -Append
    
    #ToHTML
    & $CSVtoHTML
}



$MonitorSystem = {
    #Paths
    $rootfolder = "C:\dfsroots\files"
    $logPath = "C:\dfsroots\files\Log"
    $filePathPerformance = "\\SRV1\Log\Performance.csv"
    $filePathService = "\\SRV1\Log\Service.csv"
    $filePathLogon = "\\SRV1\Log\Logon.csv"

    #Log duration
    $duration = 120
    $interval = 60
    $startTime = Get-Date 

    while ((New-TimeSpan -Start $startTime).TotalMinutes -lt $duration){
        if (!(Test-Path $logPath)) {
            New-Item -Path $rootfolder -ItemType Directory
        }

        if (!(Test-Path -Path $filePathPerformance)){
            New-Item -Path $filePathPerformance -ItemType "File"
            "Server,Counter,Value,Timestamp,Status" | Out-File -FilePath $filePathPerformance -Encoding UTF8
        }

        if (!(Test-Path -Path $filePathService)){
            New-Item -Path $filePathService -ItemType "File"
            "Server,Name,Status,Timestamp" | Out-File -FilePath $filePathService -Encoding UTF8
        }

        if (!(Test-Path -Path $filePathLogon)){
            New-Item -Path $filePathLogon -ItemType "File"
            "Server,Timestamp,User,IP,LogonType,Status" | Out-File -FilePath $filePathLogon -Encoding UTF8
        }

        & $dataCollection
        Start-Sleep -Seconds $interval
    }    
}

& $MonitorSystem






