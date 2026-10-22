#!/usr/bin/env bash
# ============================================================================
#  Full Gitflow simulation (runs 100% locally, real git commands)
#
#  Usage:  bash scripts/simulate_gitflow.sh [sandbox_dir]
#
#  Creates a bare "origin" + a working clone in the sandbox, copies this project
#  into it, installs the hooks, then plays through:
#     hooks in action -> feature branches -> PRs -> release -> hotfix
# ============================================================================
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SANDBOX="${1:-${TMPDIR:-/tmp}/gitflow-sandbox}"
ORIGIN="$SANDBOX/origin.git"
WORK="$SANDBOX/work"

if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  CYAN=$'\033[36m'; YELLOW=$'\033[33m'; RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; CYAN=""; YELLOW=""; RESET=""
fi

PY="$(command -v python3 || command -v python)"
if "$PY" -c "import pytest" 2>/dev/null; then
  TESTCMD=("$PY" -m pytest -q)
else
  TESTCMD=("$PY" -m unittest discover -s tests -t .)
fi

PR=0
phase() { printf '\n%s%s══ %s ══%s\n' "$BOLD" "$YELLOW" "$*" "$RESET"; }
say()   { printf '%s▸ %s%s\n' "$CYAN" "$*" "$RESET"; }
run()   { printf '%s$ %s%s\n' "$DIM" "$*" "$RESET"; "$@"; }
expect_block() {
  local what="$1"; shift
  printf '%s$ %s%s\n' "$DIM" "$*" "$RESET"
  if "$@"; then
    printf '%s✖ expected this to be blocked, but it succeeded%s\n' "$RED" "$RESET"; exit 1
  fi
  printf '%s✔ blocked as expected: %s%s\n' "$GREEN" "$what" "$RESET"
}

# pr_merge <branch> <target> <title>  -> simulates open PR + CI + review + merge
pr_merge() {
  local branch="$1" target="$2" title="$3"
  PR=$((PR + 1))
  say "PR #$PR  $branch → $target   \"$title\""
  printf '%s# on GitHub: gh pr create --base %s --head %s --title "%s"%s\n' "$DIM" "$target" "$branch" "$title" "$RESET"
  run git push -q -u origin "$branch"
  say "CI would run lint + tests now. Running the tests locally instead:"
  "${TESTCMD[@]}" | tail -n 3
  say "Review approved → merge commit (--no-ff keeps the branch visible in history)"
  run git checkout -q "$target"
  run git merge --no-ff -q "$branch" -m "Merge pull request #$PR from $branch" -m "$title"
  run git push -q origin "$target"
}
drop_branch() {
  run git branch -d "$1"
  run git push -q origin --delete "$1"
}

# ---------------------------------------------------------------------------
phase "0. SETUP  (bare origin + working clone + hooks)"
rm -rf "$SANDBOX"; mkdir -p "$SANDBOX"
git init -q --bare -b main "$ORIGIN"
git init -q -b main "$WORK"
(cd "$PROJECT_ROOT" && tar --exclude=.git --exclude=__pycache__ --exclude=.pytest_cache \
   --exclude=sandbox -cf - .) | (cd "$WORK" && tar -xf -)
cd "$WORK"
git config user.name  "Dev Demo"
git config user.email "dev@example.com"
git remote add origin "$ORIGIN"
git add -A
git commit -q -m "chore: initial commit (v0.1.0)"      # hooks not installed yet
run git push -q -u origin main
run git checkout -q -b develop
run git push -q -u origin develop
run bash scripts/install_hooks.sh

# ---------------------------------------------------------------------------
phase "1. PRE-COMMIT HOOK: direct commits to develop are blocked"
echo "# scratch" >> README.md
git add README.md
expect_block "protected branch" git commit -m "docs: sneaky direct commit"
git reset -q --hard HEAD

# ---------------------------------------------------------------------------
phase "2. FEATURE BRANCH #1: feature/multiply"
run git checkout -q -b feature/multiply develop

say "Hook check: a leftover breakpoint() must not get committed"
echo "breakpoint()" > app/debug_tmp.py
git add app/debug_tmp.py
expect_block "debugger statement" git commit -m "feat: add debug helper"
git reset -q; rm -f app/debug_tmp.py

say "Implement multiply()"
cat >> app/calculator.py <<'EOF'


def multiply(a, b):
    """Return a * b."""
    return a * b
EOF
git add -A
say "Hook check: commit-msg enforces Conventional Commits"
expect_block "bad commit message" git commit -m "added multiply stuff"
run git commit -q -m "feat(calculator): add multiply()"

cat > tests/test_multiply.py <<'EOF'
import unittest

from app.calculator import multiply


class TestMultiply(unittest.TestCase):
    def test_multiply(self):
        self.assertEqual(multiply(3, 4), 12)

    def test_multiply_by_zero(self):
        self.assertEqual(multiply(5, 0), 0)
EOF
git add -A
run git commit -q -m "test(calculator): cover multiply()"
pr_merge feature/multiply develop "Add multiply()"
drop_branch feature/multiply

# ---------------------------------------------------------------------------
phase "3. FEATURE BRANCH #2: feature/divide  (ships with a latent bug!)"
run git checkout -q -b feature/divide develop
cat >> app/calculator.py <<'EOF'


def divide(a, b):
    """Return a / b."""
    return a / b
EOF
cat > tests/test_divide.py <<'EOF'
import unittest

from app.calculator import divide


class TestDivide(unittest.TestCase):
    def test_divide(self):
        self.assertEqual(divide(10, 4), 2.5)
EOF
git add -A
run git commit -q -m "feat(calculator): add divide()"
pr_merge feature/divide develop "Add divide()"
drop_branch feature/divide

# ---------------------------------------------------------------------------
phase "4. RELEASE: release/1.0.0 branches off develop"
run git checkout -q -b release/1.0.0 develop
run git push -q -u origin release/1.0.0

say "Meanwhile, develop keeps moving: feature/stats goes into the NEXT release"
run git checkout -q -b feature/stats develop
cat > app/stats.py <<'EOF'
"""Statistics helpers."""


def mean(values):
    """Return the arithmetic mean of a non-empty sequence."""
    values = list(values)
    if not values:
        raise ValueError("mean() requires at least one value")
    return sum(values) / len(values)
EOF
cat > tests/test_stats.py <<'EOF'
import unittest

from app.stats import mean


class TestStats(unittest.TestCase):
    def test_mean(self):
        self.assertEqual(mean([1, 2, 3]), 2)

    def test_mean_empty_raises(self):
        with self.assertRaises(ValueError):
            mean([])
EOF
git add -A
run git commit -q -m "feat(stats): add mean()"
pr_merge feature/stats develop "Add stats.mean()"
drop_branch feature/stats

say "On the release branch only stabilisation work is allowed (docs, bug fixes, version bump)"
run git checkout -q release/1.0.0
"$PY" - <<'PYEOF'
import pathlib
p = pathlib.Path("app/calculator.py")
old = '"""Tiny calculator used as the demo codebase for the Gitflow simulation."""'
p.write_text(p.read_text().replace(old, '"""Tiny calculator: add, subtract, multiply and divide."""'))
PYEOF
git add -A
run git commit -q -m "docs(calculator): describe public API in module docstring"
run "$PY" scripts/bump_version.py 1.0.0 --note "Add multiply()" --note "Add divide()" --note "Docs: module docstring"
git add -A
run git commit -q -m "chore(release): bump version to 1.0.0"

say "Finish the release: merge into main, tag, then back-merge into develop"
pr_merge release/1.0.0 main "Release 1.0.0"
run git tag -a v1.0.0 -m "Release 1.0.0"
run git push -q origin v1.0.0
printf '%s# on GitHub, pushing the tag triggers .github/workflows/release.yml%s\n' "$DIM" "$RESET"
pr_merge release/1.0.0 develop "Back-merge release 1.0.0"
drop_branch release/1.0.0

# ---------------------------------------------------------------------------
phase "5. HOTFIX: production bug in 1.0.0 -> hotfix/1.0.1 branches off MAIN"
say "Customer report: divide(1, 0) crashes with ZeroDivisionError. Fix must not wait for the next release."
run git checkout -q -b hotfix/1.0.1 main

say "Step 1 - reproduce with a failing test. The pre-commit hook refuses to commit red tests:"
cat > tests/test_divide.py <<'EOF'
import unittest

from app.calculator import divide


class TestDivide(unittest.TestCase):
    def test_divide(self):
        self.assertEqual(divide(10, 4), 2.5)

    def test_divide_by_zero_raises_value_error(self):
        with self.assertRaises(ValueError):
            divide(1, 0)
EOF
git add -A
expect_block "failing tests" git commit -m "test(calculator): reproduce divide-by-zero"

say "Step 2 - fix the code, then commit fix + test together"
"$PY" - <<'PYEOF'
import pathlib
p = pathlib.Path("app/calculator.py")
old = '    """Return a / b."""\n    return a / b\n'
new = ('    """Return a / b. Raises ValueError when b is zero."""\n'
       '    if b == 0:\n        raise ValueError("Cannot divide by zero")\n    return a / b\n')
assert old in p.read_text()
p.write_text(p.read_text().replace(old, new))
PYEOF
git add -A
run git commit -q -m "fix(calculator): raise ValueError when dividing by zero"
run "$PY" scripts/bump_version.py 1.0.1 --note "Fix: divide() raises ValueError instead of ZeroDivisionError"
git add -A
run git commit -q -m "chore(release): bump version to 1.0.1"

pr_merge hotfix/1.0.1 main "Hotfix 1.0.1"
run git tag -a v1.0.1 -m "Hotfix 1.0.1"
run git push -q origin v1.0.1
say "Hotfix must also land on develop (no release branch is open, so it goes there)"
pr_merge hotfix/1.0.1 develop "Back-merge hotfix 1.0.1"
drop_branch hotfix/1.0.1

# ---------------------------------------------------------------------------
phase "6. RESULT"
say "History graph (all branches):"
git log --graph --oneline --decorate --all
echo
say "Tags:";            git tag -n
say "Remote branches:"; git branch -r
echo
say "Version on each long-lived branch:"
for b in main develop; do
  printf '  %-8s %s\n' "$b" "$(git show "$b:app/__init__.py" | grep __version__)"
done
say "stats.py is on develop but NOT in the 1.0.x releases on main:"
git ls-tree --name-only main app/ | sed 's/^/  main:    /'
git ls-tree --name-only develop app/ | sed 's/^/  develop: /'
echo
run git checkout -q develop
"${TESTCMD[@]}" | tail -n 3
printf '\n%s%s✔ Simulation complete.%s Explore it:  cd %s && git log --graph --oneline --all\n' "$BOLD" "$GREEN" "$RESET" "$WORK"
