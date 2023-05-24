::===============================================================
:: INSTALL HMS 
::===============================================================
@echo off
setlocal ENABLEDELAYEDEXPANSION
REM This batch command can be used to change or reset the cmd.exe prompt.
prompt
Echo Local Time: %Time%

REM Exception Constans //////////////////////////////////////////////////////////////////////////////////
set INTERNETCONNECTIONERR=No internet connection, please connect internet and try again...
set ADBDEFAULTDEVICEERR=Unable to connect to device, check your device connection and port try again...
REM ///////////////////////////////////////////////////////////////////////////////////////////////////////

REM Port Constans ///////////////////////////
set MEMUPLAYERDEFAULTPORT=21503
set BLUESTACKDEFAULTPORT=5555
set NOXPLAYERDEFAULTPORT=62001
set MUMUPLAYERDEFAULTPORT=7555
REM /////////////////////////////////////////

REM APK Constans //////////////////////////////////////////////////////////////////
set AppGalleryApkURL=https://appgallery.cloud.huawei.com/appdl/C27162?
set HmsCoreApkURL=https://appgallery.cloud.huawei.com/appdl/C10132067?
set InstallAppApkURL=https://appgallery.cloud.huawei.com/appdl/C107971673?

set GameName=SummonersWarChronicles
set AppGalleryOUTPUT=AppGallery.apk
set HmsCoreOUTPUT=HMSCore.apk
set InstallAppOUTPUT=%GameName%.apk
REM /////////////////////////////////////////////////////////////////////////////

REM ADB Constans //////////////////////////////////////////////////////////////////
set ADB_PATH=adb\platform-tools\adb.exe
set FILE_NAME=devices.txt
REM /////////////////////////////////////////////////////////////////////////////

REM Check Internet Connection part
CALL :CHECKINTERNETCONNFUNC

timeout /t 1 /nobreak > NUL

REM Create a folder for ADB and download
if not exist "adb" (
	CALL :ADBINSTALLERFUNC
)

REM Apk download and setup by adb part
echo Download AppGallery, HMS Core and Game

if not exist "%AppGalleryOUTPUT%" (
	CALL :APKDOWLOADFUNC %AppGalleryOUTPUT%, %AppGalleryApkURL%, AppGallery
)
if not exist "%HmsCoreOUTPUT%" (
	CALL :APKDOWLOADFUNC %HmsCoreOUTPUT%, %HmsCoreApkURL%, HmsCore
)
if not exist "%InstallAppOUTPUT%" (
	CALL :APKDOWLOADFUNC %InstallAppOUTPUT%, %InstallAppApkURL%, %GameName%
)

REM Adb operation

echo Adb Operations...
%ADB_PATH% start-server 
timeout /t 1 /nobreak > NUL
for /f %%i in ('%ADB_PATH% devices ^| findstr "device$"') do (
  echo %%i >> %FILE_NAME%
)

if not exist "%FILE_NAME%" (
	echo File not found: %FILE_NAME%
	for /f "usebackq tokens=*" %%A IN (`%ADB_PATH% connect 127.0.0.1:%BLUESTACKDEFAULTPORT%`) DO (
		timeout /t 1 /nobreak > NUL
		call :ADBCONNECTFUNC "%%A", "%BLUESTACKDEFAULTPORT%"
	)
	for /f "usebackq tokens=*" %%A IN (`%ADB_PATH% connect 127.0.0.1:%MEMUPLAYERDEFAULTPORT%`) DO (
		timeout /t 1 /nobreak > NUL
		call :ADBCONNECTFUNC "%%A", "%MEMUPLAYERDEFAULTPORT%"
	)
	for /f "usebackq tokens=*" %%A IN (`%ADB_PATH% connect 127.0.0.1:%NOXPLAYERDEFAULTPORT%`) DO (
		timeout /t 1 /nobreak > NUL
		call :ADBCONNECTFUNC "%%A", "%NOXPLAYERDEFAULTPORT%"
	)
	for /f "usebackq tokens=*" %%A IN (`%ADB_PATH% connect 127.0.0.1:%MUMUPLAYERDEFAULTPORT%`) DO (
		timeout /t 1 /nobreak > NUL
		call :ADBCONNECTFUNC "%%A", "%MUMUPLAYERDEFAULTPORT%"
	)
)

if not exist "%FILE_NAME%" (
	echo %ADBDEFAULTDEVICEERR%
	timeout /t 10 /nobreak > NUL
	exit /B 1
)

REM Install the APKs onto all connected devices

for /f "tokens=1" %%i in (devices.txt) do (
	echo %%i
	CALL :CHECKIPFUNC %%i, RETURNIPCHECK
	IF RETURNIPCHECK==1 (
		%ADB_PATH% connect %%i
	)
	echo uninstall hwid
	CALL :CHECKAPPUNINSTALLFUNC com.huawei.hwid, %%i
	echo Installing %GameName% !device!...
	CALL :APKINSTALLFUNC %InstallAppOUTPUT%, %%i
	echo Installing AppGallery on !device!...
	CALL :APKINSTALLFUNC %AppGalleryOUTPUT%, %%i
	echo Installing HMSCore on !device!...
	CALL :APKINSTALLFUNC %HmsCoreOUTPUT%, %%i

	REM ECHO Open Dragon Trail on !device!...
	REM CALL :RUNAPKFUNC "com.slsmus.huawei", "com.sy4399.yf5lib.MainActivity", %%i
)

del devices.txt

%ADB_PATH% kill-server

echo Done!

timeout /t 10 /nobreak > NUL

exit

REM FUNCTIONS PART

:CHECKINTERNETCONNFUNC
	ping google.com -n 1 >NUL
	if errorlevel 1 (
		echo %INTERNETCONNECTIONERR%
		timeout /t 10 /nobreak > NUL
		exit
	) else (
		echo Internet connection is active
	)
EXIT /B 0
:ADBCONNECTFUNC <ADBOUTPUT>, <PORT>
	ECHO.%~1 | findstr /v /c:"adb server is out of date" >nul && (
		ECHO.%~1 | findstr /C:"cannot" /C:"unable" /C:"killing" >nul && (
			echo %ADBDEFAULTDEVICEERR% - Port Number: %~2 	
		) || (
			echo "ADB connection successfully."
			echo Connected to device 127.0.0.1:%~2
			echo 127.0.0.1:%~2 >> devices.txt
		)
	)
EXIT /B 0
:ADBINSTALLERFUNC
	echo ADB not found, local downloading...
	mkdir "adb"
	
	REM Download ADB
	echo Downloading ADB... 
	
	REM Download the ADB package using cURL
	curl -L -o adb.zip "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"

	REM Extract ADB
	echo Extracting ADB...
	CALL :UNZIPFUNC "adb.zip" "adb"
	timeout /t 1 /nobreak > NUL

	echo Cleaning adb zip file
	del adb.zip
EXIT /B 0
:APKDOWLOADFUNC <OUTPUT>, <URL>, <APKNAME>
	setlocal
	echo Downloading %~3 APK...
	set FILE_NAME=%~1
	set URL=%~2
	:retry
	curl -L -o %FILE_NAME% %URL%
	CALL :GETFILESIZEFUNC %FILE_NAME%, RETURNFILESIZE
	set maxbytesize=4096
	IF %RETURNFILESIZE% LSS %maxbytesize% (
		echo %~3 APK download failed, retrying...
		del %FILE_NAME%
		timeout /t 1 /nobreak > NUL
		goto retry
	)
EXIT /B 0
:RUNAPKFUNC <package name>, <activity name>, <device>
	%ADB_PATH% -s %~3 shell am start -n %~1/%~2
EXIT /B 0
:UNZIPFUNC <zipfile> <outputdir>
	powershell -Command "Expand-Archive %~1 -DestinationPath %~2"
EXIT /B 0
:CHECKAPPUNINSTALLFUNC <package name>, <device>
	%ADB_PATH% -s %~2 shell pm list packages | findstr "%~1" >nul && (
		%ADB_PATH% -s %~2 uninstall %~1
	) || (
		echo %~1 is not installed
	)
EXIT /B 0
:APKINSTALLFUNC <apkfile> <device>
	%ADB_PATH% -s %~2 install %~1
EXIT /B 0
:GETFILESIZEFUNC <FILENAME>
	set file="%~1%" 
	FOR /F "usebackq" %%A IN ('%file%') DO set %~2=%%~zA 
EXIT /B 0
:CHECKIPFUNC <IP>
	ECHO.%~1 | findstr /c:"127.0.0.1" >nul && (
		set %~2=1
	) || (
		set %~2=0
	)
EXIT /B 0