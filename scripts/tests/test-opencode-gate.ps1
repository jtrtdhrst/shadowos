$ErrorActionPreference = "Stop"

$repositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
$syncScript = Join-Path $repositoryRoot "scripts\sync-repo.ps1"
$publishScript = Join-Path $repositoryRoot "scripts\publish-commit.ps1"
$gitExe = (Get-Command git.exe -ErrorAction Stop).Source
$global:ForbiddenGitCalls = [System.Collections.Generic.List[string]]::new()
$global:GitExe = $gitExe

function Get-Process {
    return @()
}

function git {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        [string[]]$GitArguments
    )

    $networkVerb = @($GitArguments | Where-Object { $_ -in @("fetch", "pull", "push", "clone", "ls-remote") })
    if ($networkVerb.Count -gt 0) {
        $global:ForbiddenGitCalls.Add($networkVerb[0])
        $global:LASTEXITCODE = 97
        return
    }

    $output = & $global:GitExe @GitArguments
    $exitCode = $LASTEXITCODE
    $global:LASTEXITCODE = $exitCode
    return $output
}

$syncOutput = @(& $syncScript -RepositoryPath $repositoryRoot) -join [Environment]::NewLine
if ($syncOutput -notmatch "Skipped sync because OpenCode is not running") {
    throw "FAIL: sync did not report the no-OpenCode skip. Output: $syncOutput"
}
if ($global:ForbiddenGitCalls.Count -ne 0) {
    throw "FAIL: sync attempted Git network operations: $($global:ForbiddenGitCalls -join ', ')"
}
Write-Output "PASS: scheduled sync skips before any Git network operation without OpenCode."

$publishOutput = @(& $publishScript -RepositoryPath $repositoryRoot) -join [Environment]::NewLine
if ($publishOutput -notmatch "commit remains local") {
    throw "FAIL: publisher did not leave the commit local without OpenCode. Output: $publishOutput"
}
if ($global:ForbiddenGitCalls.Count -ne 0) {
    throw "FAIL: publisher attempted Git network operations: $($global:ForbiddenGitCalls -join ', ')"
}
Write-Output "PASS: post-commit publisher skips without OpenCode and makes no Git network operation."
