[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [string]$RepositoryPath = "",
    [switch]$Install,
    [switch]$Uninstall
)

$ErrorActionPreference = "Stop"
$TaskName = "ShadowOS GitHub Auto Sync"
$script:GitWorkingDirectory = $null
$script:RepositoryRoot = $null
$script:RepositoryMutex = $null
$script:MutexHeld = $false
$script:LogPath = Join-Path $env:LOCALAPPDATA "ShadowOS\sync.log"

function Write-SyncLog {
    param([Parameter(Mandatory)][string]$Message)

    $logDirectory = Split-Path -Parent $script:LogPath
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null

    if ((Test-Path -LiteralPath $script:LogPath) -and
        (Get-Item -LiteralPath $script:LogPath).Length -ge 1MB) {
        $previousLog = "$($script:LogPath).1"
        if (Test-Path -LiteralPath $previousLog) {
            Remove-Item -LiteralPath $previousLog -Force
        }
        Move-Item -LiteralPath $script:LogPath -Destination $previousLog
    }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -LiteralPath $script:LogPath -Encoding UTF8 -Value "$timestamp $Message"
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$GitArguments)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & git -c "credential.helper=" -c "credential.helper=!gh auth git-credential" -C $script:GitWorkingDirectory @GitArguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        throw "Git command failed (exit code $exitCode): git $($GitArguments -join ' ')"
    }

    return (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
}

function Initialize-Repository {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        throw "Git was not found. Install Git for Windows and retry."
    }

    if ([string]::IsNullOrWhiteSpace($RepositoryPath)) {
        $RepositoryPath = Join-Path $PSScriptRoot ".."
    }

    $script:GitWorkingDirectory = (Resolve-Path -LiteralPath $RepositoryPath).Path
    $script:RepositoryRoot = [string](Invoke-Git @("rev-parse", "--show-toplevel"))
    $script:RepositoryRoot = $script:RepositoryRoot.Trim()
    $script:GitWorkingDirectory = $script:RepositoryRoot
}

function Invoke-RepositorySync {
    $before = [string](Invoke-Git @("rev-parse", "HEAD"))
    $before = $before.Trim()

    $null = Invoke-Git @("fetch", "--quiet", "origin")
    $null = Invoke-Git @("remote", "set-head", "origin", "--auto")

    $defaultRef = [string](Invoke-Git @(
        "symbolic-ref",
        "--quiet",
        "--short",
        "refs/remotes/origin/HEAD"
    ))
    $defaultRef = $defaultRef.Trim()
    if (-not $defaultRef.StartsWith("origin/")) {
        throw "Could not resolve the GitHub default branch from origin/HEAD."
    }

    $currentBranch = [string](Invoke-Git @("branch", "--show-current"))
    $currentBranch = $currentBranch.Trim()
    if ([string]::IsNullOrWhiteSpace($currentBranch)) {
        throw "Could not resolve the checked-out branch; automatic sync requires a branch checkout."
    }

    $trackingRef = "refs/remotes/origin/$currentBranch"
    $trackingExists = & git -C $script:GitWorkingDirectory show-ref --verify --quiet $trackingRef
    if ($LASTEXITCODE -ne 0) {
        $message = "No origin/$currentBranch branch exists yet; nothing to pull."
        Write-SyncLog $message
        return $message
    }

    $localChanges = [string](Invoke-Git @(
        "status",
        "--porcelain",
        "--untracked-files=all"
    ))
    if (-not [string]::IsNullOrWhiteSpace($localChanges)) {
        throw "This checkout has local changes. Sync stopped without changing files; preserve the work, then retry."
    }

    $null = Invoke-Git @("merge", "--ff-only", "origin/$currentBranch")
    $after = [string](Invoke-Git @("rev-parse", "HEAD"))
    $after = $after.Trim()

    if ($before -ne $after) {
        $message = "Updated $currentBranch from $before to $after."
        Write-SyncLog $message
        return $message
    }

    return "Already current: $currentBranch at $after."
}

try {
    if ($Install -and $Uninstall) {
        throw "Choose either -Install or -Uninstall, not both."
    }

    Initialize-Repository
    $mutexSuffix = [regex]::Replace($script:RepositoryRoot.ToLowerInvariant(), "[^a-z0-9]", "_")
    $script:RepositoryMutex = New-Object System.Threading.Mutex($false, "Local\ShadowOSGitSync_$mutexSuffix")
    try {
        $script:MutexHeld = $script:RepositoryMutex.WaitOne([TimeSpan]::FromSeconds(30))
    }
    catch [System.Threading.AbandonedMutexException] {
        $script:MutexHeld = $true
        Write-SyncLog "Recovered an abandoned repository sync lock."
    }
    if (-not $script:MutexHeld) {
        Write-SyncLog "Skipped sync because another repository sync/publish is running."
        Write-Output "Skipped: another repository sync/publish is running."
        return
    }

    if ($Uninstall) {
        $existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
        if ($null -eq $existingTask) {
            Write-Output "Scheduled task '$TaskName' is not installed."
            return
        }

        if ($PSCmdlet.ShouldProcess($TaskName, "Remove scheduled task")) {
            Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
            Write-SyncLog "Removed scheduled task."
            Write-Output "Removed scheduled task '$TaskName'."
        }
        return
    }

    if ($Install) {
        $powerShellPath = (Get-Process -Id $PID).Path
        $scriptPath = (Resolve-Path -LiteralPath $PSCommandPath).Path
        $taskArguments = "-NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -RepositoryPath `"$($script:RepositoryRoot)`""
        $action = New-ScheduledTaskAction -Execute $powerShellPath -Argument $taskArguments
        $trigger = New-ScheduledTaskTrigger `
            -Once `
            -At (Get-Date).AddMinutes(1) `
            -RepetitionInterval ([TimeSpan]::FromMinutes(1))
        $settings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -MultipleInstances IgnoreNew `
            -ExecutionTimeLimit ([TimeSpan]::FromMinutes(5))
        $principal = New-ScheduledTaskPrincipal `
            -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) `
            -LogonType Interactive `
            -RunLevel Limited

        if ($PSCmdlet.ShouldProcess($TaskName, "Install/update per-user task to sync every minute")) {
            $hooksPath = Join-Path $script:RepositoryRoot ".githooks"
            if (-not (Test-Path -LiteralPath (Join-Path $hooksPath "post-commit"))) {
                throw "Git post-commit hook not found in $hooksPath."
            }
            if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
                throw "GitHub CLI (gh) is required for commit publication and PR creation. Install it and run 'gh auth login'."
            }
            & gh auth status --hostname github.com *> $null
            if ($LASTEXITCODE -ne 0) {
                throw "GitHub CLI is not authenticated. Run 'gh auth login' and retry installation."
            }
            $null = Invoke-Git @("config", "--local", "core.hooksPath", ".githooks")
            $syncResult = Invoke-RepositorySync
            Register-ScheduledTask `
                -TaskName $TaskName `
                -Action $action `
                -Trigger $trigger `
                -Settings $settings `
                -Principal $principal `
                -Description "Fast-forward the clean checked-out ShadowOS branch from its matching GitHub branch every minute." `
                -Force | Out-Null
            Write-SyncLog "Installed scheduled task; $syncResult"
            Write-Output "Installed '$TaskName'. It checks the checked-out branch every minute while you are signed in; local task-branch commits are pushed by the Git post-commit hook."
            Write-Output $syncResult
        }
        return
    }

    if ($PSCmdlet.ShouldProcess($script:RepositoryRoot, "Fast-forward from the GitHub default branch")) {
        Write-Output (Invoke-RepositorySync)
    }
}
catch {
    $message = $_.Exception.Message
    try {
        Write-SyncLog "ERROR: $message"
    }
    catch {
        [Console]::Error.WriteLine("Could not write the sync log: $($_.Exception.Message)")
    }
    [Console]::Error.WriteLine($message)
    exit 1
}
finally {
    if ($script:MutexHeld -and $null -ne $script:RepositoryMutex) {
        $script:RepositoryMutex.ReleaseMutex()
    }
    if ($null -ne $script:RepositoryMutex) {
        $script:RepositoryMutex.Dispose()
    }
}
