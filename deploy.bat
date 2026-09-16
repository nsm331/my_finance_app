@echo off
set "PATH=C:\Program Files\nodejs;%PATH%"
echo ====================================================
echo  Preparing Web Assets...
echo ====================================================
if exist "web\sqflite_sw.js" copy /y "web\sqflite_sw.js" "build\web\sqflite_sw.js" >nul
if exist "web\sqlite3.wasm" copy /y "web\sqlite3.wasm" "build\web\sqlite3.wasm" >nul

echo ====================================================
echo  Deploying to Firebase Hosting...
echo ====================================================
call "C:\Program Files\nodejs\npx.cmd" -y firebase-tools deploy --only hosting
echo ====================================================
echo  Deployment complete!
echo ====================================================
pause
