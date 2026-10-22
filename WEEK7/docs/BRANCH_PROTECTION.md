# GitHub branch protection (Settings → Branches → Add rule)

Client-side hooks can be bypassed (`--no-verify`), so enforce the rules on the server too.

## Rule for `main`
- ✅ Require a pull request before merging → **1 approval**, dismiss stale approvals
- ✅ Require status checks to pass → select `gitflow-guard`, `lint`, `test (3.10)`, `test (3.11)`, `test (3.12)`
- ✅ Require branches to be up to date before merging
- ✅ Do not allow force pushes · ✅ Do not allow deletions
- ❌ Do **not** require linear history (Gitflow relies on merge commits)

## Rule for `develop`
Same as `main` (1 approval is enough).

## Repo settings
- General → Pull Requests: enable **Allow merge commits**; disable squash & rebase merging
- General → Default branch: `develop` (so PRs target it by default)
- Enable **Automatically delete head branches**

> Tip: run CI once on a PR first — GitHub only lists status checks it has seen before.
