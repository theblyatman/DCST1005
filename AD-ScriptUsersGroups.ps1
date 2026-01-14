
$name_pool = "Alice", "Bob", "Charlie", "David", "Emma", "Frank", "Grace", "Hannah", "Ian", "Julia",
"Kevin", "Laura", "Michael", "Nina", "Oscar", "Paula", "Quentin", "Rachel", "Samuel", "Tina",
"Ulf", "Victoria", "William", "Xander", "Yara", "Zoe", "Andreas", "Benjamin", "Clara", "Daniel",
"Elena", "Felix", "Gabriel", "Ida", "Jonas", "Katrine", "Lukas", "Marius", "Noah", "Sara"

$team_roles = "HR", "Sales", "Finance", "IT", "Consultants"
$team_count = 1, 2, 1, 2, 9


$count = -1
foreach ($role in $team_roles) {
  $count += 1
  foreach ($i in 1..$team_count[$count]){
    $name = Get-Random $name_pool
    $ProfName =($name+"0."+$role).ToLower()
    $SecurePassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
    $num = 0

    while (Get-ADUser -Filter "SamAccountName -eq '$ProfName'" -ErrorAction SilentlyContinue) {
          $num += 1
          $ProfName =($name+$num+"."+$role).ToLower()
    }

    $SecurePassword = ConvertTo-SecureString $SecurePassword -AsPlainText -Force
    New-ADUser `
  -Name "$name ($role)" `
  -GivenName $name `
  -Surname $role `
  -SamAccountName $ProfName `
  -UserPrincipalName "$ProfName@InfraIT.sec" `
  -AccountPassword $SecurePassword `
  -ChangePasswordAtLogon $true `
  -Enabled $true `
  -Path "OU=$role,OU=InfraIT_Users,DC=InfraIT,DC=sec"


    $GroupName = "g_all_"+$role.ToLower()

  if (!(Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue)) {

        Write-Host "Gruppa $GroupName finnes ikke" -ForegroundColor Red

  } elseif (Get-ADGroupMember -Identity $GroupName | Where-Object { $_.SamAccountName -eq $ProfName }){

    Write-Host "$ProfName finnes alerede i gruppa $GroupName" -ForegroundColor Red

  } else{

    Add-ADGroupMember -Identity $GroupName -Members $ProfName
    Write-Host "$ProfName ble lagt til i gruppa $GroupName" -ForegroundColor Green

  }
  }
}




