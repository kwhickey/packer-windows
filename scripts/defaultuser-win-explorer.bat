:: Load the DefaultUser hive into HKLM
reg load HKLM\DefaultUser C:\Users\Default\NTUSER.DAT

:: Show file extensions in Explorer
%SystemRoot%\System32\reg.exe ADD HKLM\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v HideFileExt /t REG_DWORD /d 0 /f
%SystemRoot%\System32\reg.exe ADD HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v HideFileExt /t REG_DWORD /d 0 /f

:: Show hidden files Explorer
%SystemRoot%\System32\reg.exe ADD HKLM\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Hidden /t REG_DWORD /d 1 /f
%SystemRoot%\System32\reg.exe ADD HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Hidden /t REG_DWORD /d 1 /f

:: Show Run command in Start Menu
%SystemRoot%\System32\reg.exe ADD HKLM\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Start_ShowRun /t REG_DWORD /d 1 /f
%SystemRoot%\System32\reg.exe ADD HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v Start_ShowRun /t REG_DWORD /d 1 /f

:: Show Administrative Tools in Start Menu
%SystemRoot%\System32\reg.exe ADD HKLM\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v StartMenuAdminTools /t REG_DWORD /d 1 /f
%SystemRoot%\System32\reg.exe ADD HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\ /v StartMenuAdminTools /t REG_DWORD /d 1 /f

:: Enable QuickEdit mode in console
%SystemRoot%\System32\reg.exe ADD HKLM\DefaultUser\Console /v QuickEdit /t REG_DWORD /d 1 /f
%SystemRoot%\System32\reg.exe ADD HKCU\Console /v QuickEdit /t REG_DWORD /d 1 /f

reg unload HKLM\DefaultUser
