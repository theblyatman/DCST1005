###############################################################################
# Deploy-HubSpokeVMs.ps1
#
# Deployer tre Linux VM-er (én per spoke) med nginx-webserver.
#
# Forutsetninger:
#   - Du er innlogget med Connect-AzAccount mot riktig tenant og subscription
#   - Hub VNET og spoke-VNETs er allerede opprettet
#   - Azure Firewall og DNAT-regler er allerede konfigurert
#   - Az PowerShell-modulen er installert (Install-Module -Name Az)
###############################################################################


###############################################################################
# VARIABLER — fyll inn dine egne verdier her
###############################################################################

$prefix            = 'nr04'                              # Ditt tildelte prefix
$location          = 'norwayeast'                        # Azure-region for alle ressurser

# Resource groups
$networkingRG      = "$prefix-rg-infraitsec-network"
$computeRG         = "$prefix-rg-infraitsec-compute"

# Brukernavn og passord for VM-ene (samme for alle tre)
$adminUsername     = 'azureuser'
$adminPassword     = 'Fv_215b-183'                      # Minst 12 tegn, store+små+tall+spesialtegn

# VM-størrelser
$vmSize            = 'Standard_B1s'

# ---------------------------------------------------------------------------
# Spoke 1 — eksisterende n-tier VNET
# ---------------------------------------------------------------------------
$spoke1VnetName    = "$prefix-vnet-infraitsec"
$spoke1SubnetName  = 'subnet-frontend'
$spoke1VmName      = "$prefix-vm-web-spoke1"
$spoke1VmIp        = '10.0.1.10'                         # Statisk privat IP i subnet-frontend

# ---------------------------------------------------------------------------
# Spoke 2
# ---------------------------------------------------------------------------
$spoke2VnetName    = "$prefix-vnet-spoke2"
$spoke2SubnetName  = 'subnet-workload'
$spoke2VmName      = "$prefix-vm-web-spoke2"
$spoke2VmIp        = '10.1.0.10'                         # Statisk privat IP i subnet-workload

# ---------------------------------------------------------------------------
# Spoke 3
# ---------------------------------------------------------------------------
$spoke3VnetName    = "$prefix-vnet-spoke3"
$spoke3SubnetName  = 'subnet-workload'
$spoke3VmName      = "$prefix-vm-web-spoke3"
$spoke3VmIp        = '10.2.0.10'                         # Statisk privat IP i subnet-workload

# ---------------------------------------------------------------------------
# Azure Firewall
# ---------------------------------------------------------------------------
$firewallName      = "$prefix-fw-hub"

# ---------------------------------------------------------------------------
# DNAT-porter
# ---------------------------------------------------------------------------
$httpPortSpoke1    = '8081'
$httpPortSpoke2    = '8082'
$httpPortSpoke3    = '8083'
$sshPortSpoke1     = '2221'
$sshPortSpoke2     = '2222'
$sshPortSpoke3     = '2223'


###############################################################################
# CLOUD-INIT — nginx installeres og startes automatisk ved første oppstart
# Hver VM får en unik HTML-side som identifiserer hvilken spoke den tilhører
###############################################################################

$cloudInitSpoke1 = @"
#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html>
        <head><title>Spoke 1</title></head>
        <body style="font-family:sans-serif; padding:2em; background:#e8f4f8;">
          <h1>&#x2705; Spoke 1 &mdash; Frontend</h1>
          <p><strong>InfraIT.sec Hub-Spoke Demo</strong></p>
          <p>VM: $spoke1VmName</p>
          <p>Privat IP: $spoke1VmIp</p>
          <p>Nettverk: $spoke1VnetName</p>
        </body>
      </html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
"@

$cloudInitSpoke2 = @"
#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html>
        <head><title>Spoke 2</title></head>
        <body style="font-family:sans-serif; padding:2em; background:#e8f8e8;">
          <h1>&#x2705; Spoke 2 &mdash; Workload</h1>
          <p><strong>InfraIT.sec Hub-Spoke Demo</strong></p>
          <p>VM: $spoke2VmName</p>
          <p>Privat IP: $spoke2VmIp</p>
          <p>Nettverk: $spoke2VnetName</p>
        </body>
      </html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
"@

$cloudInitSpoke3 = @"
#cloud-config
package_update: true
packages:
  - nginx
write_files:
  - path: /var/www/html/index.html
    content: |
      <!DOCTYPE html>
      <html>
        <head><title>Spoke 3</title></head>
        <body style="font-family:sans-serif; padding:2em; background:#f8f0e8;">
          <h1>&#x2705; Spoke 3 &mdash; Workload</h1>
          <p><strong>InfraIT.sec Hub-Spoke Demo</strong></p>
          <p>VM: $spoke3VmName</p>
          <p>Privat IP: $spoke3VmIp</p>
          <p>Nettverk: $spoke3VnetName</p>
        </body>
      </html>
runcmd:
  - systemctl enable nginx
  - systemctl restart nginx
"@


###############################################################################
# FUNKSJON: Deploy-SpokeVM
# Oppretter NIC (uten public IP) og VM med cloud-init i angitt subnet
###############################################################################

function Deploy-SpokeVM {
    param (
        [string]$VmName,
        [string]$VnetName,
        [string]$SubnetName,
        [string]$PrivateIpAddress,
        [string]$CloudInitContent,
        [string]$ResourceGroup,
        [string]$Location,
        [string]$AdminUsername,
        [string]$AdminPassword,
        [string]$VmSize,
        [string]$NetworkingRG
    )

    Write-Host "`n  Henter subnet '$SubnetName' fra '$VnetName'..." -ForegroundColor Gray
    $vnet   = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $NetworkingRG
    $subnet = Get-AzVirtualNetworkSubnetConfig -Name $SubnetName -VirtualNetwork $vnet

    Write-Host "  Oppretter NIC for $VmName..." -ForegroundColor Gray
    $ipConfig = New-AzNetworkInterfaceIpConfig `
        -Name 'ipconfig1' `
        -SubnetId $subnet.Id `
        -PrivateIpAddress $PrivateIpAddress `
        -PrivateIpAddressVersion IPv4 `
        -Primary

    $nic = New-AzNetworkInterface `
        -Name "$VmName-nic" `
        -ResourceGroupName $ResourceGroup `
        -Location $Location `
        -IpConfiguration $ipConfig `
        -Tag @{ Owner = $VmName; Environment = 'Lab'; Course = 'InfraIT-Cyber' }

    Write-Host "  Konfigurerer VM-objekt for $VmName..." -ForegroundColor Gray
    $credential = [PSCredential]::new(
        $AdminUsername,
        (ConvertTo-SecureString $AdminPassword -AsPlainText -Force)
    )

    $vmConfig = New-AzVMConfig -VMName $VmName -VMSize $VmSize |
        Set-AzVMOperatingSystem `
            -Linux `
            -ComputerName $VmName `
            -Credential $credential `
            -CustomData $CloudInitContent |
        Set-AzVMSourceImage `
            -PublisherName 'Canonical' `
            -Offer 'ubuntu-24_04-lts' `
            -Skus 'server' `
            -Version 'latest' |
        Add-AzVMNetworkInterface -Id $nic.Id |
        Set-AzVMOSDisk `
            -Name "$VmName-osdisk" `
            -CreateOption FromImage `
            -StorageAccountType Standard_LRS |
        Set-AzVMBootDiagnostic -Disable

    Write-Host "  Deployer $VmName (dette tar 1-2 minutter)..." -ForegroundColor Gray
    New-AzVM `
        -ResourceGroupName $ResourceGroup `
        -Location $Location `
        -VM $vmConfig `
        -Tag @{ Owner = $VmName; Environment = 'Lab'; Course = 'InfraIT-Cyber' } | Out-Null

    Write-Host "  $VmName opprettet." -ForegroundColor Green
}


###############################################################################
# STEG 1: Opprett compute resource group hvis den ikke finnes
###############################################################################

Write-Host "`n[1/3] Sjekker compute resource group..." -ForegroundColor Cyan

$rg = Get-AzResourceGroup -Name $computeRG -ErrorAction SilentlyContinue
if (-not $rg) {
    Write-Host "  Oppretter $computeRG..." -ForegroundColor Gray
    New-AzResourceGroup -Name $computeRG -Location $location `
        -Tag @{ Environment = 'Lab'; Course = 'InfraIT-Cyber' } | Out-Null
    Write-Host "  $computeRG opprettet." -ForegroundColor Green
} else {
    Write-Host "  $computeRG finnes allerede." -ForegroundColor Green
}


###############################################################################
# STEG 2: Deploy VM-er i alle tre spokes
###############################################################################

Write-Host "`n[2/3] Deployer VM-er i spoke 1, 2 og 3..." -ForegroundColor Cyan

Write-Host "`nSpoke 1:" -ForegroundColor White
Deploy-SpokeVM `
    -VmName           $spoke1VmName `
    -VnetName         $spoke1VnetName `
    -SubnetName       $spoke1SubnetName `
    -PrivateIpAddress $spoke1VmIp `
    -CloudInitContent $cloudInitSpoke1 `
    -ResourceGroup    $computeRG `
    -Location         $location `
    -AdminUsername    $adminUsername `
    -AdminPassword    $adminPassword `
    -VmSize           $vmSize `
    -NetworkingRG     $networkingRG

Write-Host "`nSpoke 2:" -ForegroundColor White
Deploy-SpokeVM `
    -VmName           $spoke2VmName `
    -VnetName         $spoke2VnetName `
    -SubnetName       $spoke2SubnetName `
    -PrivateIpAddress $spoke2VmIp `
    -CloudInitContent $cloudInitSpoke2 `
    -ResourceGroup    $computeRG `
    -Location         $location `
    -AdminUsername    $adminUsername `
    -AdminPassword    $adminPassword `
    -VmSize           $vmSize `
    -NetworkingRG     $networkingRG

Write-Host "`nSpoke 3:" -ForegroundColor White
Deploy-SpokeVM `
    -VmName           $spoke3VmName `
    -VnetName         $spoke3VnetName `
    -SubnetName       $spoke3SubnetName `
    -PrivateIpAddress $spoke3VmIp `
    -CloudInitContent $cloudInitSpoke3 `
    -ResourceGroup    $computeRG `
    -Location         $location `
    -AdminUsername    $adminUsername `
    -AdminPassword    $adminPassword `
    -VmSize           $vmSize `
    -NetworkingRG     $networkingRG


$firewall         = Get-AzFirewall -Name $firewallName -ResourceGroupName $networkingRG
$fwPublicIp       = $firewall.IpConfigurations[0].PublicIPAddress
$fwPipObj         = Get-AzPublicIpAddress -ResourceGroupName $networkingRG |
                        Where-Object { $_.Id -eq $fwPublicIp.Id }
$fwPublicIpAddress = $fwPipObj.IpAddress


###############################################################################
# STEG 3: Oppsummering
###############################################################################

Write-Host "`n[3/3] Deployment fullfort!" -ForegroundColor Cyan
Write-Host "`n==============================================" -ForegroundColor White
Write-Host " Tilgangsoversikt" -ForegroundColor White
Write-Host "==============================================" -ForegroundColor White
Write-Host "" 
Write-Host " HTTP-tilgang (aapnes i nettleser):" -ForegroundColor White
Write-Host "   Spoke 1:  http://$($fwPublicIpAddress):$httpPortSpoke1" -ForegroundColor Yellow
Write-Host "   Spoke 2:  http://$($fwPublicIpAddress):$httpPortSpoke2" -ForegroundColor Yellow
Write-Host "   Spoke 3:  http://$($fwPublicIpAddress):$httpPortSpoke3" -ForegroundColor Yellow
Write-Host ""
Write-Host " SSH-tilgang:" -ForegroundColor White
Write-Host "   Spoke 1:  ssh $adminUsername@$fwPublicIpAddress -p $sshPortSpoke1" -ForegroundColor Yellow
Write-Host "   Spoke 2:  ssh $adminUsername@$fwPublicIpAddress -p $sshPortSpoke2" -ForegroundColor Yellow
Write-Host "   Spoke 3:  ssh $adminUsername@$fwPublicIpAddress -p $sshPortSpoke3" -ForegroundColor Yellow
Write-Host "==============================================" -ForegroundColor White
Write-Host ""
Write-Host " NB: Cloud-init installerer nginx etter oppstart." -ForegroundColor Gray
Write-Host " Vent 2-3 minutter etter deployment foer HTTP-tilgang fungerer." -ForegroundColor Gray
Write-Host ""