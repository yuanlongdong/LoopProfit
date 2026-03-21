#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="build-coverage"

cmake -S . -B "$BUILD_DIR" -G Ninja -DLOOPPROFIT_ENABLE_COVERAGE=ON
cmake --build "$BUILD_DIR" -j
ctest --test-dir "$BUILD_DIR" --output-on-failure

if ! command -v gcovr >/dev/null 2>&1; then
  echo "gcovr not found, install with: pip install gcovr"
  exit 1
fi

gcovr \
  -r . \
  --object-directory "$BUILD_DIR" \
  --filter 'src/' \
  --filter 'tests/' \
  --exclude 'src/AppController.cpp' \
  --exclude 'src/AppController.h' \
  --exclude 'src/main.cpp' \
  --exclude 'src/LoopEngine.h' \
  --exclude 'build-coverage/.*' \
  --exclude 'build/.*' \
  --exclude 'tests/.*moc' \
  --xml-pretty -o "$BUILD_DIR/coverage.xml" \
  --html-details -o "$BUILD_DIR/coverage.html" \
  --print-summary \
  --fail-under-line 80

echo "Coverage reports: $BUILD_DIR/coverage.xml and $BUILD_DIR/coverage.html"
