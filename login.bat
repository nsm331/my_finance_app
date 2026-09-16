@echo off
set "PATH=C:\Program Files\nodejs;%PATH%"
echo ====================================================
echo  Firebase CLI Login
echo ====================================================
call "C:\Program Files\nodejs\npx.cmd" -y firebase-tools login
pause
