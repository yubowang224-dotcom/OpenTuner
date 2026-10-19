param([string]$CMake = '', [string]$BuildDirectory = (Join-Path $PSScriptRoot '../build/native-probe'))
$ErrorActionPreference = 'Stop'
if (-not $CMake) {
    $candidate = Get-Command cmake -ErrorAction SilentlyContinue
    if ($candidate) { $CMake = $candidate.Source }
}
if (-not $CMake) {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio/Installer/vswhere.exe'
    if (Test-Path -LiteralPath $vswhere) {
        $vsPath = & $vswhere -latest -products '*' -property installationPath
        $CMake = Join-Path $vsPath 'Common7/IDE/CommonExtensions/Microsoft/CMake/CMake/bin/cmake.exe'
    }
}
if (-not $CMake -or -not (Test-Path -LiteralPath $CMake)) { throw 'CMake not found. Install CMake/C++ tools or pass -CMake.' }
$artifactDirectory = Join-Path $PSScriptRoot '../artifacts'
New-Item -ItemType Directory -Path $artifactDirectory -Force | Out-Null
$log = Join-Path $artifactDirectory 'native-probe.log'
Start-Transcript -Path $log -Force | Out-Null
try {
    & $CMake --version
    if ($LASTEXITCODE -ne 0) { throw 'CMake version probe failed.' }
    & $CMake -S (Join-Path $PSScriptRoot 'probes') -B $BuildDirectory
    if ($LASTEXITCODE -ne 0) { throw 'Native configure failed.' }
    & $CMake --build $BuildDirectory --config Release
    if ($LASTEXITCODE -ne 0) { throw 'Native build failed.' }
    $ctest = Join-Path (Split-Path -Parent $CMake) 'ctest.exe'
    & $ctest --test-dir $BuildDirectory -C Release --output-on-failure --verbose
    if ($LASTEXITCODE -ne 0) { throw 'Native smoke probe failed.' }
} finally {
    Stop-Transcript | Out-Null
}
