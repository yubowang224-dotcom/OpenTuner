# Dot-source this script: . .\tools\activate.ps1
# Only changes the current PowerShell process; never writes the user/system PATH.
param([string]$ConfigPath = (Join-Path $PSScriptRoot '../.local/toolchain.json'))
$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw 'Missing local toolchain config. See docs/windows-setup.zh-CN.md.'
}
$toolchain = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
foreach ($required in @('flutter', 'androidSdk', 'jdk', 'cmakeBin')) {
    if (-not (Test-Path -LiteralPath $toolchain.$required)) {
        throw "Configured path for $required does not exist."
    }
}
$env:JAVA_HOME = $toolchain.jdk
$env:ANDROID_HOME = $toolchain.androidSdk
$env:ANDROID_SDK_ROOT = $toolchain.androidSdk
$env:FLUTTER_SUPPRESS_ANALYTICS = 'true'
$env:CI = 'true'
$sdkManagerBin = Join-Path $toolchain.androidSdk 'cmdline-tools/latest/bin'
if (-not (Test-Path -LiteralPath $sdkManagerBin)) {
    $sdkManagerBin = Join-Path $toolchain.androidSdk 'cmdline-tools/7.0/bin'
}
$env:PATH = (@((Join-Path $toolchain.flutter 'bin'), (Join-Path $toolchain.jdk 'bin'),
    (Join-Path $toolchain.androidSdk 'platform-tools'), $sdkManagerBin, $toolchain.cmakeBin) -join ';') + ';' + $env:PATH
Write-Output 'OpenTune toolchain activated in this terminal only.'
