Param(
    [Int]$Pass=0,
    [Int]$MaxPasses=5,
    [String]$AutoLogonUsername="vagrant",
    [String]$AutoLogonPassword="vagrant",
    [String]$RestartResumeTriggerType="StartupFolder"
)

# =================================================================================================================
# ==== ERROR-HANDLING =============================================================================================
# =================================================================================================================
# Override default PowerShell behavior to NOT continue on error.
# See: http://stackoverflow.com/a/5851948 and link within post
$ErrorActionPreference = 'Stop'

# Trap and report any errors not being reported if this script is run with the -File option
trap
{
    Write-Output $_
    exit 1
}

# To trap errors of executing .exe's rather than plain old PowerShell code, wrap them in this function; e.g.:
#     exec { ping -someOption }
# This executes ping.exe, and will trap and report the error if it fails.
function Exec([ScriptBlock]$cmd, [string]$errorMessage = "Error executing command: " + $cmd) {
  & $cmd
  if ($LastExitCode -ne 0) {
    throw $errorMessage
  }
}

function ExecStr([String]$cmd, [string]$errorMessage = "Error executing command: " + $cmd) {
  [ScriptBlock]$sb = [ScriptBlock]::Create($cmd)
  Invoke-Command -ScriptBlock $sb
  if ($LastExitCode -ne 0) {
    throw $errorMessage
  }
}
# =================================================================================================================
# ==== END ERROR-HANDLING =========================================================================================
# =================================================================================================================

function LogInfo {
   Param ([string]$logstring)
   $now = Get-Date -format 'yyyy/MM/dd HH:mm:ss'
   [string]$logEntry = "$now [INFO] $logstring"
   $logEntry | Tee-Object -Append -FilePath $LogFile | Write-Host -ForegroundColor DarkGray
}

function LogDebug {
   Param ([string]$logstring)
   $now = Get-Date -format 'yyyy/MM/dd HH:mm:ss'
   [string]$logEntry = "$now [DEBUG] $logstring"
   $logEntry | Tee-Object -Append -FilePath $LogFile | Write-Host -ForegroundColor DarkYellow
}

function Create-RestartResumeTrigger() {
  if ($script:RestartResumeTriggerType -eq "Registry") {
    Create-RestartResumeTriggerRegistry
  }
  elseif ($script:RestartResumeTriggerType -eq "StartupFolder") {
    Create-RestartResumeTriggerStartupFolder
  }
}

function Create-RestartResumeTriggerRegistry() {
  Remove-RestartResumeTriggerRegistry
  $prop = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$script:ScriptPath`" -Pass $script:Pass -MaxPasses $script:MaxPasses -AutoLogonUsername $script:AutoLogonUsername -AutoLogonPassword $script:AutoLogonPassword -RestartResumeTriggerType $script:RestartResumeTriggerType"
  LogInfo "(Re)Creating Restart Registry Entry with value: `"$prop`""
  Set-ItemProperty -Path $script:RestartResumeRegistryKey -Name $script:RestartResumeRegistryEntry -Value "$prop"
}

function Create-RestartResumeTriggerStartupFolder() {
  Remove-RestartResumeTriggerStartupFolder
  LogInfo "(Re)Creating Restart script at path: `"$script:RestartResumeScriptPath`""
  $restartScript="Call PowerShell -NoProfile -ExecutionPolicy Bypass -File `"$script:ScriptPath`" -Pass $script:Pass -MaxPasses $script:MaxPasses -AutoLogonUsername $script:AutoLogonUsername -AutoLogonPassword $script:AutoLogonPassword -RestartResumeTriggerType $script:RestartResumeTriggerType"
  LogInfo "Creating restart script to call command: `"$restartScript`""
  New-Item "$script:RestartResumeScriptPath" -ItemType File -Force -Value $restartScript | Out-Null
}

function Remove-RestartResumeTrigger() {
  if ($script:RestartResumeTriggerType -eq "Registry") {
    Remove-RestartResumeTriggerRegistry
  }
  elseif ($script:RestartResumeTriggerType -eq "StartupFolder") {
    Remove-RestartResumeTriggerStartupFolder
  }
}

function Remove-RestartResumeTriggerRegistry() {
  $prop = (Get-ItemProperty $script:RestartResumeRegistryKey).$script:RestartResumeRegistryEntry
  if ($prop) {
      LogInfo "Restart Registry Entry Exists with value: `"$prop`" - Removing It"
      Remove-ItemProperty -Path $script:RestartResumeRegistryKey -Name $script:RestartResumeRegistryEntry -ErrorAction SilentlyContinue
  }
}

function Remove-RestartResumeTriggerStartupFolder() {
  if (Test-Path $script:RestartResumeScriptPath) {
    LogInfo "Restart script exists in startup folder at path: `"$script:RestartResumeScriptPath`" - Removing It"
    Remove-Item -Path $script:RestartResumeScriptPath -Force -ErrorAction SilentlyContinue
  }
}

function Check-ContinueRestartOrEnd() {
    $AutoLogonRegKey = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

    if ($script:IsRestartRequired) {
        Create-RestartResumeTrigger

        LogInfo "Setting AutoAdminLogon 1 time for user = $script:AutoLogonUsername and password = $script:AutoLogonPassword"
        Set-ItemProperty -Path $AutoLogonRegKey -Name "AutoAdminLogon" -Value "1" -type String
        Set-ItemProperty -Path $AutoLogonRegKey -Name "DefaultUsername" -Value "$script:AutoLogonUsername" -type String
        Set-ItemProperty -Path $AutoLogonRegKey -Name "DefaultPassword" -Value "$script:AutoLogonPassword" -type String
        Set-ItemProperty -Path $AutoLogonRegKey -Name "AutoLogonCount" -Value "1" -type DWord

        LogInfo "Restart Required - Restarting..."
        Restart-Computer
    }
    else {
        Remove-RestartResumeTrigger # Cleanup
        LogInfo "No Restart Required"
        Check-WindowsUpdates

        # Guard against recurisve update passes not requiring a restart
        if ($script:IsMoreUpdates -and ($script:Pass -le $script:MaxPasses)) {
            LogInfo "Found Windows Updates to Install - [Pass # $($script:Pass + 1)] Proceeding with download and install"
            Install-WindowsUpdates
        } elseif ($script:Pass -gt $script:MaxPasses) {
            LogInfo "Exceeded Max Number of Windows Update Passes ($script:MaxPasses) - Stopping"
        } else {
            LogInfo "Done Installing Windows Updates"
        }
    }
}

function Install-WindowsUpdates() {
    $script:Pass++
    LogInfo "Beginning Install of Available Updates"
    #DEBUGGING
    $sleepWork = Get-Random -minimum 2 -maximum 5
    LogDebug "Sleeping for $sleepWork to simulate installing updates"
    Start-Sleep -s $sleepWork
    #Invoke-Expression "Get-WUInstall $script:WUInstallOptions"
    $script:IsRestartRequired = $True
    #END DEBUGGING
    LogInfo "Completed Install of Available Updates"

    if ($(Get-WURebootStatus -Silent)) {
        LogInfo "Reboot found to be required after installing batch of updates. Initiating restart and recheck for updates."
        $script:IsRestartRequired = $True
    }

    Check-ContinueRestartOrEnd
}

function Check-WindowsUpdates() {
    LogInfo "Checking For Windows Updates"

    # Log into the Event Log execution of this script
    $Username = $env:USERDOMAIN + "\" + $env:USERNAME
    New-EventLog -Source $ScriptName -LogName 'Windows Powershell' -ErrorAction SilentlyContinue
    $Message = "Script: " + $ScriptPath + " `nScript User: " + $Username + " `nStarted: " + (Get-Date).toString()
    Write-EventLog -LogName 'Windows Powershell' -Source $ScriptName -EventID "104" -EntryType "Information" -Message $Message
    LogInfo $Message

    $successful = $False
    $attempts = 0
    $maxAttempts = 12
    while(-not $successful -and $attempts -lt $maxAttempts) {
        if ($attempts -gt 0)
        {
            LogDebug "Retrying Update Search. Attempt # $attempts"
        }
        if ($(Get-WUInstallerStatus -Silent)) { # if the Updates installer is busy, retry
            LogDebug "Windows Update Installer is Busy. Retrying in 20 seconds."
            $attempts++
            Start-Sleep -s 20
        }
        else {
            try {
                LogDebug "Searching for Updates with call to Get-WUInstall and options: $script:WUInstallOptions"
                $script:SearchResult = Invoke-Expression "Get-WUInstall -ListOnly $script:WUInstallOptions"
                $successful = $True
            } catch {
                LogDebug $_.Exception | Format-List -force
                LogDebug "Search call to Get-WUInstall with -ListOnly was unsuccessful. Retrying in 10s."
                $attempts++
                Start-Sleep -s 10
            }
        }
    }
    if ($attempts -eq $maxAttempts)
    {
        LogInfo "Failed to search for updates in $maxAttempts retry attempts - Aborting."
    }

    if ($SearchResult.Count -ne 0) {
        $Message = "There are " + $SearchResult.Count + " more updates."
        LogInfo $Message
        try {
            LogInfo $($SearchResult | Format-Table | Out-String)
            $script:IsMoreUpdates = $True
        } catch {
            LogInfo $_.Exception | Format-List -force
            LogInfo "Showing SearchResult was unsuccessful. Rebooting to retry."
            $script:IsRestartRequired = $True
            $script:IsMoreUpdates = $False
            Check-ContinueRestartOrEnd
            LogDebug "Failed to detect restart. Should not have reached here. Forcing Restart."
            Restart-Computer
        }
    } else {
        LogInfo "No applicable updates found."
        $script:IsRestartRequired = $False
        $script:IsMoreUpdates = $False
    }
}

# Script variables
$script:ScriptName = $MyInvocation.MyCommand.ToString()
$script:ScriptPath = $MyInvocation.MyCommand.Path
$script:ScriptDirectory = Split-Path -Parent -Path $MyInvocation.MyCommand.Path
$script:ScriptBoundParams = $($MyInvocation.BoundParameters | Out-String)
$script:ScriptUnboundArgs = $($MyInvocation.UnboundArguments | Out-String)

[Bool]$IsRestartRequired=$False
[Bool]$IsMoreUpdates=$False

$Logfile = "$scriptDirectory\win-updates.log"

$script:SearchResult = $null
$script:WUInstallOptions = "-MicrosoftUpdate -AcceptAll -IgnoreUserInput -IgnoreReboot -NotCategory 'Language Packs' -Confirm:`$False -ShowSearchCriteria -Verbose"

$script:RestartResumeRegistryKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run"
$script:RestartResumeRegistryEntry = "InstallWindowsUpdates"
$script:startupFolderPath = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
$script:RestartResumeScriptName = "resume-windows-updates.bat"
$script:RestartResumeScriptPath = "$script:startupFolderPath\$script:RestartResumeScriptName"

# Main entry point
if ($script:Pass -eq 0) {
    LogInfo "Starting Script $script:ScriptPath to begin batch installs of windows updates. With bound params: $script:ScriptBoundParams, and unbound args: $script:ScriptUnboundArgs"
}
else {
    LogInfo "Resuming Script $script:ScriptPath at pass $script:Pass to continue batch installs of windows updates. With bound params: $script:ScriptBoundParams, and unbound args: $script:ScriptUnboundArgs"
}

LogDebug "`$IsRestartRequired = $IsRestartRequired"
LogDebug "`$IsMoreUpdates = $IsMoreUpdates"
LogDebug "`$Pass = $Pass"
LogDebug "`$MaxPasses = $MaxPasses"
LogDebug "`$AutoLogonUsername = $AutoLogonUsername"
LogDebug "`$AutoLogonPassword = $AutoLogonPassword"
LogDebug "`$RestartResumeTriggerType = $RestartResumeTriggerType"

$psboundparameters.keys | ForEach {
    Write-Output "($_)=($($PSBoundParameters.$_))"
}

if ($script:Pass -gt $script:MaxPasses) {
    LogInfo "Exceeded Max Number of Windows Update Passes ($script:MaxPasses) - Stopping"
    Remove-RestartResumeTrigger # Cleanup
    Exit
}

Add-WUServiceManager -ServiceID 7971f918-a847-4430-9279-4a52d1efe18d -Confirm:$False # Register Microsoft Update service as a source for updates, to allow MS software to be updated too
Check-WindowsUpdates
if ($script:IsMoreUpdates) {
    Install-WindowsUpdates
} else {
    Check-ContinueRestartOrEnd
}
