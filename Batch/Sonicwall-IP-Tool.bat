@echo off
setlocal
title Ethernet 4 - IP Switcher

:: ============================================================
:: Self-elevate to Administrator
:: ============================================================
net session >nul 2>&1
if %errorlevel% neq 0 (
    echo Requesting Administrator privileges...
    powershell -NoProfile -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:MENU
cls
echo ============================================================
echo                  ETHERNET 4 - IP TOOL
echo ============================================================
echo.
echo   Current configuration:
echo.
netsh interface ipv4 show config name="Ethernet 4"
echo.
echo ============================================================
echo.
echo   [1] STATIC - 192.168.168.169 / 255.255.255.0
echo       No Gateway / No DNS
echo.
echo   [2] DHCP - Automatic IP and DNS
echo.
echo   [3] Show ipconfig
echo.
echo   [Q] Quit
echo.
echo ============================================================
echo.

choice /C 123Q /N /M "Choose an option: "

if errorlevel 4 goto END
if errorlevel 3 goto IPCONFIG
if errorlevel 2 goto DHCP
if errorlevel 1 goto STATIC


:STATIC
cls
echo ============================================================
echo                     SETTING STATIC
echo ============================================================
echo.
echo Adapter : Ethernet 4
echo IP      : 192.168.168.169
echo Mask    : 255.255.255.0
echo Gateway : NONE
echo DNS     : NONE
echo.

netsh interface ipv4 set address name="Ethernet 4" ^
    source=static ^
    address=192.168.168.169 ^
    mask=255.255.255.0 ^
    gateway=none

netsh interface ipv4 delete dnsservers name="Ethernet 4" all >nul 2>&1

echo.
echo Done!
echo.
netsh interface ipv4 show config name="Ethernet 4"

echo.
pause
goto MENU


:DHCP
cls
echo ============================================================
echo                     RESTORING DHCP
echo ============================================================
echo.

netsh interface ipv4 set address name="Ethernet 4" source=dhcp
netsh interface ipv4 set dnsservers name="Ethernet 4" source=dhcp

echo.
echo Requesting a DHCP lease...
ipconfig /renew "Ethernet 4"

echo.
echo Done!
echo.
netsh interface ipv4 show config name="Ethernet 4"

echo.
pause
goto MENU


:IPCONFIG
cls
ipconfig /all
echo.
pause
goto MENU


:END
exit
