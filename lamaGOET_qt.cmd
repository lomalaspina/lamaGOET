@echo off
setlocal
set "SCRIPT_DIR=%~dp0"

if defined LAMAGOET_QT_PYTHON goto custom_python
if exist "%SCRIPT_DIR%.venv-qt\Scripts\python.exe" goto private_python
where py >nul 2>nul
if not errorlevel 1 goto python_launcher
where python >nul 2>nul
if not errorlevel 1 goto system_python

echo lamaGOET Qt requires Python 3.10 or newer. 1>&2
echo Install it from https://www.python.org/downloads/ and run this file again. 1>&2
exit /b 2

:custom_python
"%LAMAGOET_QT_PYTHON%" "%SCRIPT_DIR%GUI_lamaGOET_qt.py" --mode local %*
exit /b %errorlevel%

:private_python
"%SCRIPT_DIR%.venv-qt\Scripts\python.exe" "%SCRIPT_DIR%GUI_lamaGOET_qt.py" --mode local %*
exit /b %errorlevel%

:python_launcher
py -3 "%SCRIPT_DIR%GUI_lamaGOET_qt.py" --mode local %*
exit /b %errorlevel%

:system_python
python "%SCRIPT_DIR%GUI_lamaGOET_qt.py" --mode local %*
exit /b %errorlevel%
