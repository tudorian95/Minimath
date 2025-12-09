@echo off
ECHO Minikube Deployment Script - Requires Administrator Access.

:: Check for Administrator privilege
net session >nul 2>&1
IF %errorLevel% NEQ 0 (
    ECHO Relaunching with Administrator privileges...
    
    :: Use PowerShell to relaunch this same batch file with elevation
    powershell -Command "Start-Process '%~dpnx0' -Verb RunAs"
    EXIT /B
)

:: --- Set the correct working directory BEFORE running the PS script ---
CD /D "%~dp0"

ECHO Running Minikube Deployment Script...

:: --- Run the PowerShell script ---
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "deploy.ps1"

:: --- Keep the window open after the script finishes ---
ECHO.
ECHO --- SCRIPT FINISHED ---
PAUSE