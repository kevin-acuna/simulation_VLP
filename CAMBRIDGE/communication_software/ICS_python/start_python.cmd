@echo off
pushd "%~dp0"
if errorlevel 1 exit /b 1
if not exist ".venv\Scripts\python.exe" (
  echo Please follow START_HERE.txt to create the Python environment first.
  pause
  popd
  exit /b 1
)
".venv\Scripts\python.exe" -i run_ics.py
popd
