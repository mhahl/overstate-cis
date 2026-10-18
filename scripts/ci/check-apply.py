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
    "1.6.3-selinux-mode-enforcing",   # needs SELinux in the kernel
    "4.3.x-auditd-enabled",           # needs audit netlink
    "3.2.x-sysctl-apply",             # host-global keys are read-only in containers
    "1.4.2-grub-mkconfig-bios",       # no grub tooling in containers
    "1.4.2-grub-transactional-update",  # same, transactional path
    "3.1.x-firewalld-default-zone",   # firewall-cmd needs dbus/nftables
    "5.2.x-sshd-service",             # sshd start flaky in containers;
                                      # config validity still enforced by
                                      # sshd -t check_cmd on the file state
}

path = sys.argv[1]
with open(path) as f:
    data = json.load(f)

unexpected, allowed = [], []
for _minion, states in data.items():
    for _key, ret in states.items():
        if ret.get("result") is False:
            sid = ret.get("__id__", _key)
            (allowed if sid in ALLOWLIST else unexpected).append(sid)

for sid in allowed:
    print(f"ALLOWED (container-only): {sid}")
for sid in unexpected:
    print(f"FAILED: {sid}")

if unexpected:
    print(f"{len(unexpected)} unexpected state failure(s)", file=sys.stderr)
    sys.exit(1)
print("apply gate: OK")
