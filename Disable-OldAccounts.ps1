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
        Write-Log "No inactive local accounts found"
    }
    else {
        Write-Log "Found $($Users.Count) inactive local account(s)"
        
        foreach ($User in $Users) {
            try {
                # Check if user is currently logged in
                $CurrentUser = (Get-WMIObject -class Win32_ComputerSystem).Username
                if ($CurrentUser -notlike "*$($User.Name)") {
                    # Disable the account silently
                    Disable-LocalUser -Name $User.Name -ErrorAction SilentlyContinue
                    Write-Log "Disabled local account: $($User.Name) - Last logon: $($User.LastLogon)"
                    
                    # Remove user profile folder
                    $ProfilePath = "C:\Users\$($User.Name)"
                    if (Test-Path $ProfilePath) {
                        Remove-Item -Path $ProfilePath -Recurse -Force -ErrorAction SilentlyContinue
                        Write-Log "Deleted profile folder for local user: $($User.Name)"
                    }
                } else {
                    Write-Log "Skipped currently logged-in local user: $($User.Name)"
                }
            }
            catch {
                Write-Log "Failed to process local account $($User.Name): $_"
            }
        }
    }

    # Remove user profile folders that haven't been modified in the last 90 days
    $ProfileFolders = Get-ChildItem -Path "C:\Users" -Directory | Where-Object {
        ($_.LastWriteTime -lt $CutoffDate) -and 
        ($_.Name -notlike "Administrator") -and 
        ($_.Name -notlike "DefaultAccount") -and 
        ($_.Name -notlike "WDAGUtilityAccount") -and
        ($_.Name -notlike "*$")
    }

    if ($ProfileFolders.Count -eq 0) {
        Write-Log "No old profile folders found"
    }
    else {
        Write-Log "Found $($ProfileFolders.Count) old profile folder(s)"
        
        foreach ($ProfileFolder in $ProfileFolders) {
            try {
                Remove-Item -Path $ProfileFolder.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Deleted old profile folder: $($ProfileFolder.Name)"
            }
            catch {
                Write-Log "Failed to delete profile folder $($ProfileFolder.Name): $_"
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
