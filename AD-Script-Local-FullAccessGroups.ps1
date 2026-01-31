$Groups= "global", "local"

$AD_OUs22 = Get-ADOrganizationalUnit -SearchBase "OU=InfraIT_Groups,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
foreach ($L1 in $Groups){
    if ($AD_OUs22 -contains $L1){
        Write-Host "$L1 eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADOrganizationalUnit -Name $L1 -Path "OU=InfraIT_Groups,DC=InfraIT,DC=sec" -ProtectedFromAccidentalDeletion $False
        Write-Host "La til OU $L1" -ForegroundColor Green
    }
}



$FullAccess = "l_fullAccess-hr-share","l_fullAccess-it-share","l_fullAccess-sales-share","l_fullAccess-finance-share","l_fullAccess-consultants-share"
$AD_OU_G = Get-ADOrganizationalUnit -SearchBase "OU=local,OU=InfraIT_Groups,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
foreach ($NG in $FullAccess){
    if ($AD_OU_G -contains $NG){
        Write-Host "$NG eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        New-ADGroup -Name $NG -SamAccountName $NG -GroupCategory Security -GroupScope Global -Path "OU=local,OU=InfraIT_Groups,DC=InfraIT,DC=sec" -Description "Global group for $NG"
        Write-Host "La til OU $NG" -ForegroundColor Green
    }

}

$Groups2 = Get-ADGroup -Filter 'Name -like "g_*"' |
           Where-Object {
               $_.DistinguishedName -notlike '*OU=global,OU=InfraIT_Groups*'
           }

foreach ($G2 in $Groups2){
    Move-ADObject `
      -Identity $G2.DistinguishedName `
      -TargetPath "OU=global,OU=InfraIT_Groups,DC=InfraIT,DC=sec"

    Write-Host "Flyttet $($G2.Name) til global" -ForegroundColor Green
}


$GroupList = Get-ADGroup -SearchBase "OU=InfraIT_Groups,DC=InfraIT,DC=sec" -SearchScope OneLevel -Filter * | Select-Object -ExpandProperty Name
$Prefix = "HR", "Sales", "Finance", "IT", "Consultants" 
foreach ($group in $Prefix){
    $groups = "g_all_" + $group.ToLower()
    if ($GroupList -contains $groups){
        Write-Host "$groups eksisterer allerede: skipper den" -ForegroundColor Yellow
    } else {
        $OutPutString = $group.ToUpper() 
        New-ADGroup -Name $groups -SamAccountName $groups -GroupCategory Security -GroupScope Global -Path "OU=InfraIT_Groups,DC=InfraIT,DC=sec" -Description "Global group for $OutPutString"
        Write-Host "La til gruppe $groups" -ForegroundColor Green
    }
} 