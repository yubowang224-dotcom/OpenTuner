param(
    [switch]$BuildApk,
    [string]$ProxyHost = '',
    [int]$ProxyPort = 0
)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$probeDirectory = Join-Path $projectRoot '.local/flutter_probe'
$artifacts = Join-Path $projectRoot 'artifacts'
. (Join-Path $PSScriptRoot 'activate.ps1')
New-Item -ItemType Directory -Path $artifacts -Force | Out-Null
function Invoke-Check([string]$Label, [scriptblock]$Action) {
    $log = Join-Path $artifacts "flutter-probe-$Label.log"
    & $Action *> $log
    $exitCode = $LASTEXITCODE
    Get-Content -LiteralPath $log -Tail 15 | Write-Output
    if ($exitCode -ne 0) { throw "$Label failed with exit $exitCode. See $log" }
}
if (-not (Test-Path -LiteralPath $probeDirectory)) {
    Invoke-Check 'create' { flutter create --platforms=android --project-name toolchain_probe --org dev.opentune.probe $probeDirectory }
}
if (-not (Test-Path -LiteralPath (Join-Path $probeDirectory 'pubspec.yaml'))) {
    throw 'Probe directory exists but is not a Flutter project. Inspect it; no files were overwritten.'
}
if ($ProxyHost) {
    if ($ProxyHost -notmatch '^[a-zA-Z0-9.:-]+$' -or $ProxyPort -lt 1 -or $ProxyPort -gt 65535) {
        throw 'Supply a plain proxy host and a valid port, with no credentials.'
    }
    $properties = Join-Path $probeDirectory 'android/gradle.properties'
    $content = Get-Content -LiteralPath $properties
    $content = $content | Where-Object { $_ -notmatch '^systemProp\.(http|https)\.(proxyHost|proxyPort|nonProxyHosts)=' }
    $content += @("systemProp.http.proxyHost=$ProxyHost", "systemProp.http.proxyPort=$ProxyPort",
        "systemProp.https.proxyHost=$ProxyHost", "systemProp.https.proxyPort=$ProxyPort",
        'systemProp.http.nonProxyHosts=localhost|127.*')
    $content | Set-Content -LiteralPath $properties -Encoding UTF8
}
Push-Location $probeDirectory
try {
    Invoke-Check 'analyze' { flutter analyze }
    Invoke-Check 'test' { flutter test }
    if ($BuildApk) { Invoke-Check 'build' { flutter build apk --debug } }
} finally { Pop-Location }
Write-Output 'Template toolchain checks completed. These are NOT OpenTune product tests.'
