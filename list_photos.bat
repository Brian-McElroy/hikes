@echo off
setlocal enabledelayedexpansion
if exist photos_list.js del photos_list.js

echo const hikes = [>> photos_list.js
for /d %%D in (*) do (
  echo   {>> photos_list.js
  echo     title: "%%D",>> photos_list.js
  echo     photos: [>> photos_list.js
  for %%f in ("%%D\*.jpg") do (
    echo       "%%D/%%~nxf",>> photos_list.js
  )
  echo     ]>> photos_list.js
  echo   },>> photos_list.js
)
echo ];>> photos_list.js

echo Done. photos_list.js updated.
pause
