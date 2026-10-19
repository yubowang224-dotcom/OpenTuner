# Host process measurement only; never an Android CPU/RSS claim.
param([string]$BuildDirectory='build/m3-dsp')
$ErrorActionPreference='Stop'
$evidenceDirectory=(New-Item -ItemType Directory -Path artifacts/m3/resource-probe -Force).FullName
$binaryPath=(Resolve-Path "$BuildDirectory/Release/partial_tests.exe").Path
$timer=[Diagnostics.Stopwatch]::StartNew()
$process=Start-Process -FilePath $binaryPath -ArgumentList ('"'+$evidenceDirectory+'"') -WindowStyle Hidden -PassThru -RedirectStandardOutput "$evidenceDirectory/stdout.log" -RedirectStandardError "$evidenceDirectory/stderr.log"
$observedPeak=0L
while(-not $process.WaitForExit(50)) {
    $process.Refresh()
    $observedPeak=[Math]::Max($observedPeak,$process.PeakWorkingSet64)
}
$timer.Stop()
if($process.ExitCode -ne 0){throw 'Host partial resource probe failed'}
$native=Get-Content "$evidenceDirectory/summary.json" -Raw | ConvertFrom-Json
[ordered]@{evidence='Separate Windows host process; OS peak working set sampled every 50 ms; not Android RSS/CPU';peak_working_set_bytes=$observedPeak;wall_seconds=$timer.Elapsed.TotalSeconds;process_cpu_seconds=$native.cpu_seconds;cpu_percent_one_core_equivalent=100*$native.cpu_seconds/$timer.Elapsed.TotalSeconds;logical_processors=[Environment]::ProcessorCount;cpu=(Get-CimInstance Win32_Processor).Name;os=[Environment]::OSVersion.VersionString} | ConvertTo-Json | Set-Content artifacts/m3/host-resource.json -Encoding utf8
Get-Content artifacts/m3/host-resource.json
