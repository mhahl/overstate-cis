# overstate_cis

CIS Distribution Independent Linux v2.0.0 hardening formula for Salt. Targets Fedora 44 and openSUSE Tumbleweed / Leap 16.0 on Salt 3008.

[![CI](https://github.com/mhahl/overstate-cis/actions/workflows/goss.yml/badge.svg)](https://github.com/mhahl/overstate-cis/actions/workflows/goss.yml)

## Status

| Item | Value |
|---|---|
| CIS baseline | Distribution Independent Linux v2.0.0 |
| Supported OS | Fedora 44, openSUSE Tumbleweed, openSUSE Leap 16.0 |
| Salt | 3008 |
| CI | Render gate plus 3-image x level 1/2 goss matrix (`.github/workflows/goss.yml`) |

## Overview

`overstate_cis` is the single entrypoint (`init.sls`). It includes `packages`, `config` (SELinux, bootloader, network, logging, access, accounts, maintenance), `services`, and `audit`. With `enforce: False` only `audit.sls` runs, and nothing is changed.

| Pillar | Default | Effect |
|---|---|---|
| `overstate_cis:enforce` | `False` | `False` = audit only. `True` = install packages, manage configs, mask services. |
| `overstate_cis:level` | `1` | `2` enables the level 2 blocks. Each still needs its own opt-in flag. |
| `overstate_cis:controls` | all `True` | Per-control toggles. Set any key to `False` to disable that control. |

Every state ID embeds its control (`1.6.1-selinux-enforcing-mode` in `selinux.sls`) plus a `# CIS x.y.z - Title` comment, so failures map 1:1 to `tests/goss/*.yaml`.

## Deployment

Setup, top-file integration, and the pillar reference are in `docs/admin-guide.md`. Operators start with `docs/user-guide.md`. Overstate UI paths are in `docs/overstate-guide.md`.

### 1. Render check

```sh
salt-call --local state.show_sls overstate_cis
```

### 2. Audit (read-only)

```sh
salt-call --local state.apply overstate_cis.audit test=True
```

### 3. Enforce level 1 on a canary

```sh
salt-call --local state.apply overstate_cis \
  pillar='{"overstate_cis": {"enforce": True, "level": 1}}'
```

Reboot only if the bootloader or SELinux changed, or if legacy migration armed `/.autorelabel`.

### 4. Enforce level 2

Level 2 requires explicit opt-ins:

```sh
salt-call --local state.apply overstate_cis \
  pillar='{"overstate_cis": {"enforce": True, "level": 2, \
    "tmout_enable": True, "umask_restrictive": True, \
    "usb_disable": True, "audit_immutable": True}}'
```

### 5. Verify

```sh
goss -g tests/goss/ validate
```

`tests/run-goss-podman.sh` runs the same checks against `fedora:44`, `opensuse/tumbleweed:latest`, and `opensuse/leap:16.0`.

Promote canary to wave to fleet only when goss is green and the job returns no unexpected changes.

## Targeting

Use grains, not a bare `*`, for the first run:

```sh
salt -C 'os:Fedora and not osrelease:44' state.apply overstate_cis.audit test=True
salt -C 'osfinger:openSUSE*Leap*16*' state.apply overstate_cis.audit test=True
salt -C 'osfinger:openSUSE*Tumbleweed*' state.apply overstate_cis.audit test=True
```

Useful grains on these minions: `os`, `osfinger`, `os_family` (`RedHat` on Fedora, `Suse` on openSUSE), `selinux:enforced`.

## Rollback

Every `file.managed` and `file.replace` uses `backup: minion` and writes pre-change copies to `/var/cache/salt/hardening-backup/<date>/`.

Restore a file, then re-apply with enforcement off so the change does not come back:

```sh
cp /var/cache/salt/hardening-backup/<date>/etc/ssh/sshd_config /etc/ssh/sshd_config
salt-call --local state.apply overstate_cis \
  pillar='{"overstate_cis": {"enforce": False}}'
```

For grub, restore `/etc/default/grub` from the backup and re-run `grub2-mkconfig`.

## Risky controls

These controls are commented out by default. Enable them only with the matching pillar flag, and only after testing.

| Control | Flag | Breaks |
|---|---|---|
| Strict firewalld/nftables drop | `firewalld_strict_drop` | Docker, Kubernetes networking |
| `usb-storage` blacklist | `usb_disable` | Installers, VMs |
| `audit -e 2` immutable | `audit_immutable` | Requires reboot to change |
| `umask 027` | `umask_restrictive` | GUI and desktop workflows |
| `TMOUT` | `tmout_enable` | Idle shells |
| IPv6 disable | `disable_ipv6` | Docker, Kubernetes networking |
| Wireless mask | `disable_wireless` (default `True`) | WiFi laptops |
| Ctrl-Alt-Del mask | `ctrlaltdel_disable` | Keyboard reboots at the console |

Every control has a per-control toggle. Set `overstate_cis:controls:<name>: False` in pillar to turn it off; all controls default to `True`. The full key list is in the `controls:` block of `pillar.example` and in `docs/admin-guide.md`. `examples/conflict-avoidance.sls` is a copy-paste reference with all 33 toggles and a conflict-avoidance example.

The world-writable, unowned, and SUID scans in `audit.sls` are report-only. The formula never auto-chmods overlay or volume mounts.

SELinux-confined services on freshly migrated hosts need relabel and reboot before enforcing.

## Legacy AppArmor migration

- Default off: `legacy_apparmor_migration: False`. Enable only for pre-February 2025 imports or Leap 15.x.
- Masks `apparmor`, strips `security=apparmor` from kernel params, installs the SELinux policy, touches `/.autorelabel`.
- Requires a manual reboot. The formula never auto-reboots; expect a long first boot for relabeling.
- Running both LSMs simultaneously is unsupported. Do not apply SELinux booleans until after relabel and reboot.
- Leap 16 may ship userspace without a loaded policy. `audit.sls` warns instead of failing until the policy is present.

## Continuous integration

`.github/workflows/goss.yml` runs on push to `main` and on pull requests.

1. Render gate: `state.show_sls` for every SLS on Salt 3008, plus YAML parsing of `pillar.example` and the goss files.
2. Matrix: 3 images (`fedora:44`, `opensuse/tumbleweed:latest`, `opensuse/leap:16.0`) x level 1 and 2 in privileged systemd containers.
3. Each job runs the audit dry-run, full enforcement gated by `scripts/ci/check-apply.py` (the allowlisted container-only states are documented there), and `goss validate` with `SKIP_KERNEL_CHECKS=1`. Live-kernel checks skip; file-content checks stay strict.

## Documentation

- `docs/user-guide.md`: operating the formula, reading results, common outcomes.
- `docs/admin-guide.md`: file-roots setup, top file, pillar reference, OS specifics, migration runbook, rollback, troubleshooting.
- `docs/overstate-guide.md`: Overstate UI keys and groups, Files sync, Pillar snapshots, Jobs audit-to-waves, conformity states, schedules, RBAC/CI, end-to-end checklist.
