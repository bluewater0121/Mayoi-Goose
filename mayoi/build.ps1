param([switch]$Run, [switch]$Console)
# Builds MayoiGoose: goose emits C, MSVC (arm64) compiles it with the runtime
# object the compiler cached, and src/plat.c joins it.
$ErrorActionPreference = "Stop"
$env:PATH = "C:\Windows\System32;C:\Windows;C:\Windows\System32\Wbem;" + $env:PATH
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$out = Join-Path $root "build"
New-Item -ItemType Directory -Force -Path $out | Out-Null
$goose = "C:\bin\goose\goose.exe"

# runtime version, for the cached runtime object
$ver = (& $goose --version) -join "`n"
if ($ver -match "runtime ([0-9a-f]+)") { $rtver = $Matches[1] } else { throw "cannot read runtime version" }

$rt = $null
$rtRoot = Join-Path $env:USERPROFILE ".goose\build\runtime\$rtver"
if (Test-Path $rtRoot) {
  $rt = Get-ChildItem -Path $rtRoot -Recurse -Filter "goose_runtime.obj" -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1 -ExpandProperty FullName
}
if (-not $rt) { throw "no goose_runtime.obj for runtime $rtver; run 'goose run' once to build it" }

Push-Location $root
try {
  # icon masks: assets/icons.h + icons_k.goose, from cmd/mayoi/icons.go
  $mk = Join-Path (Split-Path -Parent $root) "tools\mkicons.py"
  if (Test-Path $mk) { python $mk | Out-Null }
  & $goose -o "build\mayoi.c" "main.goose"
  if ($LASTEXITCODE -ne 0) { throw "goose failed ($LASTEXITCODE)" }
} finally { Pop-Location }

$vcvars = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvarsamd64_arm64.bat"
$exename = if ($Console) { "MayoiDbg.exe" } else { "MayoiGoose.exe" }
$subsys = if ($Console) { "/SUBSYSTEM:CONSOLE" } else { "/SUBSYSTEM:WINDOWS" }
$cmd = "call `"$vcvars`" >nul 2>&1 && cd /d `"$root`" && " +
       "cl /nologo /O2 /MT /utf-8 /wd4819 /GS- /I src /I assets `"build\mayoi.c`" `"src\plat.c`" `"$rt`" " +
       "/Fe:`"build\$exename`" /link $subsys /ENTRY:mainCRTStartup " +
       "user32.lib gdi32.lib msimg32.lib shell32.lib ole32.lib comdlg32.lib imm32.lib advapi32.lib"
cmd /c $cmd
if ($LASTEXITCODE -ne 0) { throw "cl failed ($LASTEXITCODE)" }
Write-Output "built: build\$exename"
if ($Run) {
  Get-Process MayoiGoose -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 400
  Start-Process -FilePath (Join-Path $out $exename) -WorkingDirectory $root -ArgumentList $args
}


