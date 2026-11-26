[CmdletBinding()]
param(
    [string]$RepositoryPath = (Join-Path $PSScriptRoot "..")
)

$ErrorActionPreference = "Stop"
$logPath = Join-Path $env:LOCALAPPDATA "ShadowOS\sync.log"

function Write-PublishLog {
    param([Parameter(Mandatory)][string]$Message)

    $logDirectory = Split-Path -Parent $logPath
    New-Item -ItemType Directory -Path $logDirectory -Force | Out-Null
    Add-Content -LiteralPath $logPath -Encoding UTF8 -Value "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') $Message"
}

function Invoke-Git {
    param([Parameter(Mandatory)][string[]]$GitArguments)

    $output = & git -C $RepositoryPath @GitArguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed (exit code $LASTEXITCODE): git $($GitArguments -join ' ')`n$($output -join [Environment]::NewLine)"
    }
    return (($output | ForEach-Object { [string]$_ }) -join [Environment]::NewLine).Trim()
}

try {
    $RepositoryPath = (Resolve-Path -LiteralPath $RepositoryPath).Path
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

    $existingPr = & gh pr list --repo "$owner/$repo" --state open --head "${owner}:$branch" --json url --jq ".[0].url // empty" 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "Commit was pushed, but could not check for an existing PR: $($existingPr -join [Environment]::NewLine)"
    }
    $existingPr = [string]($existingPr | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($existingPr)) {
        $prResult = & gh pr create --repo "$owner/$repo" --base $defaultBranch --head $branch --fill 2>&1
        if ($LASTEXITCODE -ne 0) {
            throw "Commit was pushed, but PR creation failed: $($prResult -join [Environment]::NewLine)"
        }
        $existingPr = [string]($prResult | Out-String).Trim()
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
