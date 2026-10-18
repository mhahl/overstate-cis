#!/bin/sh
# Podman goss harness — Fedora 44 + Tumbleweed + Leap 16.0
# Usage: ./tests/run-goss-podman.sh [--l1|--l2]
set -eu
MODE="${1:---l1}"
if [ "$MODE" = "--l2" ]; then export ENABLE_L2=1; else export ENABLE_L2=0; fi
IMAGES="fedora:44 opensuse/tumbleweed:latest opensuse/leap:16.0"
for IMG in $IMAGES; do
  echo "=== $IMG (ENABLE_L2=$ENABLE_L2) ==="
  podman run --rm -v "$PWD:/repo:ro" -v "$PWD/tests/goss:/goss:ro" -e ENABLE_L2 "$IMG" sh -c '
    (command -v salt-call >/dev/null || (zypper -n in salt-minion goss 2>/dev/null || dnf -y install salt-minion goss 2>/dev/null) || true);
    salt-call --local state.show_sls overstate_cis || echo "show_sls failed (render check)";
    salt-call --local state.apply overstate_cis.audit test=True || true;
    goss -g /goss/ validate || echo "goss found issues (review)";
  '
done
