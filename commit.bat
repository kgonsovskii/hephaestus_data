@echo off
setlocal EnableExtensions

rem === Paths relative to this .bat ===
set "REPO1=%~dp0..\hephaestus"
set "REPO2=%~dp0..\hephaestus_data"
set "REPO3=%~dp0..\hephaestus_distrib"

rem Message: commit.bat "fix dns sync"
if not "%~1"=="" (
  set "COMMIT_MSG=%*"
) else (
  set "COMMIT_MSG=chore: sync"
)

call :DoRepo "%REPO1%" || exit /b 1
call :DoRepo "%REPO2%" || exit /b 1
call :DoRepo "%REPO3%" || exit /b 1
echo Done.
exit /b 0

:DoRepo
set "ROOT=%~1"
if not exist "%ROOT%\.git" (
  echo [skip] Not a git repo: %ROOT%
  exit /b 0
)
echo.
echo === %ROOT% ===
pushd "%ROOT%" || exit /b 1
git add -A
git diff --cached --quiet
if errorlevel 1 (
  git commit -m "%COMMIT_MSG%"
  if errorlevel 1 (
    echo [error] commit failed in %ROOT%
    popd
    exit /b 1
  )
) else (
  echo Nothing to commit ^(working tree clean after add^).
)
git push
if errorlevel 1 (
  echo [error] push failed in %ROOT%
  popd
  exit /b 1
)
popd
exit /b 0
