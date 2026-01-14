
$LEVEL1_OU = "InfraIT_Users", "InfraIT_Computers", "InfraIT_Groups"

#Remove-ADOrganizationalUnit -Identity "OU=UserAccounts,DC=InfraIT,DC=sec" -Recursive -Confirm:$False

#New-ADOrganizationalUnit -Name "UserAccounts" -Path "OU=UserAccounts,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False

#New-ADGroup -Name "RODC Admins" -SamAccountName RODCAdmins -GroupCategory Security -GroupScope Global -Path "CN=Users,DC=Fabrikam,DC=Com" -Description "Global group"

$AD_OUs1 = Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty Name

foreach ($L1 in $LEVEL1_OU){
    if ($AD_OUs1 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
}   

$LEVEL2_OU = "Workstations", "Servers"
$LEVEL3_OU = "HR", "Sales", "Finance", "IT", "Consultants"


$AD_OUs12 = Get-ADOrganizationalUnit -SearchBase "OU=InfraIT_Users,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name

foreach ($L1 in $LEVEL3_OU){
    if ($AD_OUs12 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=InfraIT_Users,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
} 
$AD_OUs21 = Get-ADOrganizationalUnit -SearchBase "OU=InfraIT_Computers,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
foreach ($L1 in $LEVEL2_OU){
    if ($AD_OUs21 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=InfraIT_Computers,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
} 

$AD_OUs22 = Get-ADOrganizationalUnit -SearchBase "OU=Workstations,OU=InfraIT_Computers,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
foreach ($L1 in $LEVEL3_OU){
    if ($AD_OUs22 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=Workstations,OU=InfraIT_Computers,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
} 