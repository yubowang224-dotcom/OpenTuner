param()
$ErrorActionPreference = 'Stop'
python (Join-Path $PSScriptRoot 'verify_baseline.py')
if ($LASTEXITCODE) { throw 'Frozen baseline provenance failed' }
& (Join-Path $PSScriptRoot 'test-dsp.ps1')
if ($LASTEXITCODE) { throw 'DSP tests failed' }
$rootDirectory = Split-Path -Parent $PSScriptRoot
Push-Location $rootDirectory
try {
    $env:PYTHONUTF8='1'
    python tools/evaluate_tracking.py *> artifacts/stage25-evaluation-run.log
    $evaluationExit=$LASTEXITCODE
    Get-Content artifacts/stage25-evaluation-run.log
    if ($evaluationExit) { throw 'Stage25 evaluation failed; inspect complete data' }
} finally { Pop-Location }
