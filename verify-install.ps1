# Verifisering av installasjon
Write-Host "`n=== Verifikasjon av utviklingsmiljø ===" -ForegroundColor Cyan

# Sjekk PowerShell-versjon
Write-Host "`nPowerShell versjon:" -ForegroundColor Green
$PSVersionTable.PSVersion

# Sjekk Chocolatey
Write-Host "`nChocolatey versjon:" -ForegroundColor Green
choco --version

# Sjekk Git
Write-Host "`nGit versjon:" -ForegroundColor Green
git --version

# Sjekk Git-konfigurasjon
Write-Host "`nGit-konfigurasjon:" -ForegroundColor Green
Write-Host "Navn: $(git config --global user.name)"
Write-Host "E-post: $(git config --global user.email)"

# Sjekk VS Code
Write-Host "`nVS Code versjon:" -ForegroundColor Green
code --version

Write-Host "`n=== Alle verktøy er installert! ===" -ForegroundColor Green