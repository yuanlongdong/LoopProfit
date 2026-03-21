#!/usr/bin/env bash
set -euo pipefail

sudo apt-get update
sudo apt-get install -y \
  cmake \
  build-essential \
  ninja-build \
  qt6-base-dev \
  qt6-base-dev-tools \
  qt6-declarative-dev

echo "Qt6 build dependencies installed."
