Param(
  [string]$VmDir="$(Resolve-Path ~)\VirtualMachines",
  [string]$VagrantDir="$(Resolve-Path $VmDir)\Vagrant",
  [string]$PackerTemplatesDir="$(Resolve-Path .)",
  [bool]$PackerLog=$False
)

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
function Exec([scriptblock]$cmd, [string]$errorMessage = "Error executing command: " + $cmd) {
  & $cmd
  if ($LastExitCode -ne 0) {
    throw $errorMessage
  }
}

cd "$VagrantDir\windows_2012_r2_virtualbox"
if ($(Exec { vagrant status }) -like "*running*") { Exec { vagrant halt; } }
if ($(Exec { vagrant status }) -like "*poweroff*") { Exec { vagrant destroy -f; } }
if ($(Exec { vagrant box list }) -like "*windows_2012_r2_virtualbox*") { Exec { vagrant box remove windows_2012_r2_virtualbox } }
cd "$PackerTemplatesDir"

# Having PACKER_LOG set to ANYTHING will enable debug logging to console
if ($PackerLog) {
  New-Item Env:\PACKER_LOG -Value 1 -ErrorAction SilentlyContinue
}
else {
  Remove-Item Env:\PACKER_LOG -ErrorAction SilentlyContinue # Having PACKER_LOG set to ANYTHING will enable debug logging to console
}

Exec { packer validate -only=virtualbox-iso .\windows_2012_r2.json; }
Exec { packer build -only=virtualbox-iso .\windows_2012_r2.json; }
Exec { vagrant box add --name windows_2012_r2_virtualbox "$VagrantDir\BaseBoxes\windows_2012_r2_virtualbox.box" }
cd "$VagrantDir\windows_2012_r2_virtualbox"
Exec { vagrant up; }
Exec { vagrant rdp; }
