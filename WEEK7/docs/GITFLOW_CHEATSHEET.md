# Gitflow command cheat-sheet

## Feature
```bash
git checkout develop && git pull
git checkout -b feature/my-feature
# ...work, commit (hooks run automatically)...
git push -u origin feature/my-feature
gh pr create --base develop --title "Add my feature"
# after approval:  merge on GitHub (merge commit), then
git checkout develop && git pull && git branch -d feature/my-feature
```

## Release
```bash
git checkout develop && git pull
git checkout -b release/1.2.0 && git push -u origin release/1.2.0
# only stabilisation commits here (bugfix/*, docs)
python scripts/bump_version.py 1.2.0 --note "Add X" --note "Fix Y"
git commit -am "chore(release): bump version to 1.2.0"
gh pr create --base main    --head release/1.2.0 --title "Release 1.2.0"   # merge it, then:
git checkout main && git pull
git tag -a v1.2.0 -m "Release 1.2.0" && git push origin v1.2.0           # triggers release.yml
gh pr create --base develop --head release/1.2.0 --title "Back-merge 1.2.0"
```

## Hotfix
```bash
git checkout main && git pull
git checkout -b hotfix/1.2.1
# fix + test, commit
python scripts/bump_version.py 1.2.1 --note "Fix: ..."
git commit -am "chore(release): bump version to 1.2.1"
gh pr create --base main --title "Hotfix 1.2.1"       # merge, tag v1.2.1, push tag
gh pr create --base develop --title "Back-merge hotfix 1.2.1"
```
(If a release branch is open, back-merge the hotfix into `release/*` instead of `develop`.)

## Handy
```bash
git log --graph --oneline --decorate --all     # see the branch graph
git branch --merged develop                    # branches safe to delete
git commit --no-verify                         # skip hooks (emergencies only)
GITFLOW_ALLOW_PROTECTED=1 git commit ...       # allow commit on main/develop (e.g. merge-conflict fix)
SKIP_TESTS=1 git commit ...                    # skip tests in the pre-commit hook
```
