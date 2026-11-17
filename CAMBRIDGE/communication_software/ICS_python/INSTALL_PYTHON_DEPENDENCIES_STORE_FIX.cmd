@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "ICS_SETUP_STAGE=Opening the program folder"
set "ICS_CHECK_ONLY="
if /i "%~1"=="--check-python" set "ICS_CHECK_ONLY=1"
pushd "%~dp0"
if errorlevel 1 goto folder_error

echo ICS Python dependency setup - Microsoft Store detection fix
echo Internet access is required for package installation. No instruments will be connected.
echo.
if defined ICS_CHECK_ONLY goto locate_python
if not exist "requirements.txt" goto missing_files
if not exist "selftest.py" goto missing_files

:locate_python
if exist ".venv\Scripts\python.exe" goto environment_ready
set "ICS_SETUP_STAGE=Finding a working Python 3.12 64-bit interpreter"
set "ICS_BASE_PYTHON="
rem Versioned Store aliases take priority over unversioned aliases.
call :probe_python "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.12.exe"
call :probe_python "%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
call :probe_python "%ProgramFiles%\Python312\python.exe"
for /f "delims=" %%P in ('where.exe python3.12.exe 2^>nul') do call :probe_python "%%P"
for /f "delims=" %%P in ('where.exe python.exe 2^>nul') do call :probe_python "%%P"
for /f "delims=" %%P in ('where.exe python3.exe 2^>nul') do call :probe_python "%%P"
call :probe_python "%LOCALAPPDATA%\Microsoft\WindowsApps\python.exe"
call :probe_python "%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe"
if defined ICS_BASE_PYTHON goto create_environment

rem Keep the traditional launcher as a final fallback; do not request installation.
where.exe py.exe >nul 2>&1
if errorlevel 1 goto missing_python
set "PYLAUNCHER_ALLOW_INSTALL="
set "PYLAUNCHER_ALWAYS_INSTALL="
py.exe -3.12 -c "import sys,struct; print('ICS_PYTHON_312_X64' if sys.version_info[:2]==(3,12) and struct.calcsize('P')==8 else 'ICS_WRONG_PYTHON')" 2>nul | "%SystemRoot%\System32\findstr.exe" /x /c:"ICS_PYTHON_312_X64" >nul
if errorlevel 1 goto missing_python
py.exe -3.12 -c "import sys; print('Detected Python:',sys.executable); print(sys.version)"
if defined ICS_CHECK_ONLY goto check_success
set "ICS_SETUP_STAGE=Creating the project Python environment"
py.exe -3.12 -m venv ".venv"
if errorlevel 1 goto failed
goto environment_ready

:create_environment
echo Found a compatible Python interpreter:
echo "%ICS_BASE_PYTHON%"
if defined ICS_CHECK_ONLY goto check_success
set "ICS_SETUP_STAGE=Creating the project Python environment"
"%ICS_BASE_PYTHON%" -m venv ".venv"
if errorlevel 1 goto failed

:environment_ready
set "ICS_ENV_PYTHON=%CD%\.venv\Scripts\python.exe"
set "ICS_SETUP_STAGE=Checking the project Python environment"
"%ICS_ENV_PYTHON%" -c "import sys,struct; print('Using:',sys.executable); print('Python:',sys.version); ok=sys.version_info[:2]==(3,12) and struct.calcsize('P')==8; sys.exit(0 if ok else 'This project environment must use Python 3.12 64-bit')"
if errorlevel 1 goto failed

if defined ICS_CHECK_ONLY goto check_success

set "ICS_SETUP_STAGE=Updating pip"
echo.
echo Updating pip...
"%ICS_ENV_PYTHON%" -m pip install --upgrade pip
if errorlevel 1 goto failed

set "ICS_SETUP_STAGE=Installing the dependencies"
echo.
echo Installing dependencies from requirements.txt...
"%ICS_ENV_PYTHON%" -m pip install -r "requirements.txt"
if errorlevel 1 goto failed
"%ICS_ENV_PYTHON%" -m pip check
if errorlevel 1 goto failed

set "ICS_SETUP_STAGE=Checking package imports"
"%ICS_ENV_PYTHON%" -c "import numpy,scipy,matplotlib,pyvisa; print('Dependencies OK'); print('NumPy',numpy.__version__,'SciPy',scipy.__version__,'Matplotlib',matplotlib.__version__,'PyVISA',pyvisa.__version__)"
if errorlevel 1 goto failed

set "ICS_SETUP_STAGE=Running the offline self-tests"
echo.
echo Running self-tests. Please wait...
"%ICS_ENV_PYTHON%" "selftest.py"
if errorlevel 1 goto failed

echo.
echo SUCCESS: dependencies installed and all self-tests passed.
echo Your Visual Studio / VS Code Python interpreter should be:
echo "%ICS_ENV_PYTHON%"
echo.
echo To open the program later, double-click start_python.cmd.
echo No hardware has been connected or started.
popd
pause
exit /b 0

:missing_files
echo Put this file INSIDE your extracted ICS_python folder,
echo beside requirements.txt and selftest.py, then double-click it again.
goto failed

:missing_python
echo No working Python 3.12 64-bit interpreter could be verified.
echo If you installed Microsoft Store Python, open Start and search for:
echo Manage App Execution Aliases
echo Enable the aliases belonging to Python 3.12, then run this file again.
echo Check that the installed app is Python 3.12 from the Python Software Foundation.
echo A different Python version will not pass this check.
echo You do not need to uninstall your existing Python.
goto failed

:failed
echo.
echo SETUP STOPPED during: %ICS_SETUP_STAGE%
echo Keep this window open and copy or photograph the error above.
echo For self-test failures, also send validation\offline_tests.log.
popd
if defined ICS_CHECK_ONLY exit /b 1
pause
exit /b 1

:folder_error
echo Could not open the folder containing this setup file.
echo Copy the program into a permanent local folder on this PC and try again.
pause
exit /b 1

:check_success
echo Python detection passed. This check did not install packages or create an environment.
popd
exit /b 0

:probe_python
if defined ICS_BASE_PYTHON exit /b 0
if not exist "%~1" exit /b 1
rem Require a marker from actual Python: an empty Store launcher is not sufficient.
"%~1" -c "import sys,struct; print('ICS_PYTHON_312_X64' if sys.version_info[:2]==(3,12) and struct.calcsize('P')==8 else 'ICS_WRONG_PYTHON')" 2>nul | "%SystemRoot%\System32\findstr.exe" /x /c:"ICS_PYTHON_312_X64" >nul
if errorlevel 1 exit /b 1
set "ICS_BASE_PYTHON=%~1"
exit /b 0
