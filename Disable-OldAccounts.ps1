# Disable-OldAccounts.ps1
# Script to disable Windows user accounts that have been inactive for more than 90 days

# Set error action preference
$ErrorActionPreference = "Continue"

# Set up logging
$LogFile = "C:\Logs\DisableAccounts_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$LogDir = Split-Path $LogFile -Parent

# Create log directory if it doesn't exist
if (!(Test-Path $LogDir)) {
    New-Item -ItemType Directory -Path $LogDir -Force
}

function Write-Log {
    param($Message)
    $LogMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Add-Content -Path $LogFile -Value $LogMessage
    Write-Output $LogMessage
}

# Get the cutoff date (90 days ago)
$CutoffDate = (Get-Date).AddDays(-90)

Write-Log "Script started - Looking for accounts inactive for more than 90 days (before $CutoffDate)"

try {
    # Get all local user accounts
    $Users = Get-LocalUser | Where-Object {
        $_.Enabled -eq $true -and 
        $_.LastLogon -ne $null -and 
        $_.LastLogon -lt $CutoffDate -and 
        $_.Name -notlike "Administrator" -and 
        $_.Name -notlike "DefaultAccount" -and 
        $_.Name -notlike "WDAGUtilityAccount"
    }

    if ($Users.Count -eq 0) {
        Write-Log "No inactive accounts found that meet the criteria"
    }
    else {
        Write-Log "Found $($Users.Count) inactive account(s)"
        
        foreach ($User in $Users) {
            try {
                # Disable the account
                Disable-LocalUser -Name $User.Name
                Write-Log "Successfully disabled account: $($User.Name) - Last logon: $($User.LastLogon)"
            }
            catch {
                Write-Log "ERROR: Failed to disable account $($User.Name): $_"
            }
        }
    }
}
catch {
    Write-Log "ERROR: Script encountered an error: $_"
}

Write-Log "Script completed"

# Export results to CSV for reference
$ExportPath = "C:\Logs\DisabledAccounts_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
$Users | Select-Object Name, LastLogon, Enabled | Export-Csv -Path $ExportPath -NoTypeInformation
Write-Log "Results exported to $ExportPath"