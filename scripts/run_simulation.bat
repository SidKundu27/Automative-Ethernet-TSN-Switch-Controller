@echo off
REM Automotive TSN Switch Simulation Script (Batch)
REM Simple wrapper for PowerShell script

echo.
echo Automotive Ethernet TSN Switch Controller
echo =========================================
echo.

REM Check if PowerShell is available
powershell -Command "Get-Host" >nul 2>&1
if %errorlevel% neq 0 (
    echo ERROR: PowerShell is required but not found.
    echo Please install PowerShell and try again.
    pause
    exit /b 1
)

REM Check arguments and run PowerShell script
if "%1"=="" (
    echo Running complete test suite...
    powershell -ExecutionPolicy Bypass -File "run_simulation.ps1" all
) else if "%1"=="help" (
    powershell -ExecutionPolicy Bypass -File "run_simulation.ps1" help
) else if "%1"=="compile" (
    powershell -ExecutionPolicy Bypass -File "run_simulation.ps1" compile
) else if "%1"=="clean" (
    powershell -ExecutionPolicy Bypass -File "run_simulation.ps1" clean
) else (
    powershell -ExecutionPolicy Bypass -File "run_simulation.ps1" %*
)

echo.
echo Script execution completed.
if not "%1"=="help" pause
