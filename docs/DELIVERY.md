# Delivery workflow — one owner, one OpenCode agent

## 1. Purpose and operating model

GitHub is the canonical source for project code and approved documentation. OpenCode works from a local checkout, automatically discovers applicable repository instructions, and reads the relevant PRD and docs on demand. Git provides version history and synchronization; do not build a separate document synchronization system.

The agent is responsible for implementing and verifying agreed work. The human owner defines product intent, grants access and resolves material decisions. Routine changes should not need manual review if the configured rules permit autonomous merge. No additional agent, issue tracker, context service or review layer is required for this operating model.

**Normal cycle:** sync → branch → implement → local checks → PR → required CI → merge → deploy (if applicable) → verify → report and clean up.

## 2. Repository and OpenCode setup

Keep the following files at the repository root / paths shown:

```text
repository/
├── AGENTS.md
├── PRD.md
├── README.md              # if the project needs one
├── docs/
│   └── DELIVERY.md
└── .github/workflows/     # actual CI configuration, if using GitHub Actions
```

Launch OpenCode from the project checkout. No extra `opencode.json` is required merely to discover `AGENTS.md`. If the repository already contains OpenCode configuration, preserve it unless a specific change is required. Do not add the whole PRD or docs tree to always-loaded instructions; `AGENTS.md` points to the relevant files. Nested `AGENTS.md` files may be used where local rules genuinely differ.

At the start of each task, fetch the remote and work from the appropriate up-to-date branch. Remote changes do not magically update local files. Start a fresh task/session after significant instruction changes when needed to ensure the applicable rules are read. Use Git's native history; no separate SHA registry is necessary.

### Multi-computer synchronization

The canonical project documents are `AGENTS.md`, `PRD.md`, and `docs/DELIVERY.md` in this GitHub repository. Work from a clone of this repository on every computer; do not maintain separate editable copies or copy the files between machines. GitHub sync is commit-based, not real-time: uncommitted changes and files outside the checkout stay on that computer. Changes become canonical after their pull request is merged into the default branch.

On a computer that does not yet have a checkout:

```sh
git clone https://github.com/jtrtdhrst/shadowos.git
cd shadowos
git status --short --branch
git symbolic-ref refs/remotes/origin/HEAD
```

The clone checks out GitHub's default branch. For this repository it currently resolves to `bootstrap`; do not assume `main` exists.

Before continuing work on an existing checkout, inspect local changes and preserve them before updating:

```sh
git status --short --branch
git fetch origin
git switch bootstrap
git pull --ff-only origin bootstrap
```

Make edits on a task branch based on the updated default branch, then commit, push, and open a pull request into `bootstrap`. Once merged, repeat the update commands on the other computers. Do not pull over uncommitted work or use force-push to resolve divergence.

To verify synchronization on another checkout after a merge:

```sh
git fetch origin
git switch bootstrap
git pull --ff-only origin bootstrap
git rev-parse HEAD
git ls-tree -r --name-only HEAD -- AGENTS.md PRD.md docs/DELIVERY.md
git status --short --branch
```

Confirm that `HEAD` matches `origin/bootstrap`, all three paths are listed, and the checkout is clean. This verifies repository synchronization; it does not claim live/background synchronization of arbitrary desktop files.

#### Automatic updates on Windows

For a local folder that should synchronize commits in both directions, use `scripts/sync-repo.ps1 -Install` from the checkout. Installation configures the repository-local `.githooks` directory and a per-user Windows Scheduled Task. The `post-commit` hook publishes each task-branch commit only while the OpenCode desktop window or CLI process is running, then opens a PR to the current default branch if needed. Commits on the default branch are deliberately not auto-pushed: create a task branch and use the PR workflow. GitHub-to-local synchronization checks the currently checked-out branch once per minute but performs no Git network operations unless OpenCode is running; it fast-forwards only a clean working tree. A dirty tree, divergent history, missing remote branch, or authentication failure is never reset or overwritten; check `%LOCALAPPDATA%\ShadowOS\sync.log` and resolve the condition before retrying.

Install GitHub CLI and authenticate it once on each computer (`gh auth login`), then from the repository root in PowerShell install the post-commit hook and per-user Scheduled Task:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-repo.ps1 -Install
```

The task uses a hidden Windows Script Host launcher (`wscript.exe` in batch mode) for PowerShell, so it does not open a console window. It checks once per minute while that Windows user is signed in and the network is available, but only synchronizes while the OpenCode desktop window (`OpenCode.exe` with a main window) or OpenCode CLI (`opencode-cli.exe`) is running. It does not replay missed runs and skips overlapping runs. The Git hook applies the same OpenCode-running gate to commit publication. Sync/publish commands use the existing `gh` authentication through a command-scoped Git credential helper; no token is written to repository files or global Git configuration. Local task-branch commits are pushed by the Git post-commit hook (not by the scheduled task). Its update/error log is `%LOCALAPPDATA%\ShadowOS\sync.log`. To run a one-time sync manually, omit `-Install`; to remove the task, use `-Uninstall`:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-repo.ps1 -RepositoryPath .
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\sync-repo.ps1 -Uninstall
```

The scheduled task uses `-ExecutionPolicy Bypass` for its hidden PowerShell child only; it does not change the machine's execution-policy setting. GitHub commits appear after the next successful one-minute poll while OpenCode is running; this is near-real-time polling, not an instant webhook. The task updates the currently checked-out branch only. To receive a merged PR on a checkout that is on a task branch, switch to the default branch after preserving or merging that work. Each computer needs its own clone, Git hook installation, and scheduled task. GitHub is authoritative for committed history. Run the Windows process-gate and no-visible-window regression tests with `powershell.exe -NoProfile -File .\scripts\tests\test-opencode-process.ps1`, `powershell.exe -NoProfile -File .\scripts\tests\test-opencode-gate.ps1`, and `powershell.exe -NoProfile -File .\scripts\tests\test-hidden-launcher.ps1`.

## 3. Branch protections and one-time GitHub setup

Use a branch ruleset or classic branch protection, not duplicate mechanisms for the same purpose. The owner must configure and verify the actual repository settings; availability depends on repository visibility, plan and permissions.

**Current repository state:** `bootstrap` is the GitHub default branch and `main` does not exist. An active ruleset protects `main`; it has prevented renaming `bootstrap` or creating `main`, and requires a `ci` check. The repository currently has no GitHub Actions workflows to emit that check. Keep protection unchanged; do not bypass it. Use the current default branch for work and PRs until the owner completes an approved `main` bootstrap and configures real CI.

Recommended `main` policy if it becomes the default:

| Rule | Setting |
| --- | --- |
| Enforcement | Active |
| Prevent deletion | On |
| Prevent force pushes | On |
| Require pull request before merge | On |
| Required approving reviews | 0 |
| Require passing status checks | On, after actual checks exist |
| Require branch up to date before merge | Optional; useful for a single release branch if not causing unnecessary churn |
| Require linear history | On if squash/rebase merging is configured |
| Required code owner review / merge queue / signed commits | Off unless separately required |
| Routine agent bypass | None |

Enable squash merging and automatic deletion of merged head branches. Auto-merge may be enabled but is optional; the agent may merge directly once requirements pass and its account is authorized. Do not use administrator bypass as routine delivery. Ensure the actual agent identity can open, update and merge PRs within the rules. The owner retains administrative control and emergency recovery access.

Bootstrap CI before making its checks mandatory: add or verify the real workflow, run it on a test PR, then select the actual emitted check names in the ruleset. Avoid requiring nonexistent, renamed or path-skipped checks. Any existing stricter policy remains in force until the owner explicitly approves a change.

## 4. Project-specific operational facts — complete once

Discover these from existing repository configuration and deployment tooling. Ask the owner only for facts that cannot be determined. Do not invent values or introduce infrastructure to fill the table.

| Fact | Value |
| --- | --- |
| GitHub repository / default branch | `jtrtdhrst/shadowos` / `bootstrap` (verified through `origin/HEAD`) |
| Production website | <https://shadowos.miloszspyrka.pl/> (owner-provided) |
| Runtime and package manager | Static HTML/CSS/JS; Wrangler CLI via `npx` |
| Setup/install command | None |
| Local lint / typecheck / test / build commands | No configured lint, typecheck or test suite; validate Worker deployment with Wrangler dry-run |
| Required GitHub check names | `Workers Builds: shadow-os` (Preview and Production builds passed for the latest merged revision; see PR #2 and its linked check runs) |
| Deployment target and trigger | Cloudflare Worker `shadow-os`; owner-confirmed Production branch `bootstrap`, build command none, Production deploy command `npx wrangler deploy`, Preview command `npx wrangler preview`, root `/`, watch include `*` and exclude `node_modules/**, .git/`; Wrangler config must include `previews` (empty for this static Worker). Production URL: <https://shadowos.miloszspyrka.pl/> |
| How to identify deployed revision | Cloudflare Production build for commit `2d610cfec61e2bafa05b168dda70c607408b538f`: [build `e336fc80-0a54-4647-9c39-660732506cda`](https://dash.cloudflare.com/c056821a7ee2aabdcf0a6dc447490184/workers/services/view/shadow-os/production/builds/e336fc80-0a54-4647-9c39-660732506cda); Worker version `b6d87104-5e74-4fa6-bb8b-bba3bd457ef8` |
| Production URL / smoke checks | Owner-provided page content includes `Hello, world.` and `ONLINE`; independent HTTP/browser smoke test still needs the public Worker URL. Verify the page response, CSS/JS assets, and the status button interaction |
| Rollback procedure / previous release identification | Cloudflare deployment history; procedure not yet exercised |
| Secret management location (names only, never values) | Cloudflare Workers Builds settings; never record token values or identifiers in repository docs |

## 5. Task execution

### 5.1 Sync and branch

Check status and fetch before implementation. The following commands illustrate the standard path; adapt to the actual remote and existing branches. Run branch creation only when the checkout is clean and no canonical branch/PR exists for the task.

```sh
git status --short --branch
git fetch origin
git switch bootstrap
git pull --ff-only origin bootstrap
git switch -c feat/short-task-name
```

Use `fix/`, `feat/`, or `docs/` names as appropriate. If working changes exist, preserve them and determine whether they belong to the same task. Continue the existing branch/PR when appropriate. Do not force reset, overwrite owner changes, or create duplicate branches. If local `main` diverged or fetch fails, resolve safely before delivery; do not silently pretend the local state is current.

Read `AGENTS.md`, applicable PRD requirements and relevant files. Identify the acceptance criteria, impacted areas and checks. A short mental/task checklist is sufficient; a separate plan document is unnecessary for routine work.

### 5.2 Implement and verify locally

Implement the smallest complete solution, following existing code conventions. Add relevant regression tests and update affected documentation. Run the actual project commands discovered in section 4. At minimum, inspect the resulting diff and run applicable tests. Do not invent a lint, typecheck or build command for a stack that does not use one.

Before pushing, check `git status`, `git diff` and the staged diff. Stage intended paths only. Ensure no credentials, local environment files, unrelated changes or generated clutter are included.

### 5.3 Pull request and CI

Commit and push the task branch. Open or update the one PR targeting the current GitHub default branch (`bootstrap` while it remains the default). Use the GitHub UI, authorized GitHub tooling or authenticated `gh` CLI already available; do not add a new integration just to perform this step.

PR description should include: scope/reason, relevant requirement or task reference (if present), tests run and results, deployment or migration notes when needed, and any known limitations.

Wait for configured required checks on the actual latest PR head to reach a terminal result; queued or running checks are not complete. If the PR head changes, wait for and verify the new checks. If CI fails, inspect its actual logs, reproduce where practical, fix the underlying issue on the same branch and rerun. Rerun transient infrastructure failures only when evidence supports that diagnosis. Never bypass a required check or report checks as passed before they finish.

Before merge, ensure the PR is in scope, required checks pass, any branch conflicts are resolved and the PR head has not changed since verification. If upstream requirements have changed, reconcile the affected scope first. Where the ruleset permits autonomous merging, squash merge without an unnecessary manual review. If approval or access is genuinely required by existing policy, request the exact missing action rather than bypassing it.

### 5.4 CI baseline

Use one straightforward CI workflow unless the project needs separation. For code changes, choose applicable checks from:

- Reproducible dependency installation using the existing lockfile.
- Lint and typecheck if supported by the stack.
- Automated unit/integration tests, including relevant regressions.
- Production build or equivalent package validation.
- Secret detection using available repository or CI tooling; never expose detected secret values.

Run required checks on PRs targeting the current default branch (`bootstrap` while it remains the default); ensure the required check reports a result even for changes that safely skip expensive steps. Verify the merged revision as well where the deployment process depends on a successful default-branch build. Do not require tools that do not apply to the stack or introduce artificial checks solely for process compliance.

### 5.5 Deploy and verify

For a deployed product, prefer the existing pipeline's deployment triggered by the merged current default branch (`bootstrap` while it remains the default). If deployment requires an authorized manual action, perform it only within the agreed policy. Do not add a deployment system unless requested. Do not deploy a feature branch directly to production as a substitute for merging.

Wait for the production build/deployment to finish. Verify the deployment result and the actual revision/build identity against the intended release using existing platform evidence (commit SHA, image digest or release record). Check application health and perform the primary affected user journey plus relevant negative scenarios. Use safe, non-destructive test data or an authorized test environment; do not alter real customer data for verification. If build/deployment status or revision identity cannot be observed, report the precise blocker and do not claim deployment verification.

For the static ShadowOS page, the browser smoke test should confirm the page loads with `Hello, world.`, the status reads `ONLINE`, the CSS and JavaScript assets load successfully, and **Sprawdź status** updates the status message. When the page version is part of the change, confirm the visible version matches it. A green Cloudflare build alone does not satisfy this check.

Documentation-only changes or tasks without a deployment target can be completed at their applicable delivery level. If a production deployment is expected but cannot be verified, explicitly report `MERGED — DEPLOYMENT UNVERIFIED` or the actual failure state. Do not equate a successful build with a successful deployment.

## 6. Failures and rollback

| Situation | Required response |
| --- | --- |
| Git fetch fails | Diagnose access/network; local inspection only if safe; no remote-state claims or merge until verified. |
| CI fails | Inspect failing check; fix on the same branch; rerun and verify. |
| Merge conflict | Preserve unrelated work; resolve or update the task branch using the repository's normal policy; rerun checks. |
| Deployment fails | Inspect deployment logs and release identity; fix the cause or restore a known-good release. |
| Production regression | Restore known-good behavior using the configured rollback mechanism; verify service recovery; track the forward fix or revert. |
| Missing access or a material owner decision | State the precise missing permission or decision and continue independent safe work. |

For deployments, record the previous known-good release using the existing platform. Rollback may use redeployment of that release or a reviewed revert of the faulty change, depending on the platform and repository policy. Avoid destructive history rewriting. Database migrations require particular care: do not assume reverting application code reverses data or schema changes. For changes with material migration risk, verify backup/recovery and compatibility before deployment; seek owner approval where necessary.

A recovery procedure is not evidence that rollback works. For a new deployment pipeline or materially changed release mechanism, validate the recovery path in an appropriate environment before relying on it. Do not force a production rollback for every successful routine change.

## 7. Completion and cleanup

After successful delivery, verify the PR merge and applicable deployment/tests. Let GitHub delete the merged head branch automatically where enabled; clean the local branch only when its work is safely merged and no changes remain. Do not remove unrelated branches. Refresh the current default branch (`bootstrap` while it remains the default) safely when returning to it.

Keep GitHub as the history of code, PRs and decisions. An issue tracker is optional. If the task was tracked in an issue, update its status only to match verified delivery. No separate audit system is required for this project size.

Use a concise final report in the owner's language. Use only observed evidence; mark each applicable check/stage as `PASS`, `FAIL`, `PENDING`, `BLOCKED` or `N/A` with a reason. Do not call a queued/running check `PASS`, imply that a preview is production, or report `DONE` while a required stage is unverified. Distinguish blockers (which require access, a decision or corrective work) from non-blocking limitations.

```text
Outcome: DONE | MERGED — DEPLOYMENT UNVERIFIED | INCOMPLETE
Change: <what changed and why>
Local checks: <command/test and PASS/FAIL, or N/A with reason>
PR checks: <exact PR head, terminal status and check link; or BLOCKED/PENDING with reason>
PR / merge: <PR link and merged revision, or current PR state>
Deployment: <target, build ID and deployed revision; or N/A with reason; state BLOCKED if identity/status is unverified>
Smoke / E2E: <actual scenario and result, or N/A with reason>
Blockers: <each blocker, exact cause and required next action; or none>
Limitations: <known non-blocking gaps, or none>
```

For investigation-only or explicitly limited tasks, report the actual requested outcome and omit irrelevant implementation stages. For production-changing work, DONE requires the applicable end-to-end conditions in `AGENTS.md`.
