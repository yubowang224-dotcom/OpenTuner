param()
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'activate.ps1')
$rootDirectory = Split-Path -Parent $PSScriptRoot
$outputDirectory = Join-Path $rootDirectory 'artifacts/dsp'
New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
if (Test-Path -LiteralPath "$outputDirectory/test.log") {
    $historyDirectory = Join-Path $outputDirectory ('history/' + (Get-Date -Format 'yyyyMMddTHHmmssfff'))
    New-Item -ItemType Directory -Path $historyDirectory -Force | Out-Null
    Get-ChildItem -LiteralPath $outputDirectory -File | Copy-Item -Destination $historyDirectory
}
Push-Location $rootDirectory
try {
    cmake -S native -B build/dsp *> "$outputDirectory/configure.log"
    if ($LASTEXITCODE) { Get-Content "$outputDirectory/configure.log"; throw 'DSP configure failed' }
    cmake --build build/dsp --config Release *> "$outputDirectory/build.log"
    if ($LASTEXITCODE) { Get-Content "$outputDirectory/build.log"; throw 'DSP build failed' }
    ctest --test-dir build/dsp -C Release --output-on-failure --verbose *> "$outputDirectory/test.log"
    Get-Content "$outputDirectory/test.log" -Tail 30
    Copy-Item -Path build/dsp/results/*.csv,build/dsp/results/host_process.json -Destination $outputDirectory -Force
    Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors | ConvertTo-Json | Set-Content "$outputDirectory/cpu.json"
    if ($LASTEXITCODE) { throw 'Production DSP tests failed; inspect full CSV results' }
} finally { Pop-Location }
