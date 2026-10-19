# Build review-only unsigned AOT APKs. Never creates/loads a signing key.
param([string]$ProxyHost='', [int]$ProxyPort=0)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'activate.ps1')
$projectDirectory=Split-Path -Parent $PSScriptRoot
$versionLine=Get-Content "$projectDirectory/pubspec.yaml" | Where-Object {$_ -match '^version:'}
$versionMatch=[regex]::Match($versionLine,'^version:\s*([A-Za-z0-9.-]+)\+([0-9]+)\s*$')
if(-not $versionMatch.Success){throw 'Invalid version'}
$versionName=$versionMatch.Groups[1].Value
$reviewDirectory=Join-Path $projectDirectory "artifacts/unsigned-$versionName"
if(Test-Path -LiteralPath $reviewDirectory){throw 'Unsigned delivery directory exists; refuse overwrite'}
New-Item -ItemType Directory -Path $reviewDirectory | Out-Null
$signingNames=@('OPENTUNER_STORE_FILE','OPENTUNER_STORE_PASSWORD','OPENTUNER_KEY_ALIAS','OPENTUNER_KEY_PASSWORD')
$savedSigning=@{}
foreach($name in $signingNames){$savedSigning[$name]=[Environment]::GetEnvironmentVariable($name,'Process');[Environment]::SetEnvironmentVariable($name,$null,'Process')}
$previousOptions=$env:GRADLE_OPTS
if($ProxyHost){
 if($ProxyHost -notmatch '^[a-zA-Z0-9.:-]+$' -or $ProxyPort -lt 1 -or $ProxyPort -gt 65535){throw 'Invalid proxy'}
 $env:GRADLE_OPTS="$previousOptions -Dhttp.proxyHost=$ProxyHost -Dhttp.proxyPort=$ProxyPort -Dhttps.proxyHost=$ProxyHost -Dhttps.proxyPort=$ProxyPort"
}
Push-Location $projectDirectory
try {
 flutter build apk --release --split-per-abi *> "$reviewDirectory/build.log"
 if($LASTEXITCODE){Get-Content "$reviewDirectory/build.log" -Tail 35;throw 'Unsigned release build failed'}
 $buildTools=Join-Path $env:ANDROID_HOME 'build-tools/36.0.0'
 $checks=@()
 foreach($abi in @('arm64-v8a','armeabi-v7a','x86_64')){
  $sourcePath="build/app/outputs/flutter-apk/app-$abi-release.apk"
  if(-not(Test-Path -LiteralPath $sourcePath)){throw "Missing split $abi"}
  $deliveryPath=Join-Path $reviewDirectory "OpenTuner-$versionName-$abi-UNSIGNED.apk"
  & "$buildTools/apksigner.bat" verify --verbose --print-certs $sourcePath *> "$reviewDirectory/$abi-signature.txt"
  $verifyExit=$LASTEXITCODE
  if($verifyExit -eq 0){throw 'Unexpected signed artifact: this review forbids creating/configuring signing keys'}
  & "$buildTools/aapt.exe" dump badging $sourcePath > "$reviewDirectory/$abi-badging.txt"
  if($LASTEXITCODE){throw 'Badging inspection failed'}
  & "$buildTools/aapt.exe" dump permissions $sourcePath > "$reviewDirectory/$abi-permissions.txt"
  if($LASTEXITCODE){throw 'Permission inspection failed'}
  & "$buildTools/aapt.exe" dump xmltree $sourcePath AndroidManifest.xml > "$reviewDirectory/$abi-manifest.txt"
  if($LASTEXITCODE){throw 'Actual manifest inspection failed'}
  & "$buildTools/zipalign.exe" -c -P 16 -v 4 $sourcePath *> "$reviewDirectory/$abi-zipalign.txt"
  if($LASTEXITCODE){throw 'ZIP alignment failed'}
  [IO.File]::Copy((Join-Path $projectDirectory $sourcePath),$deliveryPath,$false)
  python tools/inspect_apk.py $deliveryPath --abis $abi --output "$reviewDirectory/$abi-native.json"
  if($LASTEXITCODE){throw 'Native split inspection failed'}
  $checks+= [ordered]@{file=[IO.Path]::GetFileName($deliveryPath);abi=$abi;bytes=(Get-Item -LiteralPath $deliveryPath).Length;sha256=(Get-FileHash -LiteralPath $deliveryPath -Algorithm SHA256).Hash.ToLowerInvariant();unsigned=$true;installable=$false;signature_verify_exit=$verifyExit}
 }
 [ordered]@{kind='Unsigned AOT Release review only: NOT INSTALLABLE, NOT PUBLISHED';versionName=$versionName;baseVersionCode=[int]$versionMatch.Groups[2].Value;files=$checks} | ConvertTo-Json -Depth 6 | Set-Content "$reviewDirectory/summary.json" -Encoding utf8
 'UNSIGNED REVIEW ONLY. These APKs cannot be installed as delivered. No key was generated or configured. Do not rename them as signed releases.' | Set-Content "$reviewDirectory/DO-NOT-INSTALL.txt" -Encoding utf8
 Get-Content "$reviewDirectory/build.log" -Tail 8
 Get-Content "$reviewDirectory/summary.json"
} finally {Pop-Location;$env:GRADLE_OPTS=$previousOptions;foreach($name in $signingNames){[Environment]::SetEnvironmentVariable($name,$savedSigning[$name],'Process')}}
