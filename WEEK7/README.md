# Full Gitflow Simulation — Week 7 Mini Project

A hands-on project that plays through the **entire Gitflow lifecycle** with real git commands:
feature branch → pull request → merge → release → hotfix, protected by a **pre-commit hook**
and automated by **GitHub Actions CI**.

| Week 7 topic | Where it lives |
|---|---|
| Feature branch, PR, merge | `scripts/simulate_gitflow.sh` (phases 2–3), `docs/GITFLOW_CHEATSHEET.md` |
| Release lifecycle | simulation phase 4, `scripts/bump_version.py`, `.github/workflows/release.yml` |
| Hotfix lifecycle | simulation phase 5 |
| Pre-commit hook | `hooks/pre-commit`, `hooks/commit-msg`, `scripts/install_hooks.sh` |
| GitHub Actions CI | `.github/workflows/ci.yml`, `.github/workflows/release.yml` |

## Requirements
* Git 2.28+ and Python 3.10+
* `pip install -r requirements-dev.txt` (pytest + flake8; optional for the simulation, required for CI parity)
* **Windows users:** run the scripts from **Git Bash** (comes with Git for Windows) or WSL
* Optional for the real-GitHub walkthrough: [GitHub CLI](https://cli.github.com/) (`gh`)

## Quick start — run the simulation (2 minutes)

```bash
bash scripts/simulate_gitflow.sh          # or: make simulate
```

It builds a sandbox in `/tmp/gitflow-sandbox` (a bare `origin.git` + a working clone), so it never
touches your own repository, and prints every command it runs. Pass a folder to change the location:
`bash scripts/simulate_gitflow.sh ~/gitflow-demo`.

### What it does

| Phase | What happens | What you learn |
|---|---|---|
| 0 Setup | bare origin, `main` + `develop`, hooks installed | long-lived branches |
| 1 Hook demo | commit straight to `develop` → **blocked** | branch protection in the hook |
| 2 `feature/multiply` | breakpoint → **blocked**; bad message → **blocked**; proper commits; PR #1 merged | pre-commit + commit-msg hooks, `--no-ff` merges |
| 3 `feature/divide` | PR #2 merged (contains a latent bug) | feature lifecycle |
| 4 `release/1.0.0` | branch from `develop`, `feature/stats` lands on develop meanwhile, docs fix, version bump, merge → `main`, tag `v1.0.0`, back-merge → `develop` | release lifecycle; why release branches exist |
| 5 `hotfix/1.0.1` | failing test commit → **blocked**; fix, bump, merge → `main`, tag `v1.0.1`, merge → `develop` | hotfix lifecycle |
| 6 Result | graph, tags, versions | `stats.py` is only on `develop` — it was not in 1.0.x |

### Expected final graph (trimmed)
```
*   Merge pull request #7 from hotfix/1.0.1          (develop)
*   Merge pull request #5 from release/1.0.0
*   Merge pull request #3 from feature/stats
|   *  Merge pull request #6 from hotfix/1.0.1        (tag: v1.0.1, main)
|   *  chore(release): bump version to 1.0.1
|   *  fix(calculator): raise ValueError when dividing by zero
|   *  Merge pull request #4 from release/1.0.0       (tag: v1.0.0)
...
```
Explore it yourself afterwards: `cd /tmp/gitflow-sandbox/work && git log --graph --oneline --all`

## The branching model

```
 main      ●───────────────────●─────────────●──────────  production, tagged
            \                 /  v1.0.0       ↑ v1.0.1
 hotfix                       │          ●────●
                              │         /      \
 release              ●──●────●        /        \
                     /                /          \
 develop  ●────●────●────●────●───────●────────────●────  next release
           \  /      \  /
 feature    ●●        ●●
```

| Branch | From | Into | Lifetime |
|---|---|---|---|
| `main` | – | – | permanent, every commit is a release |
| `develop` | `main` | – | permanent |
| `feature/*`, `bugfix/*` | `develop` | `develop` | short |
| `release/x.y.z` | `develop` | `main` + `develop` | short |
| `hotfix/x.y.z` | `main` | `main` + `develop` | very short |

## Git hooks

Install once per clone (the simulation does this for you):
```bash
bash scripts/install_hooks.sh      # sets core.hooksPath=hooks
```

**`hooks/pre-commit`** runs before each commit and blocks if:
1. you are on `main`, `master` or `develop`
2. staged changes have whitespace errors, a file > 1 MB, a leaked AWS key / private key, or a `breakpoint()` / `pdb` call
3. `flake8` reports problems (if installed)
4. the test-suite fails

**`hooks/commit-msg`** enforces [Conventional Commits](https://www.conventionalcommits.org/):
`feat(calculator): add multiply()` ✔ — `added multiply stuff` ✖ (merge/revert/fixup commits are allowed).

Escape hatches (use sparingly): `git commit --no-verify`, `SKIP_TESTS=1`, `GITFLOW_ALLOW_PROTECTED=1`.

## GitHub Actions CI

| Workflow | Trigger | Jobs |
|---|---|---|
| `ci.yml` | push to `main`/`develop`/`release/**`/`hotfix/**`, PRs to `main`/`develop`/`release/**` | **gitflow-guard** (branch-name + target rules), **lint** (flake8), **test** (pytest on Python 3.10/3.11/3.12) |
| `release.yml` | push of a tag `vX.Y.Z` | checks tag is on `main` and equals `app.__version__`, runs tests, copies that version's CHANGELOG section into a **GitHub Release** |

`gitflow-guard` rules: branch names must be `feature|bugfix|release|hotfix/<name>`; only `release/*` and
`hotfix/*` may target `main`; only `bugfix/*` may target a `release/*` branch.

## Run it for real on GitHub

```bash
# 1. publish this project
git init -b main && git add -A && git commit -m "chore: initial commit"
gh repo create gitflow-simulation --public --source=. --push
git checkout -b develop && git push -u origin develop
bash scripts/install_hooks.sh

# 2. protect branches  ->  follow docs/BRANCH_PROTECTION.md

# 3. first feature through a real PR
git checkout -b feature/multiply
#   ...add multiply(), tests; commit with a conventional message...
git push -u origin feature/multiply
gh pr create --base develop --title "Add multiply()" --body "First Gitflow PR"
gh pr checks --watch                # watch CI run
gh pr merge --merge --delete-branch # merge commit, not squash
```
Then repeat the release and hotfix steps from `docs/GITFLOW_CHEATSHEET.md`. After you push tag `v1.0.0`,
check the **Actions** tab and the **Releases** page.

## Project layout
```
gitflow-simulation/
├── README.md · CONTRIBUTING.md · CHANGELOG.md · Makefile
├── app/                      demo app (calculator) at v0.1.0
├── tests/                    unit tests
├── hooks/
│   ├── pre-commit            branch guard, content checks, lint, tests
│   └── commit-msg            Conventional Commits check
├── scripts/
│   ├── simulate_gitflow.sh   the full lifecycle simulation
│   ├── install_hooks.sh      enable the hooks
│   └── bump_version.py       bump __version__ + roll CHANGELOG
├── docs/
│   ├── GITFLOW_CHEATSHEET.md command reference
│   └── BRANCH_PROTECTION.md  GitHub settings
└── .github/
    ├── workflows/ci.yml · release.yml
    └── pull_request_template.md
```

## Troubleshooting
| Problem | Fix |
|---|---|
| `Permission denied` on hooks (Linux/macOS) | `bash scripts/install_hooks.sh` (does `chmod +x`) |
| `\r': command not found` on Windows | CRLF line endings — `.gitattributes` fixes new clones; otherwise run `git config core.autocrlf input` and re-checkout |
| Hook says "direct commits to 'develop' are blocked" while resolving a merge conflict | `GITFLOW_ALLOW_PROTECTED=1 git commit` |
| `git init -b` unknown option | Update Git to 2.28+ |
| Release workflow fails "Tag ≠ app.__version__" | You tagged before bumping the version — delete the tag, fix, re-tag |

## Extension ideas
1. Add a **merge conflict**: change the same line on `feature/a` and `feature/b`, then resolve it.
2. Add a `bugfix/*` PR into an open `release/*` branch.
3. Add a `pre-push` hook that refuses pushes to `main` from your machine.
4. Publish a package or Docker image from `release.yml`.
5. Add `CODEOWNERS` so reviews are auto-requested.
6. Replace `bump_version.py --note` with notes generated from `git log --pretty=%s`.
