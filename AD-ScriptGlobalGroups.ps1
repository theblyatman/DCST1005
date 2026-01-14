
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