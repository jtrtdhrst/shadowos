$ErrorActionPreference = "Stop"
. (Join-Path $PSScriptRoot "..\opencode-process.ps1")

$cases = @(
    @{
        Name = "no processes means no OpenCode"
        Processes = @()
        Expected = $false
    }
    @{
        Name = "headless desktop helper is not the open app"
        Processes = @([pscustomobject]@{
            ProcessName = "OpenCode"
            MainWindowHandle = [IntPtr]::Zero
        })
        Expected = $false
    }
    @{
        Name = "desktop main window enables sync"
        Processes = @([pscustomobject]@{
            ProcessName = "OpenCode"
            MainWindowHandle = [IntPtr]1
        })
        Expected = $true
    }
    @{
        Name = "OpenCode CLI enables sync"
        Processes = @([pscustomobject]@{
            ProcessName = "opencode-cli"
            MainWindowHandle = [IntPtr]::Zero
        })
        Expected = $true
    }
)

foreach ($case in $cases) {
    $actual = Test-OpenCodeRunning -Processes $case.Processes
    if ($actual -ne $case.Expected) {
        throw "FAIL: $($case.Name); expected $($case.Expected), got $actual."
    }
    Write-Output "PASS: $($case.Name)"
}
