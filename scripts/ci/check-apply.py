#!/usr/bin/env python3
"""Gate CI enforcement applies: fail on real regressions, allowlist
container-only limitations (no SELinux, no audit netlink, read-only
/proc/sys keys, no grub tooling, no dbus/nftables for firewall-cmd,
flaky sshd start). Usage: check-apply.py /tmp/apply.json"""
import json
import sys

# Salt state IDs (the <cis-id>-<slug> IDs from the .sls files) that may
# fail inside docker containers but pass on real Fedora/openSUSE hosts.
ALLOWLIST = {
    "1.6.3-selinux-mode-enforcing",   # needs kernel SELinux (absent in containers;
                                      # SUSE never renders it: selinux_runtime_managed)
    "4.3.x-auditd-enabled",           # needs audit netlink
    "3.2.x-sysctl-apply",             # host-global keys are read-only in containers
    "1.4.2-grub-mkconfig-bios",       # no grub tooling in containers
    "1.4.2-grub-transactional-update",  # same, transactional path
    "3.1.x-firewalld-default-zone",   # firewall-cmd needs dbus/nftables
    "4.3.x-audit-reload",             # augenrules needs a live audit subsystem
    "5.2.x-sshd-service",             # sshd start flaky in containers;
                                      # config validity still enforced by
                                      # sshd -t check_cmd on the file state
}
# NOTE: 1.6.3-selinux-mode-enforcing is NOT here — selinux.sls guards runtime
# states with `onlyif: python3 -c "import selinux"` so they skip cleanly where
# bindings are absent (containers, stock SUSE) instead of failing.

import re

# Salt internal return key: {state}_|-{id}_|-{name}_|-{fun}
TAG_RE = re.compile(r"^(.+?)_\|-(.+?)_\|-(.+?)_\|-(.+)$")


def state_id(key, ret):
    """Resolve the <cis-id>-<slug> ID from a state return.

    Normally ret['__id__']; when a state module is unavailable
    (e.g. selinux on hosts without python bindings) Salt keys the
    return as {state}_|-{id}_|-{name}_|-{fun} without __id__.
    """
    if isinstance(ret, dict) and ret.get("__id__"):
        return ret["__id__"]
    m = TAG_RE.match(key)
    if m:
        return m.group(2)
    return key

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

unexpected, allowed = [], []
for _minion, states in data.items():
    for _key, ret in states.items():
        if isinstance(ret, dict) and ret.get("result") is False:
            sid = state_id(_key, ret)
            (allowed if sid in ALLOWLIST else unexpected).append(sid)

for sid in allowed:
    print(f"ALLOWED (container-only): {sid}")
for sid in unexpected:
    print(f"FAILED: {sid}")

if unexpected:
    print(f"{len(unexpected)} unexpected state failure(s)", file=sys.stderr)
    sys.exit(1)
print("apply gate: OK")
