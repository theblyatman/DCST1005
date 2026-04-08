## Script for creating OUs in Active Directory
# Level 1 OUs: de mest generelle;
$LEVEL1_OU = "InfraIT_Users", "InfraIT_Computers", "InfraIT_Groups"

#Remove-ADOrganizationalUnit -Identity "OU=UserAccounts,DC=InfraIT,DC=sec" -Recursive -Confirm:$False

#New-ADOrganizationalUnit -Name "UserAccounts" -Path "OU=UserAccounts,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False

#New-ADGroup -Name "RODC Admins" -SamAccountName RODCAdmins -GroupCategory Security -GroupScope Global -Path "CN=Users,DC=Fabrikam,DC=Com" -Description "Global group"

#Liste med OUs i domenet, skal egentlig ikke være noen ous, men sjekker hele domenet sånn at vi er clean start.
$AD_OUs1 = Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty Name

##For hver OU i lvl1 listen, sjekk om den finnes i domenet, hvis den gjør det så skip, hvis ikke så opprett den.
foreach ($L1 in $LEVEL1_OU){
    if ($AD_OUs1 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
}   

##Liste med target OUs, altså departments og datamaskinstyper
$LEVEL2_OU = "Workstations", "Servers"
$LEVEL3_OU = "HR", "Sales", "Finance", "IT", "Consultants"

##Først får opp alle ous inn i InfraIT_Users OU vi lagde i forrige loop
$AD_OUs12 = Get-ADOrganizationalUnit -SearchBase "OU=InfraIT_Users,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
##InfraIT_Users
foreach ($L1 in $LEVEL3_OU){
    #Sjekker om deparment OU finnes allerede i InfraIT_Users, hvis den gjør det så skip, hvis ikke så opprett den.
    if ($AD_OUs12 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=InfraIT_Users,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
} 
##Får opp alle OUs i InfraIT_Computers OU som vi lagde i forrige loop
$AD_OUs21 = Get-ADOrganizationalUnit -SearchBase "OU=InfraIT_Computers,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name

##InfraIT_Computers
foreach ($L1 in $LEVEL2_OU){
    ##Dersom InfraIT_Computers OU allerede har en OU som heter det samme som i LEVEL2_OU så skip, hvis ikke så opprett den.
    if ($AD_OUs21 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=InfraIT_Computers,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
} 

##Får opp alle OUs i Workstation OU som vi lagde i forrige loop
$AD_OUs22 = Get-ADOrganizationalUnit -SearchBase "OU=Workstations,OU=InfraIT_Computers,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
foreach ($L1 in $LEVEL3_OU){
    ##Dersom Workstations har allerede en department OU som heter det samme som i LEVEL3_OU så skip, hvis ikke så opprett den.
    if ($AD_OUs22 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=Workstations,OU=InfraIT_Computers,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
} 