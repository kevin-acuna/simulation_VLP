@echo off
setlocal
set "ICS_SETUP_STAGE=Opening the program folder"
pushd "%~dp0"
if errorlevel 1 goto folder_error

echo ICS Python dependency setup
echo Internet access is required. No instruments will be connected.
echo.
if not exist "requirements.txt" goto missing_files
if not exist "selftest.py" goto missing_files
if exist ".venv\Scripts\python.exe" goto environment_ready

set "ICS_SETUP_STAGE=Finding Python 3.12"
set "ICS_BASE_PYTHON=%LOCALAPPDATA%\Programs\Python\Python312\python.exe"
if not exist "%ICS_BASE_PYTHON%" set "ICS_BASE_PYTHON=%ProgramFiles%\Python312\python.exe"
if not exist "%ICS_BASE_PYTHON%" goto try_launcher
"%ICS_BASE_PYTHON%" -c "import sys,struct; assert sys.version_info[:2]==(3,12) and struct.calcsize('P')==8, 'Python 3.12 64-bit is required'"
if errorlevel 1 goto failed
set "ICS_SETUP_STAGE=Creating the project Python environment"
"%ICS_BASE_PYTHON%" -m venv ".venv"
if errorlevel 1 goto failed
goto environment_ready

:try_launcher
py -3.12 -c "import sys,struct; assert sys.version_info[:2]==(3,12) and struct.calcsize('P')==8, 'Python 3.12 64-bit is required'"
if errorlevel 1 goto missing_python
set "ICS_SETUP_STAGE=Creating the project Python environment"
py -3.12 -m venv ".venv"
if errorlevel 1 goto failed

:environment_ready
set "ICS_ENV_PYTHON=%CD%\.venv\Scripts\python.exe"
set "ICS_SETUP_STAGE=Checking the project Python environment"
"%ICS_ENV_PYTHON%" -c "import sys,struct; print('Using:',sys.executable); print('Python:',sys.version); assert sys.version_info[:2]==(3,12) and struct.calcsize('P')==8, 'This project environment must use Python 3.12 64-bit'"
if errorlevel 1 goto failed

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
echo Install Python 3.12 64-bit first, using Install Now and its default location.
echo If Python is installed elsewhere, send its exact location with this error.
goto failed

:failed
echo.
echo SETUP STOPPED during: %ICS_SETUP_STAGE%
echo Keep this window open and copy or photograph the error above.
echo For self-test failures, also send validation\offline_tests.log.
popd
pause
exit /b 1

:folder_error
echo Could not open the folder containing this setup file.
echo Copy the program into a permanent local folder on this PC and try again.
pause
exit /b 1
