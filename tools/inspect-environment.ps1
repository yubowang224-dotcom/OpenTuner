param([string]$OutputPath = (Join-Path $PSScriptRoot '../artifacts/environment.json'))
$ErrorActionPreference = 'Stop'
$checks = [ordered]@{}
foreach ($name in @('git','flutter','dart','java','javac','adb','sdkmanager','cmake','ninja','cl','gh','code','python','node')) {
    $found = Get-Command $name -ErrorAction SilentlyContinue | Select-Object -First 1
    $checks[$name] = if ($found) { $found.Source } else { $null }
}
$variables = [ordered]@{}
foreach ($name in @('JAVA_HOME','ANDROID_HOME','ANDROID_SDK_ROOT','FLUTTER_ROOT')) {
    $variables[$name] = [Environment]::GetEnvironmentVariable($name)
}
$report = [ordered]@{
    timestamp = [DateTimeOffset]::UtcNow.ToString('o')
    os = (Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,OSArchitecture)
    commands = $checks
    environment = $variables
    note = 'Command discovery only. Null means absent from current PATH, not proof of no installation. Run version/build probes separately. No credentials are collected.'
}
$parent = Split-Path -Parent $OutputPath
New-Item -ItemType Directory -Path $parent -Force | Out-Null
$report | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $OutputPath -Encoding UTF8
Write-Output "Environment discovery saved: $OutputPath"
