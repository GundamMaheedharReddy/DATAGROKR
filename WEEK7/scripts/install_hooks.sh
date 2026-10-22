#!/usr/bin/env bash
# Point git at the version-controlled hooks/ directory (one-time setup per clone).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
git config core.hooksPath hooks
chmod +x hooks/* scripts/*.sh 2>/dev/null || true
echo "✔ Git hooks installed (core.hooksPath=hooks): pre-commit, commit-msg"
