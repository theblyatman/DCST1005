##Listen med alle grupper i OU InfraIT_Groups
$GroupList = Get-ADGroup -SearchBase "OU=InfraIT_Groups,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
##Prefixer vi ønsker å bruke for gruppene
$Prefix = "HR", "Sales", "Finance", "IT", "Consultants" 

##Itererer gjennom prefixene
foreach ($group in $Prefix){
    ##Lager et gruppenavn ved å kombinere prefixet med "g_all_" og konvertere det til små bokstaver
    $groups = "g_all_" + $group.ToLower()
    ##Sjekker om gruppen eksisterer i listen med OUs inn i InfraIT_Groups
    ##Skipper dersom finnes, ellers oppretter den gruppen
    if ($GroupList -contains $groups){
        Write-Host "$groups eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        $OutPutString = $group.ToUpper() 
        New-ADGroup -Name $groups -SamAccountName $groups -GroupCategory Security -GroupScope Global -Path "OU=InfraIT_Groups,DC=InfraIT,DC=sec" -Description "Global group for $OutPutString"
        Write-Host "La til gruppe $groups" -ForegroundColor Green
    }
} 