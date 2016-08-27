Param(
  [string]$BuilderProvider="virtualbox",
  [string]$VmOs="windows_2012_r2",
  [string]$BaseBoxNamePrefix=$VmOs, 
  [string]$BaseBoxName="$BaseBoxNamePrefix" + "_" + "$BuilderProvider",
  [string]$VagrantVmName=$BaseBoxName,
  [string]$VmDir="$(Resolve-Path ~)\VirtualMachines",
  [string]$VagrantDir="$VmDir\Vagrant",
  [string]$PackerTemplatesDir="$(Resolve-Path .)",
  [string]$PackerTemplateFileName="$VmOs.json",
  [bool]$PackerLog=$False
)

# Time script duration
$start = Get-Date

# Log params in invocation
$params = @()
$MyInvocation.MyCommand.Parameters.Keys | ForEach {
  $var = Get-Variable -Name $_ -ErrorAction SilentlyContinue;
  if ($var)
  {
    $params += $var
  }
}
Write-Output "[INFO] Script called with params:`n"
Write-Output $params | ft

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
#     Exec "ping -someOption $hostIp" # best to use with inline variables to interpolate 
# Or
#     Exec { ping 127.0.0.1 } # best used when no inline variables to interpolate
# This executes ping.exe, and will trap and report the error if it fails.
function Exec([string]$cmd, [string]$errorMessage = "[ERROR] Error executing command: " + $cmd) {
  $sb = [ScriptBlock]::Create($cmd.ToString() + " | Write-Output") # Piping to output will force Invoke-Command to wait on Win32 executable to finish
  Write-Output "[DEBUG] Invoking ScriptBlock: $sb"
  Invoke-Command -ScriptBlock $sb -OutVariable output
  if ($LastExitCode -ne 0) {
    $errorMessage = $errorMessage + "`nOutput was:`n$output"
    throw $errorMessage
  }
}
# ==== END: ERROR-HANDLING =========================================================================================

# Ensure required directories are present
if (-not (Test-Path -PathType Container "$VmDir")) {
  New-Item -ItemType Directory -Force -Path "$VmDir" | Out-Null
}

if (-not (Test-Path -PathType Container "$VagrantDir")) {
  New-Item -ItemType Directory -Force -Path "$VagrantDir" | Out-Null
}

if (-not (Test-Path -PathType Container "$VagrantDir\BaseBoxes")) {
  New-Item -ItemType Directory -Force -Path "$VagrantDir\BaseBoxes" | Out-Null
}

if (-not (Test-Path -PathType Container "$VagrantDir\$VagrantVmName")) {
  New-Item -ItemType Directory -Force -Path "$VagrantDir\$VagrantVmName" | Out-Null
}

# If re-creating a vagrant box, erase any pre-existing vagrant box of the same name
# NOTE: This will completely destroy and erase the box if found with the same name
# If this is not the desired behavior, comment out these 4 lines, but risk the vagrant steps failing at the end if it finds a collision in names
cd "$VagrantDir\$VagrantVmName"
if ($(& { vagrant status }) -like "*running*") { Exec { vagrant halt; } }
if ($(& { vagrant status }) -like "*poweroff*") { Exec { vagrant destroy -f; } }
if ($(& { vagrant box list }) -like "*$VagrantVmName*") { Exec { vagrant box remove $VagrantVmName } }

# Having PACKER_LOG set to ANYTHING will enable debug logging to console
if ($PackerLog) {
  New-Item Env:\PACKER_LOG -Value 1 -ErrorAction SilentlyContinue
}
else {
  Remove-Item Env:\PACKER_LOG -ErrorAction SilentlyContinue # Having PACKER_LOG set to ANYTHING will enable debug logging to console
}

# Build the base box with Packer
cd "$PackerTemplatesDir"
Exec "packer validate -only=$BuilderProvider-iso $VmOs.json"
Exec "packer build -only=$BuilderProvider-iso -var `'output_dir=$VagrantDir\BaseBoxes`' -var `'box_name_prefix=$BaseBoxNamePrefix`'  $VmOs.json"

# Add the outputted base box to vagrant, and bring it up
cd "$VagrantDir\$VagrantVmName"
Exec "vagrant box add --name $VagrantVmName `"$VagrantDir\BaseBoxes\$BaseBoxName.box`""
Exec "vagrant init $VagrantVmName"
Exec { vagrant up }
Exec { vagrant rdp }

$end = Get-Date
Write-Output -ForegroundColor Green ('Total Runtime: ' + (New-TimeSpan -Start $start -End $end).ToString())