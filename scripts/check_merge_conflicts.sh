#!/usr/bin/env bash
set -euo pipefail

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

exit $status
