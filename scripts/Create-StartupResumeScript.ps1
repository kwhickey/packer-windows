$startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
$restartScript="Call PowerShell -NoProfile -ExecutionPolicy bypass -File `"C:\Windows\Temp\write-startup-time.ps1`""
#write-host $restartScript
New-Item -Path "$startup\write-startup-time.bat" -type file -force -value $restartScript | Out-Null
