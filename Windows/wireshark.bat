@echo off
rem Figure out path to plink.exe
set putty_dir_key="HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\PuTTY_is1"
for /f "tokens=3*" %%x in ('reg query %putty_dir_key% /v "InstallLocation"') do set putty_dir=%%x %%y
if not defined putty_dir (
    echo Please install PuTTY using Windows installer from http://www.chiark.greenend.org.uk/~sgtatham/putty/download.html
    exit /b 1
)
set plink="%putty_dir%\plink.exe"

rem Figure out path to wireshark.exe
set wireshark_dir_key="HKLM\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Wireshark"
for /f "tokens=3*" %%x in ('reg query %wireshark_dir_key% /v "InstallLocation"') do set wireshark_dir=%%x %%y
if not defined wireshark_dir (
    echo Please install Wireshark using Windows installer from https://www.wireshark.org/download.html
    exit /b 1
)
set wireshark="%wireshark_dir%\Wireshark.exe"

rem Ask for hostname if not specified as first parameter
set host=%1
if not defined host set /p host= What SSH host do you want to capture from? 

set pw=%2
if not defined pw set /p pw= Password? 


rem Ask for interface if not specified as second parameter
set iface=%3
if not defined iface (
    %plink% root@%host%  -pw %pw% "tcpdump -D"
    set /p iface= What interface do you want to capture from? 
)

rem Run tcpdump with output to pipe and read pipe from wireshark
%plink% -ssh root@%host% -pw %pw% "tcpdump -ni %iface% -s 0 -w - not port 22" | %wireshark% -k -i -"
