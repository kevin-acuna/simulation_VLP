@echo off
setlocal EnableExtensions DisableDelayedExpansion
pushd "%~dp0"
if errorlevel 1 goto folder_error
if not exist "run_ics.py" goto wrong_folder
if not exist "config.py" goto wrong_folder
if not exist ".venv\Scripts\python.exe" goto wrong_folder
set "ICS_KEYSIGHT_PYTHON=%CD%\.venv\Scripts\python.exe"
set "ICS_KEYSIGHT_DLL_DIR=%ProgramW6432%\Keysight\IO Libraries Suite\bin"
if not defined ProgramW6432 set "ICS_KEYSIGHT_DLL_DIR=%ProgramFiles%\Keysight\IO Libraries Suite\bin"
set "ICS_KEYSIGHT_FIX_LOG=%CD%\VISA_KEYSIGHT_FIX_LOG.txt"

echo ICS Keysight VISA compatibility launcher
echo This adds a DLL search folder only inside this Python session.
echo This startup check opens no instrument sessions and changes no drivers or system settings.
echo.
if not exist "%ICS_KEYSIGHT_DLL_DIR%\" goto missing_directory

echo Checking VISA with Keysight dependency search enabled...
"%ICS_KEYSIGHT_PYTHON%" -X utf8 -u -c "import os,sys,struct; print('Python:',sys.executable); print('Python version:',sys.version); print('Pointer width:',struct.calcsize('P')*8); sys.exit('Python 3.12 64-bit required') if sys.version_info[:2]!=(3,12) or struct.calcsize('P')!=8 else None; folder=os.environ['ICS_KEYSIGHT_DLL_DIR']; print('Adding DLL directory:',folder); _ics_dll_handle=os.add_dll_directory(folder); import pyvisa; from config import get_config; backend=get_config().get('visa_library','@ivi'); print('Requested VISA library:',backend); pyvisa.log_to_screen(); rm=pyvisa.ResourceManager(backend); print('VISA CHECK PASSED:',rm.visalib); rm.close(); print('Resource manager closed. No instrument sessions were opened.')" > "%ICS_KEYSIGHT_FIX_LOG%" 2>&1
if errorlevel 1 goto visa_failed

type "%ICS_KEYSIGHT_FIX_LOG%"
echo.
echo VISA check passed. Opening the normal ICS Python prompt.
echo Keep using this launcher so the DLL search folder remains available.
echo At the prompt, run prepare, connect and check as before.
echo.
"%ICS_KEYSIGHT_PYTHON%" -X utf8 -i -c "import os,runpy; _ics_keysight_dll_handle=os.add_dll_directory(os.environ['ICS_KEYSIGHT_DLL_DIR']); globals().update(runpy.run_path('run_ics.py',run_name='__main__'))"
if errorlevel 1 goto launch_failed
popd
exit /b 0

:visa_failed
echo.
echo VISA could not start even with the additional Keysight DLL folder.
type "%ICS_KEYSIGHT_FIX_LOG%"
echo.
echo Please send VISA_KEYSIGHT_FIX_LOG.txt from this folder.
echo No instrument sessions were opened and no system settings were changed.
popd
pause
exit /b 1

:missing_directory
> "%ICS_KEYSIGHT_FIX_LOG%" echo The standard 64-bit Keysight DLL directory was not found.
>> "%ICS_KEYSIGHT_FIX_LOG%" echo Checked: "%ICS_KEYSIGHT_DLL_DIR%"
type "%ICS_KEYSIGHT_FIX_LOG%"
echo Your Keysight installation may use a different location.
echo Please send VISA_KEYSIGHT_FIX_LOG.txt. Do not reinstall working drivers yet.
popd
pause
exit /b 1

:wrong_folder
echo Put this file inside ICS_python, beside run_ics.py and config.py.
echo The .venv folder created by the dependency setup must also be here.
popd
pause
exit /b 1

:launch_failed
echo Python did not finish normally. Keep the full error above.
popd
pause
exit /b 1

:folder_error
echo Could not open the program folder. Use a permanent local PC folder.
pause
exit /b 1
