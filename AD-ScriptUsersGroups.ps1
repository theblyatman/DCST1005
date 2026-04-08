##Random navn liste generert av CHATGPT
$name_pool = "Alice", "Bob", "Charlie", "David", "Emma", "Frank", "Grace", "Hannah", "Ian", "Julia",
"Kevin", "Laura", "Michael", "Nina", "Oscar", "Paula", "Quentin", "Rachel", "Samuel", "Tina",
"Ulf", "Victoria", "William", "Xander", "Yara", "Zoe", "Andreas", "Benjamin", "Clara", "Daniel",
"Elena", "Felix", "Gabriel", "Ida", "Jonas", "Katrine", "Lukas", "Marius", "Noah", "Sara"

##Liste med departments og antall brukere vi ønsker i hver
$team_roles = "HR", "Sales", "Finance", "IT", "Consultants"
$team_count = 1, 2, 1, 2, 9

##Iterator for å lage brukere og legge de 
$count = -1
##Itererer gjennom hver department i team_roles
foreach ($role in $team_roles) {
  $count += 1
  ##For hver department, itererer vi gjennom antall brukere vi ønsker i den departmenten, som er definert i team_count
  ## 1..1 - 1..2 - 1..1 - 1..2 - 1..9
  foreach ($i in 1..$team_count[$count]){
    ##Velger ut filfeldig navn
    $name = Get-Random $name_pool
    ##Lager et domain navn for brukeren ved å kombinere navnet, et tall og rollen, og konvertere det til små bokstaver
    $ProfName =($name+"0."+$role).ToLower()
    ##Lager et passord for brukeren
    $SecurePassword = ConvertTo-SecureString "P@ssw0rd123!" -AsPlainText -Force
    ##Har en variabelm et tall som starter på 0, og så lenge det finnes en bruker med samme SamAccountName i AD,
    ## så øker det tallet med 1 og lager et nytt SamAccountName ved å kombinere navnet med det gamle navnet
    $num = 0
    while (Get-ADUser -Filter "SamAccountName -eq '$ProfName'" -ErrorAction SilentlyContinue) {
          ##Dette sikrer at alle domene brukere er unike, selv om det er flere med samme navn og rolle, ved å legge til et tall i SamAccountName
          $num += 1
          $ProfName =($name+$num+"."+$role).ToLower()
    }

    $SecurePassword = ConvertTo-SecureString $SecurePassword -AsPlainText -Force
    ##Oppretter en ny AD-bruker med de genererte verdiene, og plasserer den i en OU basert på rollen
    New-ADUser `
        -Name "$name ($role)" `                               ##Nikita (HR)
        -GivenName $name `                                    ##Nikita
        -Surname $role `                                      ##HR
        -SamAccountName $ProfName `                           ##nikita0
        -UserPrincipalName "$ProfName@InfraIT.sec" `          ##nikita0.hr@InfraIT.sec
        -AccountPassword $SecurePassword `                    ##P@ssw0rd123!
        -ChangePasswordAtLogon $true `                        ##Ber brukeren om å endre passord ved første innlogging
        -Enabled $true `                                      ##Aktiverer brukeren
        -Path "OU=$role,OU=InfraIT_Users,DC=InfraIT,DC=sec"   ##Plasserer brukeren i en OU basert på rollen


    ##Plasserer brukeren i en global gruppe basert på rollen
    ##Finner gruppen basert på rollen ved å kombinere "g_all_" med rollen og konvertere det til små bokstaver
    $GroupName = "g_all_"+$role.ToLower()

    ##Sjekker først om gruppa eksisterer 
    if (!(Get-ADGroup -Filter "Name -eq '$GroupName'" -ErrorAction SilentlyContinue)) {

          Write-Host "Gruppa $GroupName finnes ikke" -ForegroundColor Red

    ##Sjekker om brukeren allerede er medlem av gruppa
    } elseif (Get-ADGroupMember -Identity $GroupName | Where-Object { $_.SamAccountName -eq $ProfName }){

      Write-Host "$ProfName finnes alerede i gruppa $GroupName" -ForegroundColor Red
    ##Hvis gruppa eksisterer og brukeren ikke er medlem, legger vi til brukeren i gruppa
    } else{

      Add-ADGroupMember -Identity $GroupName -Members $ProfName
      Write-Host "$ProfName ble lagt til i gruppa $GroupName" -ForegroundColor Green

    }
  }
}




