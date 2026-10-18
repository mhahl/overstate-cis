# overstate_cis — CIS DIL v2.0.0 Salt formula (Fedora 44 + openSUSE Tumbleweed/Leap 16)

## Documentation

- `docs/user-guide.md` — operators: audit vs enforce, targeting, reading results, goss.
- `docs/admin-guide.md` — admins: file-roots setup, top file, pillar reference, OS specifics, migration runbook, rollback, troubleshooting.
- `docs/overstate-guide.md` — Overstate UI: keys/groups, Files sync, Pillar snapshots, Jobs audit→waves, conformity watched states, schedules, RBAC/CI, end-to-end checklist.

## Deployment order (CLI short version)
1. `salt-call --local state.show_sls overstate_cis` (render check)
2. `state.apply overstate_cis.audit test=True` (read-only report)
3. Set `overstate_cis:enforce: True`, `level: 1` → `state.apply overstate_cis`
4. Reboot only if bootloader/SELinux changed or legacy migration armed `/.autorelabel`
5. Level 2: set `level: 2` + per-flag opt-ins (`tmout_enable`, `umask_restrictive`, `usb_disable`, `audit_immutable`), re-apply
6. `goss -g tests/goss/ validate` (see tests/run-goss-podman.sh)

## Rollback
Every `file.managed`/`file.replace` uses `backup: minion` plus pre-change copies under
`/var/cache/salt/hardening-backup/<date>/`. Restore via `cp` from backup dir, then
`state.apply` with `enforce: False` to stop re-enforcement. Grub: restore `/etc/default/grub`
from backup, re-run `grub2-mkconfig`.

## Legacy AppArmor migration caveats
- Default off (`legacy_apparmor_migration: False`). Enable only for pre-Feb-2025 / Leap 15.x imports.
- Masks `apparmor`, strips `security=apparmor`, installs SELinux policy, touches `/.autorelabel`.
- Requires MANUAL reboot (never auto-reboots); expect long first boot (relabel).
- Running both LSMs simultaneously is unsupported — do not enable SELinux booleans until after relabel+reboot.
- Leap 16 may ship userspace without loaded policy — audit warns instead of failing until policy present.

## Risky controls (commented by default, WARNING headers in code)
- `nftables/firewalld drop` tightening — breaks Docker/k8s networking
- `usb-storage` blacklist — breaks installers/VMs
- `audit -e 2` immutable — needs reboot to modify
- `umask 027`, `TMOUT`, `IPv6 disable`, `wireless mask`, `Ctrl-Alt-Del mask` — break GUI/desktops/laptops
- World-writable/unowned/SUID auto-fix is intentionally report-only (audit.sls) — never auto-chmod overlays/volumes
- SELinux-confined services on freshly migrated hosts need relabel+reboot before enforcing

## Verification
- `salt-call --local state.show_sls overstate_cis.{init,packages,config,services,audit}`
- Podman: `tests/run-goss-podman.sh` (fedora:44, opensuse/tumbleweed:latest, opensuse/leap:16.0)
- Goss per-section files in `tests/goss/` map 1:1 to state IDs (`<cis-id>-<slug>`)
