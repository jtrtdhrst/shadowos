function Test-OpenCodeRunning {
    [CmdletBinding()]
    param(
        [Parameter()]
        [object[]]$Processes
    )

    if (-not $PSBoundParameters.ContainsKey("Processes")) {
        $Processes = @(Get-Process -ErrorAction SilentlyContinue)
    }

    foreach ($process in $Processes) {
        if ($null -eq $process) {
            continue
        }

        $processName = [string]$process.ProcessName
        if ([string]::IsNullOrWhiteSpace($processName)) {
            $processName = [string]$process.Name
        }
        $processName = [System.IO.Path]::GetFileNameWithoutExtension($processName)

        if ($processName -ieq "opencode-cli") {
            return $true
        }

        if ($processName -ieq "OpenCode") {
            try {
                if ([Int64]$process.MainWindowHandle -ne 0) {
                    return $true
                }
            }
            catch {
                continue
            }
        }
    }

    return $false
}
