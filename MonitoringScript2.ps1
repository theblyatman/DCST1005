
##Funksjon som monitorerer CPU, RAM, Disk, Network og Service status på ønskede maskiner og returnerer resultatet
$performanceScript =  {

    ##Counters (sensor/ytelsesmålinger) vi ønsker å monitorere
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

    ##Henter inn ytelsesmålingene basert på counters vi definerte over
    $counterData = Get-Counter -Counter $counters

    ##En slags Select spørring på counterData. CounterSamples er en property i counterData som inneholder alle målingene vi hentet inn. 
    ##For hver måling, lager vi et objekt med Server, Counter, Value, Timestamp og Status
    $PerformanceResults = $counterData.CounterSamples | Select-Object @{Name='Server'; Expression={$env:COMPUTERNAME.ToUpper()}},
                    @{Name='Counter'; Expression={($_.Path -split '\\')[-1].ToUpper()}},
                    @{Name='Value'; Expression={[math]::Round($_.CookedValue, 2)}},
                    @{Name='Timestamp'; Expression={Get-Date -Format "yyyy-MM-dd HH:mm:ss"}},
                    @{Name='Status'; Expression={
                                ##Gir oss navnet på counteren ved å splitte Path på '\' og 
                                ##ta siste element i arrayet, som er navnet på counteren
                                $counter = ($_.Path -split '\\')[-1]
                                ##CookedValue er selve målingen vi fikk inn, og vi runder den av til 2 desimaler
                                $value = $_.CookedValue
                                ##Basert på navnet på counteren, sjekker vi om verdien er innenfor ønsket range, og gir en status basert på det
                                switch -Wildcard ($counter) {
                                    ##Hvis counter er Processor Time, sjekker vi om verdien er under 80%, og gir grønn hvis den er det, ellers rød
                                    "*Processor Time*" { if ($value -lt 80) { "✅" } else { "❌" } }
                                    "*Queue Length*"   { if ($value -lt 2) { "✅" } else { "❌" } }
                                    "*Available MBytes*" { if ($value -gt 1000) { "✅" } else { "❌" } }
                                    "*Committed Bytes*" { if ($value -lt 80) { "✅" } else { "❌" } }
                                    "*Free Space*" { if ($value -gt 15) { "✅" } else { "❌" } }
                                    "*Disk Transfers*" { if ($value -lt 200) { "✅" } else { "❌" } }
                                    "*Packets*" { if ($value -eq 0) { "✅" } else { "❌" } }
                                    ##Dersom ingen counter traffer får vi hvit
                                    default { "⚪" }}}}
    ##Returnerer resultatet av ytelsesmålingene på det formatet vi definerte i Selecten,
    ## som er Server, Counter, Value, Timestamp og Status
    return $PerformanceResults
}
##Funksjon som monitorerer ønskede tjenester basert på hvilken maskin det er, og returnerer resultatet
$serviceScript = {
    ##Dersom PCen scriptet kjører på for øyeblikket er dc1, er ønskede tjenester som står under
    $Server = $env:COMPUTERNAME.ToLower()
    if ($Server -eq "dc1"){
        $Services = "NTDS", "DNS", "KDC", "DFSR", "Netlogon"

    ##Hvis det er srv1, er ønskede tjenester som står under
    }elseif ($Server -eq "srv1"){
        $Services = "DFS", "W3SVC"
    ##Hvis det er manager eller client, da er det tomt
    } else{
        $Services = @()
    }
    ##Iffen sjekker at vi ikke kjører kommandoer på en tom array, atlså for manager og client
    if ($Services.Count -gt 0){
        ##Henter in counterdata for tjenester definert over
        $servicesData = Get-Service -Name $Services
        ##Piper det inn i selecten og lager et rad med Server, Name, Status og Timestamp for hver tjeneste vi hentet inn
        $serviceResults = $servicesData | Select-Object @{Name='Server'; Expression={$env:COMPUTERNAME.ToUpper()}},
            @{Name='Name'; Expression={$_.Name}},
            @{Name='Status'; Expression={if ($_.Status -eq "Running") { "✅" } else { "❌" }}},
            @{Name='Timestamp'; Expression={Get-Date -Format "yyyy-MM-dd HH:mm:ss"}}
            ##Returnerer resultatet av tjenestestatusen på det formatet vi definerte i Selecten,
            return $serviceResults
    }else {
        ##ellers ingen rader i tabellen
        return @()
    }


}
##Scriptet som overvåker innloggingsforsøk som blir lagret på DC1 og dekker helle infra domenet
$logonScript = {
    ##Henter eventlogg og setter på en riktig filter 
    $events = Get-WinEvent -FilterHashtable @{
        LogName = 'Security'
        #4625 - Failed logon
        #4771 - Et eller annet Kerberos pre-authentication
        #4776 - Et eller annet NTLM 
        ID = 4625,4771,4776
        ##Siden vi monitorer hver minutt, så setter vi time span som skjekker 1 min og 6 sec tilbake i tid
        StartTime = (Get-Date).AddMinutes(-1.1)} -ErrorAction SilentlyContinue

    ##Hvis filtret har noen counters så pipes vi det i selecten og lager en rad i tabellen 
    ##med Server, Timestamp, User, IP, LogonType og Status for hver event som traff filteret
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
##
$CSVtoHTML = {
    ##Henter inn data fra csv filene som blir logget av de andre scriptfunksjonene
    $csvPath = "C:\dfsroots\files\Log\Performance.csv"
    ##Lager en HTML fil basert på dataen i csv filen
    $htmlPath = "C:\inetpub\wwwroot\PerformanceOverview.html"
    ##Import-Csv lager et objekt av csv filen, der hver rad i csv filen blir et objekt i $data
    #og kolonne navnene i csv filen blir properties på objektene
    $data = Import-Csv $csvPath

##Stilen på HTML tabellen, som er en slags CSS kode som definerer hvordan tabellen skal se ut.
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
##Lager en HTML fil basert på dataen i csv filen, og bruker stilen vi definerte over.
    ##Piper rad/objektet fra CSV filen inn i ConvertTO-html
    $html = $data | ConvertTo-Html `
        -Head $style ` #Bruker stilen vi definerte over i head på HTML filen
        -Title "Performance Overview" ` #Tittelen på HTML filen
        -PreContent "<h1>Performance Overview</h1><meta http-equiv='refresh' content='30'>" ` #
        -PostContent "<p>Last updated: $(Get-Date)</p>"

    ##Lagrer HTML filen på ønsket path
    $html | Out-File $htmlPath -Encoding UTF8

    ##Samme som over bare for Service CSV objekter/rader
    $csvPath = "C:\dfsroots\files\Log\Service.csv"
    $htmlPath = "C:\inetpub\wwwroot\ServiceOverview.html"

    $data = Import-Csv $csvPath

    $html = $data | ConvertTo-Html `
        -Head $style `
        -Title "Service Status" `
        -PreContent "<h1>Service Status</h1><meta http-equiv='refresh' content='30'>" `
        -PostContent "<p>Last updated: $(Get-Date)</p>"
    ##OutFile med append legger inn nye entries i HTML filen basert på dataen i csv filen
    $html | Out-File $htmlPath -Encoding UTF8 
}

##En slags mellom funksjon som sjekker om loggfilene og HTML filene eksisterer, og hvis ikke, lager de det.
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


##Hoved funksjon som samler alt og kjører det i en loop for å monitorere systemet i en ønsket varighet og interval
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
    ##Kjører så lengde varigheten er mindre enn ønsket varighet, og kjører dataCollection scriptet i ønsket interval
    while ((New-TimeSpan -Start $startTime).TotalMinutes -lt $duration){
        ##Sjekker om logg mappa eksisterer
        if (!(Test-Path $logPath)) {
            ##Lager en hvis det ikke eksisterer
            New-Item -Path $rootfolder -ItemType Directory
        }
        ##Sjekker om performance csv fil eksisterer.
        if (!(Test-Path -Path $filePathPerformance)){
            ##Hvis ikke lager den en fil og setter noen kolonne navn 
            New-Item -Path $filePathPerformance -ItemType "File"
            "Server,Counter,Value,Timestamp,Status" | Out-File -FilePath $filePathPerformance -Encoding UTF8
        }
        #Sjekker om service csv fil eksisterer, og gjør det samme som over
        if (!(Test-Path -Path $filePathService)){
            New-Item -Path $filePathService -ItemType "File"
            "Server,Name,Status,Timestamp" | Out-File -FilePath $filePathService -Encoding UTF8
        }
        #Sjekker om logon csv fil eksisterer, og gjør det samme som over
        if (!(Test-Path -Path $filePathLogon)){
            New-Item -Path $filePathLogon -ItemType "File"
            "Server,Timestamp,User,IP,LogonType,Status" | Out-File -FilePath $filePathLogon -Encoding UTF8
        }
        ##Kjører dataCollection scriptet, som henter inn data
        & $dataCollection
        Start-Sleep -Seconds $interval ##Loopen venter i ønsket interval
    }    
}

##Kjører alt sammen
& $MonitorSystem






