[CmdletBinding()]
param(
    [string]$RepositoryPath = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"
$logPath = Join-Path $env:LOCALAPPDATA "ShadowOS\sync.log"
$repositoryMutex = $null
$mutexHeld = $false

function Write-PublishLog {
    param([Parameter(Mandatory)][string]$Message)

    $logDirectory = Split-Path -Parent $logPath
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$GitArguments)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & git -c "credential.helper=" -c "credential.helper=!gh auth git-credential" -C $RepositoryPath @GitArguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        throw "Git failed (exit code $exitCode): git $($GitArguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
}

function Invoke-Gh {
    param([Parameter(Mandatory)][string[]]$Arguments)

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    $output = & gh @Arguments 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = $previousErrorActionPreference
    if ($exitCode -ne 0) {
        throw "GitHub CLI failed (exit code $exitCode): gh $($Arguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
}

try {
    $RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
    $mutexSuffix = [regex]::Replace($RepositoryPath.ToLowerInvariant(), "[^a-z0-9]", "_")
    $repositoryMutex = New-Object System.Threading.Mutex($false, "Local\ShadowOSGitSync_$mutexSuffix")
    try {
        $mutexHeld = $repositoryMutex.WaitOne([TimeSpan]::FromSeconds(90))
    }
    catch [System.Threading.AbandonedMutexException] {
        $mutexHeld = $true
        Write-PublishLog "Recovered an abandoned repository sync lock."
    }
    if (-not $mutexHeld) {
        throw "Timed out waiting for the repository sync lock."
    }

    $branch = [string](Invoke-Git @("branch", "--show-current"))
    $branch = $branch.Trim()
    if ([string]::IsNullOrWhiteSpace($branch)) {
        throw "Automatic publication requires a named task branch."
    }

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
        throw "Could not determine the GitHub default branch from origin/HEAD."
    }

    $defaultBranch = $defaultRef.Substring("origin/".Length)
    if ($branch -eq $defaultBranch) {
        throw "Refusing to automatically publish a commit from the default branch '$defaultBranch'. Create a task branch and use a PR."
    }

    $remote = [string](Invoke-Git @("remote", "get-url", "origin"))
    $remote = $remote.Trim()
    if ($remote -notmatch "github\.com[:/]([^/]+)/([^/.]+?)(?:\.git)?$") {
        throw "Automatic PR creation requires a GitHub origin URL; found '$remote'."
    }
    $owner = $Matches[1]
    $repo = $Matches[2]

    $null = Invoke-Git @("push", "--set-upstream", "origin", $branch)
    Write-PublishLog "Published commit on $branch to origin."

    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw "Commit was pushed, but GitHub CLI (gh) is unavailable; create a PR to '$defaultBranch' manually."
    }

    $existingPr = Invoke-Gh @(
        "pr",
        "list",
        "--repo",
        "$owner/$repo",
        "--state",
        "open",
        "--head",
        $branch,
        "--json",
        "url",
        "--jq",
        ".[0].url // empty"
    )
    if ([string]::IsNullOrWhiteSpace($existingPr)) {
        $existingPr = Invoke-Gh @(
            "pr",
            "create",
            "--repo",
            "$owner/$repo",
            "--base",
            $defaultBranch,
            "--head",
            $branch,
            "--fill"
        )
        Write-PublishLog "Opened PR for ${branch} to ${defaultBranch}: $existingPr"
    }
    else {
        Write-PublishLog "Updated existing PR for ${branch}: $existingPr"
    }

    Write-Output "Published $branch and ensured a PR exists: $existingPr"
}
catch {
    $message = $_.Exception.Message
    try {
        Write-PublishLog "ERROR: $message"
    }
    catch {
        [Console]::Error.WriteLine("Could not write the sync log: $($_.Exception.Message)")
    }
    [Console]::Error.WriteLine($message)
    exit 1
}
finally {
    if ($mutexHeld -and $null -ne $repositoryMutex) {
        $repositoryMutex.ReleaseMutex()
    }
    if ($null -ne $repositoryMutex) {
        $repositoryMutex.Dispose()
    }
}
