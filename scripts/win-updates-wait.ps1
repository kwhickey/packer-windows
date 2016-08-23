$vagrantCred = New-Object System.Management.Automation.PSCredential ("vagrant", $(ConvertTo-SecureString "vagrant" -AsPlainText -Force))

Invoke-Command -ComputerName 127.0.0.1 -Port 3782 -Credential $vagrantCred { Get-WmiObject Win32_ComputerSystem }
Test-WSMan -ComputerName 127.0.0.1 -Port 3782


function SlurpOutput($l) {
  if (Test-Path $log) {
    Get-Content $log | select -skip $l | ForEach {
      $l += 1
      Write-Host "$_"
    }
  }
  return $l
}
$line = 0
do {
  Start-Sleep -m 100
  $line = SlurpOutput $line
} while (!($t.state -eq 3))


$StartTime = Get-Date

$CurrentWaitTime = 0

Write-Output 'Starting Wait'
while ($true) {
	Write-Output "Minutes Elapsed: $CurrentWaitTime"
	$CurrentWaitTime += 5
	Start-Sleep -s 300

	if ($CurrentWaitTime -ge 180) {
		Write-Output 'Waited 180 Minutes. Exiting'
		break
	}
}

# get Firefox process
$firefox = Get-Process firefox -ErrorAction SilentlyContinue
if ($firefox) {
  # try gracefully first
  $firefox.CloseMainWindow()
  # kill after five seconds
  Sleep 5
  if (!$firefox.HasExited) {
    $firefox | Stop-Process -Force
  }
}
Remove-Variable firefox