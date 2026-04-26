@echo off
setlocal
call :find_bash
if errorlevel 1 exit /b %errorlevel%
"%BASH%" -- "%~dp0loop-edit-validator.sh" %*
exit /b %errorlevel%

:find_bash
for /f "tokens=*" %%B in ('where bash 2^>nul') do ( set "BASH=%%B" & exit /b 0 )
if exist "C:\Program Files\Git\bin\bash.exe" ( set "BASH=C:\Program Files\Git\bin\bash.exe" & exit /b 0 )
if exist "C:\Program Files (x86)\Git\bin\bash.exe" ( set "BASH=C:\Program Files (x86)\Git\bin\bash.exe" & exit /b 0 )
>&2 echo Humanize: bash not found. Install Git for Windows (https://git-scm.com/download/win) or see docs/install-for-claude.md#windows.
exit /b 127
