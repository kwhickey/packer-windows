echo [DEBUG] Checking for 7zip
if not exist "C:\Windows\Temp\7z920-x64.msi" (
    echo [DEBUG] Downloading 7zip
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://www.7-zip.org/a/7z920-x64.msi', 'C:\Windows\Temp\7z920-x64.msi')" <NUL
)
msiexec /qb /i C:\Windows\Temp\7z920-x64.msi
echo [DEBUG] 7zip installed

if "%PACKER_BUILDER_TYPE%" equ "vmware-iso" goto :vmware
if "%PACKER_BUILDER_TYPE%" equ "virtualbox-iso" goto :virtualbox
if "%PACKER_BUILDER_TYPE%" equ "parallels-iso" goto :parallels
goto :done

:vmware

echo [DEBUG] Beginning install of VMWare Tools

if exist "C:\Users\vagrant\windows.iso" (
    move /Y C:\Users\vagrant\windows.iso C:\Windows\Temp
)

if not exist "C:\Windows\Temp\windows.iso" (
    echo [DEBUG] Downloading VMWare Tools package
    powershell -Command "(New-Object System.Net.WebClient).DownloadFile('http://softwareupdate.vmware.com/cds/vmw-desktop/ws/12.0.0/2985596/windows/packages/tools-windows.tar', 'C:\Windows\Temp\vmware-tools.tar')" <NUL
    echo [DEBUG] Completed VMWare Tools package download
    cmd /c ""C:\Program Files\7-Zip\7z.exe" x C:\Windows\Temp\vmware-tools.tar -oC:\Windows\Temp"
    FOR /r "C:\Windows\Temp" %%a in (VMware-tools-windows-*.iso) DO REN "%%~a" "windows.iso"
    rd /S /Q "C:\Program Files (x86)\VMWare"
)

cmd /c ""C:\Program Files\7-Zip\7z.exe" x "C:\Windows\Temp\windows.iso" -oC:\Windows\Temp\VMWare"
echo [DEBUG] Starting VMWare tools setup.exe
cmd /c C:\Windows\Temp\VMWare\setup.exe /S /v"/qn REBOOT=R\"

echo [DEBUG] Completed install of VMWare Tools

goto :done

:virtualbox

echo [DEBUG] Beginning install of virtual box guest additions

:: There needs to be Oracle CA (Certificate Authority) certificates installed in order
:: to prevent user intervention popups which will undermine a silent installation.
cmd /c certutil -addstore -f "TrustedPublisher" A:\oracle-cert.cer

:: This script is setup with the assumption that the virtual box builder's "guest_additions_mode" value is set to "attach"
:: and is not the default of "upload".
:: Given that assumption and the assumption that this build is via an ISO that is also attached, the VBox Guest additions
:: files will be present at E:\
if not exist "E:\VBoxWindowsAdditions.exe" (
    echo [ERROR] Failed to find VBoxWindowsAdditions.exe in E:\. Ensure "guest_additions_mode" is "attach", and it would be mounted on that drive
    exit /b 1
)
cmd /c E:\VBoxWindowsAdditions.exe /S /with_autologon /with_wddm

echo [DEBUG] Completed install of virtual box guest additions
goto :done

:parallels
if exist "C:\Users\vagrant\prl-tools-win.iso" (
	move /Y C:\Users\vagrant\prl-tools-win.iso C:\Windows\Temp
	cmd /C "C:\Program Files\7-Zip\7z.exe" x C:\Windows\Temp\prl-tools-win.iso -oC:\Windows\Temp\parallels
	cmd /C C:\Windows\Temp\parallels\PTAgent.exe /install_silent
	rd /S /Q "c:\Windows\Temp\parallels"
)

:done
msiexec /qb /x C:\Windows\Temp\7z920-x64.msi
