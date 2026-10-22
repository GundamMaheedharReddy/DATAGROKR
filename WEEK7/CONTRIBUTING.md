# Contributing

## One-time setup
```bash
pip install -r requirements-dev.txt
bash scripts/install_hooks.sh        # enables pre-commit + commit-msg hooks
```

## Branch rules (Gitflow)
| Branch | Created from | Merges into | Purpose |
|---|---|---|---|
| `main` | – | – | Production code. Every commit here is a release, tagged `vX.Y.Z` |
| `develop` | `main` | – | Integration branch for the next release |
| `feature/<name>` | `develop` | `develop` | New work |
| `bugfix/<name>` | `develop` (or `release/*`) | same | Non-urgent fixes |
| `release/<x.y.z>` | `develop` | `main` **and** `develop` | Stabilise + version bump |
| `hotfix/<x.y.z>` | `main` | `main` **and** `develop` | Urgent production fix |

Never commit directly to `main` or `develop` — the pre-commit hook and branch protection both block it.

## Commit messages
[Conventional Commits](https://www.conventionalcommits.org/): `type(scope): subject`
Types: `feat fix docs style refactor perf test build ci chore revert`.

## Pull requests
1. Push your branch, open a PR with the correct base branch (see table above).
2. CI must be green: `gitflow-guard`, `lint`, `test`.
3. Get one approval, then merge with a **merge commit** (not squash/rebase) to keep the Gitflow graph.
4. Delete the branch after merging.
