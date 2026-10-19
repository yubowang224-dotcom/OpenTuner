# Sign only with an existing external private vault. Never generates a key.
param([string]$SigningConfigPath=(Join-Path $env:LOCALAPPDATA 'OpenTuner/signing/signing.private.json'),[string]$ProxyHost='',[int]$ProxyPort=0,[switch]$SkipUniversal)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'activate.ps1')
$projectDirectory=Split-Path -Parent $PSScriptRoot
$names=@('OPENTUNER_STORE_FILE','OPENTUNER_STORE_PASSWORD','OPENTUNER_KEY_ALIAS','OPENTUNER_KEY_PASSWORD')
$oldEnvironment=@{}
foreach($name in $names){$oldEnvironment[$name]=[Environment]::GetEnvironmentVariable($name,'Process')}
$previousOptions=$env:GRADLE_OPTS
$plainPassword=$null;$securePassword=$null;$pointer=[IntPtr]::Zero
try {
    if(-not(Test-Path -LiteralPath $SigningConfigPath)){throw 'External private signing configuration is missing. No key is generated.'}
    $configFile=(Get-Item -LiteralPath $SigningConfigPath).FullName
    if($configFile.StartsWith($projectDirectory+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Signing configuration must stay outside the project'}
    try {$config=Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json} catch {throw 'External signing configuration cannot be read; private details not echoed'}
    if($config.schema -ne 1 -or $config.certificateSha256 -notmatch '^[a-f0-9]{64}$' -or -not(Test-Path -LiteralPath $config.storeFile)){throw 'Invalid external signing configuration'}
    $storeFile=(Get-Item -LiteralPath $config.storeFile).FullName
    if($storeFile.StartsWith($projectDirectory+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Keystore must remain outside source project'}
    $currentSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
    foreach($privatePath in @($configFile,$storeFile)) {
        $rules=(Get-Acl -LiteralPath $privatePath).GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])
        if(@($rules|Where-Object {$_.AccessControlType -eq 'Allow' -and $_.IdentityReference.Value -notin @($currentSid,'S-1-5-18')}).Count){throw 'Signing file permissions are too broad'}
    }
    try {
        $securePassword=ConvertTo-SecureString -String $config.passwordDpapi
        $pointer=[Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
        $plainPassword=[Runtime.InteropServices.Marshal]::PtrToStringBSTR($pointer)
    } catch {throw 'Private signing configuration cannot be decrypted under this Windows identity; no replacement key generated'}
    finally {if($pointer -ne [IntPtr]::Zero){[Runtime.InteropServices.Marshal]::ZeroFreeBSTR($pointer);$pointer=[IntPtr]::Zero}}
    $env:OPENTUNER_STORE_FILE=$storeFile;$env:OPENTUNER_STORE_PASSWORD=$plainPassword;$env:OPENTUNER_KEY_ALIAS=$config.keyAlias;$env:OPENTUNER_KEY_PASSWORD=$plainPassword
    $versionLine=Get-Content "$projectDirectory/pubspec.yaml" | Where-Object {$_ -match '^version:'}
    $versionMatch=[regex]::Match($versionLine,'^version:\s*([A-Za-z0-9.-]+)\+([0-9]+)\s*$')
    if(-not $versionMatch.Success){throw 'Invalid application version'}
    $versionName=$versionMatch.Groups[1].Value;$versionCode=[int]$versionMatch.Groups[2].Value
    $deliveryDirectory=Join-Path $projectDirectory "artifacts/release-$versionName"
    if(Test-Path -LiteralPath $deliveryDirectory){throw 'Release delivery already exists; refuse overwriting'}
    New-Item -ItemType Directory -Path $deliveryDirectory | Out-Null
    if($ProxyHost){
        if($ProxyHost -notmatch '^[a-zA-Z0-9.:-]+$' -or $ProxyPort -lt 1 -or $ProxyPort -gt 65535){throw 'Invalid proxy'}
        $env:GRADLE_OPTS="$previousOptions -Dorg.gradle.daemon=false -Dorg.gradle.configuration-cache=false -Dhttp.proxyHost=$ProxyHost -Dhttp.proxyPort=$ProxyPort -Dhttps.proxyHost=$ProxyHost -Dhttps.proxyPort=$ProxyPort"
    } else {$env:GRADLE_OPTS="$previousOptions -Dorg.gradle.daemon=false -Dorg.gradle.configuration-cache=false"}
    $buildTools=Join-Path $env:ANDROID_HOME 'build-tools/36.0.0'
    function Save-SanitizedBuildLine($line) {
        $text=[string]$line
        foreach($privateValue in @($plainPassword,$configFile,$storeFile,$config.passwordDpapi)){
            if(-not[string]::IsNullOrEmpty($privateValue)){$text=$text.Replace($privateValue,'[PRIVATE SIGNING VALUE REDACTED]')}
        }
        $text
    }
    $packages=@()
    function Inspect-SignedPackage([string]$sourcePath,[string]$abi) {
        $name="OpenTuner-$versionName-$abi.apk";$destination=Join-Path $deliveryDirectory $name
        & "$buildTools/apksigner.bat" verify --verbose --print-certs $sourcePath *> "$deliveryDirectory/$abi-signature.txt"
        if($LASTEXITCODE){throw 'Release APK signature verification failed'}
        $signature=Get-Content "$deliveryDirectory/$abi-signature.txt" -Raw
        $found=[regex]::Match($signature,'Signer #1 certificate SHA-256 digest: ([a-fA-F0-9]{64})')
        if(-not $found.Success -or $found.Groups[1].Value.ToLowerInvariant() -ne $config.certificateSha256 -or $found.Groups[1].Value.ToLowerInvariant() -eq 'a112fb5cd80d09a36b44cc7923fc8ce37884945fdcf05a7a5a53c6443add6064'){throw 'Unexpected signing certificate; refusing delivery'}
        & "$buildTools/aapt.exe" dump badging $sourcePath > "$deliveryDirectory/$abi-badging.txt"
        if($LASTEXITCODE){throw 'APK badging inspection failed'}
        $badging=Get-Content "$deliveryDirectory/$abi-badging.txt" -Raw
        if($badging -notmatch "name='org.opentune.tuner'" -or $badging -notmatch "versionCode='$versionCode'" -or $badging -notmatch "versionName='$([regex]::Escape($versionName))'" -or $badging -notmatch "sdkVersion:'24'"){throw 'Unexpected package/version/minimum SDK'}
        & "$buildTools/aapt.exe" dump permissions $sourcePath > "$deliveryDirectory/$abi-permissions.txt"
        if($LASTEXITCODE){throw 'APK permissions inspection failed'}
        & "$buildTools/aapt.exe" dump xmltree $sourcePath AndroidManifest.xml > "$deliveryDirectory/$abi-manifest.txt"
        if($LASTEXITCODE){throw 'Actual manifest inspection failed'}
        & "$buildTools/zipalign.exe" -c -P 16 -v 4 $sourcePath *> "$deliveryDirectory/$abi-zipalign.txt"
        if($LASTEXITCODE){throw 'APK alignment failed'}
        [IO.File]::Copy((Join-Path $projectDirectory $sourcePath),$destination,$false)
        $abis=if($abi -eq 'universal'){@('arm64-v8a','armeabi-v7a','x86_64')}else{@($abi)}
        python tools/inspect_apk.py $destination --abis $abis --output "$deliveryDirectory/$abi-native.json" > "$deliveryDirectory/$abi-native-console.txt"
        if($LASTEXITCODE){throw 'APK native inventory/alignment failed'}
        [ordered]@{file=$name;abi=$abi;versionCode=$versionCode;bytes=(Get-Item -LiteralPath $destination).Length;sha256=(Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash.ToLowerInvariant();certificateSha256=$config.certificateSha256;signed=$true;installableSignature=$true;deviceInstalled=$false}
    }
    Push-Location $projectDirectory
    try {
        flutter build apk --release --split-per-abi 2>&1 | ForEach-Object {Save-SanitizedBuildLine $_} | Set-Content "$deliveryDirectory/split-build.log" -Encoding utf8
        if($LASTEXITCODE){Get-Content "$deliveryDirectory/split-build.log" -Tail 25;throw 'Signed split Release build failed'}
        foreach($abi in @('arm64-v8a','armeabi-v7a','x86_64')){$packages+=Inspect-SignedPackage "build/app/outputs/flutter-apk/app-$abi-release.apk" $abi}
        if(-not $SkipUniversal){
            flutter build apk --release 2>&1 | ForEach-Object {Save-SanitizedBuildLine $_} | Set-Content "$deliveryDirectory/universal-build.log" -Encoding utf8
            if($LASTEXITCODE){Get-Content "$deliveryDirectory/universal-build.log" -Tail 25;throw 'Signed universal Release build failed'}
            $packages+=Inspect-SignedPackage 'build/app/outputs/flutter-apk/app-release.apk' 'universal'
        }
        $publicCertificate=Join-Path (Split-Path $configFile) 'release-public.cer'
        if(Test-Path -LiteralPath $publicCertificate){[IO.File]::Copy($publicCertificate,(Join-Path $deliveryDirectory 'OpenTuner-release-public.cer'),$false)}
        [ordered]@{kind='Signed AOT Android Release, local delivery; not uploaded or device-tested';versionName=$versionName;versionCodePolicy='Unified base code for all ABI/universal APKs, no ABI offset';recommended='arm64-v8a';certificateSha256=$config.certificateSha256;packages=$packages} | ConvertTo-Json -Depth 7 | Set-Content "$deliveryDirectory/summary.json" -Encoding utf8
        $packages | ForEach-Object {$_.sha256+'  '+$_.file} | Set-Content "$deliveryDirectory/SHA256SUMS.txt" -Encoding ascii
        Get-Content "$deliveryDirectory/summary.json"
    } finally {Pop-Location}
} finally {
    foreach($name in $names){[Environment]::SetEnvironmentVariable($name,$oldEnvironment[$name],'Process')}
    $env:GRADLE_OPTS=$previousOptions
    if($securePassword){$securePassword.Dispose()};$plainPassword=$null;$config=$null
}
