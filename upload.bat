@echo off
echo ==========================================
echo           Git Auto Upload Script
echo ==========================================
echo.

:: Fix dubious ownership issue
git config --global --add safe.directory C:/autoscript >nul 2>&1

:: Check if git user.name is configured
git config user.name >nul 2>&1
if errorlevel 1 (
    echo [INFO] Git user.name belum dikonfigurasi.
    set /p git_name="Masukkan Nama Git Anda (contoh: Nama Anda): "
    if not "%git_name%"=="" (
        git config --global user.name "%git_name%"
    )
    echo.
)

:: Check if git user.email is configured
git config user.email >nul 2>&1
if errorlevel 1 (
    echo [INFO] Git user.email belum dikonfigurasi.
    set /p git_email="Masukkan Email Git Anda (contoh: email@example.com): "
    if not "%git_email%"=="" (
        git config --global user.email "%git_email%"
    )
    echo.
)

:: Prompt for commit message
set /p commit_msg="Enter commit message (Press Enter for default 'update'): "

:: Default message if empty
if "%commit_msg%"=="" (
    set commit_msg=update
)

echo.
echo Running [git add .]...
git add .

echo.
echo Running [git commit -m "%commit_msg%"]...
git commit -m "%commit_msg%"

echo.
echo Running [git push]...
git push

echo.
echo ==========================================
echo        Upload process finished!
echo ==========================================
pause
