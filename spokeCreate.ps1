#########################################################
# Variabler — endre disse til dine egne verdier
#########################################################

$prefix            = 'nr04'       # Ditt tildelte prefix
$resourceGroupName = "$prefix-rg-infraitsec-network"
$location          = 'norwayeast'  # Husk å endre til samme region/location som du har brukt tidligere

# Spoke 2
$spoke2VnetName    = "$prefix-vnet-spoke2"
$spoke2AddressSpace = '10.1.0.0/16'
$spoke2SubnetName  = 'subnet-workload'
$spoke2SubnetPrefix = '10.1.0.0/24'

# Spoke 3
$spoke3VnetName    = "$prefix-vnet-spoke3"
$spoke3AddressSpace = '10.2.0.0/16'
$spoke3SubnetName  = 'subnet-workload'
$spoke3SubnetPrefix = '10.2.0.0/24'

#########################################################
# Opprett spoke 2
#########################################################

Write-Host "Oppretter $spoke2VnetName..." -ForegroundColor Cyan

$spoke2Subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $spoke2SubnetName `
    -AddressPrefix $spoke2SubnetPrefix

New-AzVirtualNetwork `
    -Name $spoke2VnetName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $spoke2AddressSpace `
    -Subnet $spoke2Subnet `
    -Tag @{ Owner = "nikitar@stud.ntnu.no"; Environment = 'Lab'; Course = 'InfraIT.sec'; Purpose = 'Spoke2' }

Write-Host "$spoke2VnetName opprettet." -ForegroundColor Green

#########################################################
# Opprett spoke 3
#########################################################

Write-Host "Oppretter $spoke3VnetName..." -ForegroundColor Cyan

$spoke3Subnet = New-AzVirtualNetworkSubnetConfig `
    -Name $spoke3SubnetName `
    -AddressPrefix $spoke3SubnetPrefix

New-AzVirtualNetwork `
    -Name $spoke3VnetName `
    -ResourceGroupName $resourceGroupName `
    -Location $location `
    -AddressPrefix $spoke3AddressSpace `
    -Subnet $spoke3Subnet `
    -Tag @{ Owner = "nikitar@stud.ntnu.no"; Environment = 'Lab'; Course = 'InfraIT.sec' ; Purpose = 'Spoke3' }

Write-Host "$spoke3VnetName opprettet." -ForegroundColor Green

Write-Host "`nFerdig! Begge spoke-nettverk er opprettet." -ForegroundColor Green