@echo off
setlocal EnableExtensions DisableDelayedExpansion
pushd "%~dp0"
if errorlevel 1 goto folder_error
if not exist ".venv\Scripts\python.exe" goto wrong_folder
if not exist "config.py" goto wrong_folder
set "ICS_VISA_PYTHON=%CD%\.venv\Scripts\python.exe"
set "ICS_VISA_LOG=%CD%\VISA_DIAGNOSTIC.txt"
echo Checking Python and VISA. No instrument sessions will be opened.
echo Please wait for the report.
> "%ICS_VISA_LOG%" echo ICS VISA diagnostic. No instrument commands or configuration changes.
>> "%ICS_VISA_LOG%" echo.
>> "%ICS_VISA_LOG%" echo ===== Python environment =====
"%ICS_VISA_PYTHON%" -X utf8 -u -c "import sys,struct,platform,pyvisa; print('Python executable:',sys.executable); print('Python version:',sys.version); print('Pointer width:',struct.calcsize('P')*8); print('Windows:',platform.platform()); print('PyVISA:',pyvisa.__version__); print('PyVISA file:',pyvisa.__file__)" >> "%ICS_VISA_LOG%" 2>&1
>> "%ICS_VISA_LOG%" echo.
>> "%ICS_VISA_LOG%" echo ===== VISA discovery information =====
"%ICS_VISA_PYTHON%" -X utf8 -u -c "from pyvisa import util; util.get_debug_info()" >> "%ICS_VISA_LOG%" 2>&1
>> "%ICS_VISA_LOG%" echo.
>> "%ICS_VISA_LOG%" echo ===== Resource manager creation: no instruments opened =====
"%ICS_VISA_PYTHON%" -X utf8 -u -c "import pyvisa; from config import get_config; cfg=get_config(); backend=cfg.get('visa_library','@ivi'); print('Requested backend/library:',backend); pyvisa.log_to_screen(); rm=pyvisa.ResourceManager(backend); print('RESOURCE MANAGER OPENED:',rm.visalib); rm.close(); print('Resource manager closed successfully.')" >> "%ICS_VISA_LOG%" 2>&1
set "ICS_VISA_RESULT=%ERRORLEVEL%"
>> "%ICS_VISA_LOG%" echo Resource manager test exit code: %ICS_VISA_RESULT%
echo.
echo Diagnostic complete. Please send this file:
echo "%ICS_VISA_LOG%"
echo.
echo This diagnostic made no changes to your VISA installation or instruments.
popd
pause
exit /b 0
:wrong_folder
echo Put this file in ICS_python beside config.py and the .venv folder.
popd
pause
exit /b 1
:folder_error
echo Could not open the folder. Copy the program to a local PC folder first.
pause
exit /b 1
