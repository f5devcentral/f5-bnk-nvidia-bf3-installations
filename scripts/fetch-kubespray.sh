#!/usr/bin/env bash
set -euo pipefail
KS_VERSION="$(cat .kubespray-version)"
DEST=".deps/kubespray"
REPO="https://github.com/kubernetes-sigs/kubespray.git"

if [[ -d "$DEST/.git" ]]; then
  echo "==> Updating Kubespray in $DEST to $KS_VERSION"
  git -C "$DEST" fetch --tags --depth 1 origin "$KS_VERSION"
  git -C "$DEST" checkout -f "$KS_VERSION"
else
  echo "==> Fetching Kubespray $KS_VERSION"
  mkdir -p .deps
  git clone --depth 1 --branch "$KS_VERSION" "$REPO" "$DEST"
fi
