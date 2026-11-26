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

## 3. One-time GitHub setup (recommended, not yet applied)

Use a branch ruleset or classic branch protection, not duplicate mechanisms for the same purpose. The owner must configure and verify the actual repository settings; availability depends on repository visibility, plan and permissions.

Recommended `main` policy:

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
| GitHub repository / default branch | TBD / main (verify) |
| Runtime and package manager | TBD |
| Setup/install command | TBD |
| Local lint / typecheck / test / build commands | TBD |
| Required GitHub check names | TBD |
| Deployment target and trigger | TBD / N/A |
| How to identify deployed revision | TBD / N/A |
| Production URL / smoke checks | TBD / N/A |
| Rollback procedure / previous release identification | TBD / N/A |
| Secret management location (names only, never values) | TBD / N/A |

## 5. Task execution

### 5.1 Sync and branch

Check status and fetch before implementation. The following commands illustrate the standard path; adapt to the actual remote and existing branches. Run branch creation only when the checkout is clean and no canonical branch/PR exists for the task.

```sh
git status --short --branch
git fetch origin
git switch main
git pull --ff-only origin main
git switch -c feat/short-task-name
```

Use `fix/`, `feat/`, or `docs/` names as appropriate. If working changes exist, preserve them and determine whether they belong to the same task. Continue the existing branch/PR when appropriate. Do not force reset, overwrite owner changes, or create duplicate branches. If local `main` diverged or fetch fails, resolve safely before delivery; do not silently pretend the local state is current.

Read `AGENTS.md`, applicable PRD requirements and relevant files. Identify the acceptance criteria, impacted areas and checks. A short mental/task checklist is sufficient; a separate plan document is unnecessary for routine work.

### 5.2 Implement and verify locally

Implement the smallest complete solution, following existing code conventions. Add relevant regression tests and update affected documentation. Run the actual project commands discovered in section 4. At minimum, inspect the resulting diff and run applicable tests. Do not invent a lint, typecheck or build command for a stack that does not use one.

Before pushing, check `git status`, `git diff` and the staged diff. Stage intended paths only. Ensure no credentials, local environment files, unrelated changes or generated clutter are included.

### 5.3 Pull request and CI

Commit and push the task branch. Open or update the one PR targeting `main`. Use the GitHub UI, authorized GitHub tooling or authenticated `gh` CLI already available; do not add a new integration just to perform this step.

PR description should include: scope/reason, relevant requirement or task reference (if present), tests run and results, deployment or migration notes when needed, and any known limitations.

Wait for configured required checks on the actual latest PR head. If the PR head changes, verify the new checks. If CI fails, inspect its actual logs, reproduce where practical, fix the underlying issue on the same branch and rerun. Rerun transient infrastructure failures only when evidence supports that diagnosis. Never bypass a required check.

Before merge, ensure the PR is in scope, required checks pass, any branch conflicts are resolved and the PR head has not changed since verification. If upstream requirements have changed, reconcile the affected scope first. Where the ruleset permits autonomous merging, squash merge without an unnecessary manual review. If approval or access is genuinely required by existing policy, request the exact missing action rather than bypassing it.

### 5.4 CI baseline

Use one straightforward CI workflow unless the project needs separation. For code changes, choose applicable checks from:

- Reproducible dependency installation using the existing lockfile.
- Lint and typecheck if supported by the stack.
- Automated unit/integration tests, including relevant regressions.
- Production build or equivalent package validation.
- Secret detection using available repository or CI tooling; never expose detected secret values.

Run required checks on PRs targeting `main`; ensure the required check reports a result even for changes that safely skip expensive steps. Verify the merged revision as well where the deployment process depends on a successful main build. Do not require tools that do not apply to the stack or introduce artificial checks solely for process compliance.

### 5.5 Deploy and verify

For a deployed product, prefer the existing pipeline's deployment triggered by the merged `main` revision. If deployment requires an authorized manual action, perform it only within the agreed policy. Do not add a deployment system unless requested. Do not deploy a feature branch directly to production as a substitute for merging.

Verify the deployment result and the actual revision/build identity against the intended release using existing platform evidence (commit SHA, image digest or release record). Check application health and perform the primary affected user journey plus relevant negative scenarios. Use safe, non-destructive test data or an authorized test environment; do not alter real customer data for verification.

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

After successful delivery, verify the PR merge and applicable deployment/tests. Let GitHub delete the merged head branch automatically where enabled; clean the local branch only when its work is safely merged and no changes remain. Do not remove unrelated branches. Refresh `main` safely when returning to it.

Keep GitHub as the history of code, PRs and decisions. An issue tracker is optional. If the task was tracked in an issue, update its status only to match verified delivery. No separate audit system is required for this project size.

Use a concise final report:

```text
Outcome: DONE | MERGED — DEPLOYMENT UNVERIFIED | INCOMPLETE
Change: <what changed and why>
Checks: <actual commands/results or check links>
PR / merge: <link and revision, if applicable>
Deployment: <target and release identity, or N/A>
Verification: <actual smoke/E2E results, or N/A with reason>
Remaining: <specific unresolved item or none>
```

For investigation-only or explicitly limited tasks, report the actual requested outcome and omit irrelevant implementation stages. For production-changing work, DONE requires the applicable end-to-end conditions in `AGENTS.md`.
