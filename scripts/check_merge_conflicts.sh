#!/usr/bin/env bash
set -euo pipefail

# Canonical files that must be conflict-free before merge.
FILES=(
  "CMakeLists.txt"
  "README.md"
  "qml/Main.qml"
  "src/AppController.cpp"
  "src/AppController.h"
  "src/DatabaseManager.cpp"
  "src/DatabaseManager.h"
  "src/LoopEngine.cpp"
  "src/models.h"
  "tests/test_loopengine.cpp"
)

status=0

echo "== 1) Git index unmerged-entry check =="
if git ls-files -u | rg -n "." >/dev/null; then
  echo "[ERROR] repository has unresolved unmerged index entries:"
  git ls-files -u
  status=1
else
  echo "[OK] no unmerged index entries"
fi

echo "\n== 2) Conflict marker check in critical files =="
for f in "${FILES[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "[ERROR] missing file: $f"
    status=1
    continue
  fi

  if rg -n "^(<<<<<<<|=======|>>>>>>>)" "$f" >/dev/null; then
    echo "[ERROR] merge conflict markers found: $f"
    status=1
  else
    echo "[OK] no conflict markers: $f"
  fi
done

echo "\n== 3) Whitespace conflict lint (git diff --check) =="
if git diff --check -- . ':!build' | rg -n "." >/dev/null; then
  echo "[ERROR] git diff --check reported conflict-like whitespace issues:"
  git diff --check -- . ':!build'
  status=1
else
  echo "[OK] no whitespace conflict issues"
fi

exit $status
