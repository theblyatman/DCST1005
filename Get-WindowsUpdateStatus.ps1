<#
.SYNOPSIS
    Henter Windows Update status via Event Log
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = @('cl1.infrait.sec')
)

$Results = foreach ($Computer in $ComputerName) {
    Write-Host "`nSjekker $Computer..." -ForegroundColor Cyan
    
    try {
        $UpdateInfo = Invoke-Command -ComputerName $Computer -ErrorAction Stop -ScriptBlock {
            
            # Hent pending updates fra registry (uten COM!)
            $PendingUpdatesPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\Results\Install'
            
            if (Test-Path $PendingUpdatesPath) {
                $LastInstallResult = Get-ItemProperty -Path $PendingUpdatesPath
            }
            
            # Sjekk om updates venter på reboot
            $RebootRequired = $false
            $RebootPaths = @(
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
                'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            )
            
            foreach ($Path in $RebootPaths) {
                if (Test-Path $Path) {
                    $RebootRequired = $true
                    break
                }
            }
            
            # Hent siste successful update fra Event Log
            $LastSuccessfulUpdate = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
                ID = 19  # Installation Successful
            } -MaxEvents 1 -ErrorAction SilentlyContinue
            
            # Hent pending updates count fra Event Log
            $PendingUpdatesEvent = Get-WinEvent -FilterHashtable @{
                LogName = 'System'
                ProviderName = 'Microsoft-Windows-WindowsUpdateClient'
                ID = 44  # Updates detected
            } -MaxEvents 1 -ErrorAction SilentlyContinue
            
            # Parse message for update count
            $PendingCount = 0
            if ($PendingUpdatesEvent) {
                if ($PendingUpdatesEvent.Message -match '(\d+) updates') {
                    $PendingCount = [int]$Matches[1]
                }
            }
            
            # Hent siste reboot
            $OS = Get-CimInstance -ClassName Win32_OperatingSystem
            $LastBoot = $OS.LastBootUpTime
            
            # Return object
            [PSCustomObject]@{
                Computer = $env:COMPUTERNAME
                PendingUpdateCount = $PendingCount
                RebootRequired = $RebootRequired
                LastSuccessfulUpdate = if ($LastSuccessfulUpdate) { $LastSuccessfulUpdate.Message } else { "Ingen nylige updates funnet" }
                LastUpdateDate = if ($LastInstallResult) { $LastInstallResult.LastSuccessTime } else { "N/A" }
                LastReboot = $LastBoot
                DaysSinceReboot = [math]::Round(((Get-Date) - $LastBoot).TotalDays, 1)
            }
        }
        
        $UpdateInfo
        
    } catch {
        Write-Warning "Kunne ikke kontakte $Computer : $_"
        
        [PSCustomObject]@{
            Computer = $Computer
            PendingUpdateCount = 'ERROR'
            RebootRequired = 'ERROR'
            LastSuccessfulUpdate = $_.Exception.Message
            LastUpdateDate = $null
            LastReboot = $null
            DaysSinceReboot = 'N/A'
        }
    }
}

# Vis resultater
$Results | Format-Table -AutoSize -Wrap

# Generer HTML rapport
$HTML = $Results | ConvertTo-Html -Title "Windows Update Status - InfraIT.sec" -PreContent "<h1>Windows Update Compliance Report</h1><p>Generated: $(Get-Date)</p>"
$HTML | Out-File "C:\temp\UpdateStatus_$(Get-Date -Format 'yyyyMMdd_HHmm').html"

Write-Host "`nRapport generert: C:\temp\UpdateStatus_$(Get-Date -Format 'yyyyMMdd_HHmm').html" -ForegroundColor Green