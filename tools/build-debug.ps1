param([string]$ProxyHost = '', [int]$ProxyPort = 0)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'activate.ps1')
$rootDirectory = Split-Path -Parent $PSScriptRoot
$versionText = Get-Content (Join-Path $rootDirectory 'pubspec.yaml') | Where-Object { $_ -match '^version:' }
$version = [regex]::Match($versionText, '^version:\s*([A-Za-z0-9.-]+)\+([0-9]+)\s*$')
if (-not $version.Success) { throw 'Expected a safe versionName+versionCode in pubspec.yaml.' }
$apkName = 'OpenTuner-' + $version.Groups[1].Value + '-debug.apk'
$delivery = Join-Path $rootDirectory ('artifacts/' + $apkName)
if (Test-Path -LiteralPath $delivery) { throw "Refusing to overwrite $delivery. Increment versionCode and choose a distinct versionName." }
$evidenceDirectory = Join-Path $rootDirectory ('artifacts/build-' + $version.Groups[1].Value)
New-Item -ItemType Directory -Path $evidenceDirectory -Force | Out-Null
$previousGradleOptions = $env:GRADLE_OPTS
if ($ProxyHost) {
    if ($ProxyHost -notmatch '^[a-zA-Z0-9.:-]+$' -or $ProxyPort -lt 1 -or $ProxyPort -gt 65535) {
        throw 'Use a plain proxy host and valid port, without credentials.'
    }
    $env:GRADLE_OPTS = "$previousGradleOptions -Dhttp.proxyHost=$ProxyHost -Dhttp.proxyPort=$ProxyPort -Dhttps.proxyHost=$ProxyHost -Dhttps.proxyPort=$ProxyPort"
}
Push-Location $rootDirectory
try {
    flutter build apk --debug *> (Join-Path $evidenceDirectory 'android-build.log')
    $buildExit = $LASTEXITCODE
    Get-Content -LiteralPath (Join-Path $evidenceDirectory 'android-build.log') -Tail 25
    if ($buildExit -ne 0) { throw "Android build failed: $buildExit" }
    $apkPath = Join-Path $rootDirectory 'build/app/outputs/flutter-apk/app-debug.apk'
    if (-not (Test-Path -LiteralPath $apkPath)) { throw 'Build returned success but no APK exists.' }
    $buildTools = Join-Path $env:ANDROID_HOME 'build-tools/36.0.0'
    & (Join-Path $buildTools 'apksigner.bat') verify --verbose --print-certs $apkPath *> (Join-Path $evidenceDirectory 'apk-signature.txt')
    if ($LASTEXITCODE -ne 0) { throw 'APK signature verification failed.' }
    & (Join-Path $buildTools 'aapt.exe') dump badging $apkPath > (Join-Path $evidenceDirectory 'apk-badging.txt')
    if ($LASTEXITCODE -ne 0) { throw 'APK package inspection failed.' }
    & (Join-Path $buildTools 'aapt.exe') dump permissions $apkPath > (Join-Path $evidenceDirectory 'apk-permissions.txt')
    if ($LASTEXITCODE -ne 0) { throw 'APK permission inspection failed.' }
    & (Join-Path $buildTools 'zipalign.exe') -c -P 16 -v 4 $apkPath *> (Join-Path $evidenceDirectory 'apk-zipalign.txt')
    if ($LASTEXITCODE -ne 0) { throw 'APK ZIP alignment failed.' }
    # CreateNew semantics protect against a second writer after the precheck.
    [System.IO.File]::Copy($apkPath, $delivery, $false)
    $hash = (Get-FileHash -LiteralPath $delivery -Algorithm SHA256).Hash.ToLowerInvariant()
    "$hash  $apkName" | Set-Content -LiteralPath (Join-Path $evidenceDirectory 'apk.sha256.txt') -Encoding ASCII
    python tools/inspect_apk.py $delivery --output (Join-Path $evidenceDirectory 'apk-native.json')
    if ($LASTEXITCODE -ne 0) { throw 'Native ABI/ELF inspection failed.' }
    Write-Output "APK: $delivery"
    Write-Output "SHA-256: $hash"
} finally {
    Pop-Location
    $env:GRADLE_OPTS = $previousGradleOptions
}
