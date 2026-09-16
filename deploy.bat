@echo off
set "PATH=C:\Program Files\nodejs;%PATH%"
echo ====================================================
echo  Deploying to Firebase Hosting...
echo ====================================================
call "C:\Program Files\nodejs\npx.cmd" -y firebase-tools deploy --only hosting
echo ====================================================
echo  Deployment complete!
echo ====================================================
pause
