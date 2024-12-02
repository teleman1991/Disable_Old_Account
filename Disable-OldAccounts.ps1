# Disable-OldAccounts.ps1
# Script to silently disable Windows user accounts that have been inactive for more than 90 days

# Run the script with minimal priority to reduce system impact
$Process = Get-Process -Id $pid
$Process.PriorityClass = 'BelowNormal'

# Suppress all warning messages and errors from display
$ErrorActionPreference = 'SilentlyContinue'
$WarningPreference = 'SilentlyContinue'
$ProgressPreference = 'SilentlyContinue'

# Set up silent logging
$LogFile = "C:\ProgramData\AccountMaintenance\Logs\DisableAccounts_$(Get-Date -Format 'yyyyMMdd').log"
$LogDir = Split-Path $LogFile -Parent

# Silently create log directory if it doesn't exist
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force -ErrorAction SilentlyContinue | Out-Null
}

function Write-Log {
    param($Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Add-Content -Path $LogFile -Value $LogMessage -ErrorAction SilentlyContinue
}

# Get the cutoff date (90 days ago)
$CutoffDate = (Get-Date).AddDays(-90)

Write-Log "Script started silently"

try {
    # Get all local user accounts without displaying output
    $Users = Get-LocalUser | Where-Object {
        $_.Enabled -eq $true -and 
        $_.LastLogon -ne $null -and 
        $_.LastLogon -lt $CutoffDate -and 
        $_.Name -notlike "Administrator" -and 
        $_.Name -notlike "DefaultAccount" -and 
        $_.Name -notlike "WDAGUtilityAccount" -and
        $_.Name -notlike "*$"
    }

    if ($Users.Count -eq 0) {
        Write-Log "No inactive accounts found"
    }
    else {
        Write-Log "Found $($Users.Count) inactive account(s)"
        
        foreach ($User in $Users) {
            try {
                # Check if user is currently logged in
                $CurrentUser = (Get-WMIObject -class Win32_ComputerSystem).Username
                if ($CurrentUser -notlike "*$($User.Name)") {
                    # Disable the account silently
                    Disable-LocalUser -Name $User.Name -ErrorAction SilentlyContinue
                    Write-Log "Disabled account: $($User.Name) - Last logon: $($User.LastLogon)"
                } else {
                    Write-Log "Skipped currently logged-in user: $($User.Name)"
                }
            }
            catch {
                Write-Log "Failed to process account $($User.Name): $_"
            }
        }
    }
}
catch {
    Write-Log "Script error: $_"
}

# Export results silently to CSV
$ExportPath = "C:\ProgramData\AccountMaintenance\Reports\DisabledAccounts_$(Get-Date -Format 'yyyyMMdd').csv"
$ExportDir = Split-Path $ExportPath -Parent

if (!(Test-Path $ExportDir)) {
    New-Item -ItemType Directory -Path $ExportDir -Force -ErrorAction SilentlyContinue | Out-Null
}

$Users | Select-Object Name, LastLogon, Enabled | Export-Csv -Path $ExportPath -NoTypeInformation -ErrorAction SilentlyContinue
Write-Log "Script completed"
