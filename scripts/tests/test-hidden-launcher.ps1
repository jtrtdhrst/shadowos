$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$launcherPath = Join-Path $repositoryRoot "scripts\run-sync-hidden.vbs"
$probeScriptPath = Join-Path $PSScriptRoot ".hidden-launcher-probe.ps1"
$markerPath = Join-Path $PSScriptRoot ".hidden-launcher-probe.txt"
$wscriptPath = Join-Path $env:WINDIR "System32\wscript.exe"

if (-not (Test-Path -LiteralPath $wscriptPath)) {
    throw "Windows Script Host was not found at $wscriptPath."
}

if ((Test-Path -LiteralPath $probeScriptPath) -or (Test-Path -LiteralPath $markerPath)) {
    throw "A hidden-launcher probe file already exists in $PSScriptRoot; remove it and retry."
}

$probeScript = @'
param([string]$RepositoryPath)
$windowHandle = [Int64](Get-Process -Id $PID).MainWindowHandle
Set-Content -LiteralPath (Join-Path $PSScriptRoot ".hidden-launcher-probe.txt") -Value $windowHandle
Start-Sleep -Milliseconds 500
'@
Set-Content -LiteralPath $probeScriptPath -Value $probeScript -Encoding UTF8

function Quote-Argument {
    param([Parameter(Mandatory)][string]$Value)

    return '"' + $Value.Replace('"', '""') + '"'
}

$arguments = @(
    "//B"
    "//NoLogo"
    (Quote-Argument $launcherPath)
    (Quote-Argument $probeScriptPath)
    (Quote-Argument $repositoryRoot)
)
$hostProcess = $null

try {
    $hostProcess = Start-Process -FilePath $wscriptPath -ArgumentList $arguments -PassThru
    Start-Sleep -Milliseconds 100
    $hostProcess.Refresh()
    if ($hostProcess.MainWindowHandle -ne [IntPtr]::Zero) {
        throw "Windows Script Host opened a visible window."
    }

    if (-not $hostProcess.WaitForExit(10000)) {
        throw "The hidden launcher did not finish within 10 seconds."
    }
    if ($hostProcess.ExitCode -ne 0) {
        throw "The hidden launcher exited with code $($hostProcess.ExitCode)."
    }
    if (-not (Test-Path -LiteralPath $markerPath)) {
        throw "The hidden PowerShell child did not create its probe marker."
    }

    $childWindowHandle = [Int64](Get-Content -LiteralPath $markerPath -Raw)
    if ($childWindowHandle -ne 0) {
        throw "The PowerShell child opened a visible window (handle $childWindowHandle)."
    }

    Write-Output "PASS: WScript and its PowerShell child ran without a visible window."
}
finally {
    if ($null -ne $hostProcess) {
        $hostProcess.Dispose()
    }
    Remove-Item -LiteralPath $probeScriptPath, $markerPath -Force -ErrorAction SilentlyContinue
}
