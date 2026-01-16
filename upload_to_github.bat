@echo off
echo ========================================
echo    Uploading Project to GitHub
echo ========================================
echo.

REM Check if git is installed
git --version >nul 2>&1
if errorlevel 1 (
    echo Error: Git is not installed!
    pause
    exit /b 1
)

REM Initialize git if not already initialized
if not exist ".git" (
    echo Initializing Git repository...
    git init
    echo.
)

REM Add all files
echo Adding all files...
git add .
echo.

REM Get commit message from user
set /p commit_msg="Enter commit message: "
if "%commit_msg%"=="" set commit_msg=Update project

REM Commit changes
echo Committing changes...
git commit -m "%commit_msg%"
echo.

REM Check if remote origin exists
git remote get-url origin >nul 2>&1
if errorlevel 1 (
    echo.
    echo No remote repository found!
    set /p repo_url="Enter your GitHub repository URL: "
    git remote add origin %repo_url%
)

REM Push to GitHub
echo Pushing to GitHub...
git push -u origin main
if errorlevel 1 (
    echo.
    echo Trying with master branch...
    git branch -M main
    git push -u origin main
)

echo.
echo ========================================
echo    Upload Complete!
echo ========================================
pause
