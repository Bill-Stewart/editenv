@echo off
setlocal enableextensions

set DEBUGARG=
:: set DEBUGARG=-dDEBUG
:: set DEBUGARG=-gh -gl

fpc editenv.pp %DEBUGARG% -dx86 -FEx86 -Xs -XX -oeditenv.exe
if errorlevel 1 goto :END

ppcrossx64 editenv.pp %DEBUGARG% -dx64 -FEx64 -Xs -XX -oeditenv.exe

:END
endlocal
