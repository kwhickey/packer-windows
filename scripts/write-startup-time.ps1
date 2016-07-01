$startup = "$env:appdata\Microsoft\Windows\Start Menu\Programs\Startup"
$longDateTime = Get-Date -Format 'yyyy-MM-dd-HH-mm-ss'
New-Item -ItemType File -Path "$startup\$longDateTime.txt" -Value "$longDateTime" | Out-Null
