# overstate_cis — admin guide

Deploying, configuring, upgrading, and removing the formula, plus
troubleshooting. Operators start with the [user guide](user-guide.md);
Overstate UI paths are in the [Overstate guide](overstate-guide.md).

## Requirements

- Minions: Fedora 44, openSUSE Tumbleweed, openSUSE Leap 16.0. Other
  OSes render but package/service names come from `map.jinja:1`
  (`os_family` RedHat/Suse) and are untested outside this matrix.
- Salt 3008 (master + minions). `selinux.mode/boolean` states require
  the SELinux execution module loadable on the target.
- File roots + pillar access on the master. No custom `_modules/`
  ship with this formula, so `saltutil.sync_all` is not required.
- ~100 MB free under `/var/cache/salt` for config backups.

## Setup

1. Place the formula on the master file roots as a top-level directory
   named `overstate_cis` (the SLS references
   `salt://overstate_cis/templates/…` and `overstate_cis/map.jinja`,
   so the directory name must match):

   ```sh
   cp -r overstate-cis /srv/salt/overstate_cis
   ```

   In the Overstate repo layout this is `salt-srv/salt/overstate_cis/`
   next to `salt-srv/salt/top.sls`, with pillar under `pillar/`.
2. Target it from the top file (compound-gated to the supported matrix):

   ```yaml
   base:
     'os:Fedora or osfinger:openSUSE*':
       - match: compound
       - overstate_cis
   ```

   The shipped `top.sls.snippet:1` shows the minimal `base: {'*':
   [overstate_cis]}` variant. `init.sls` is the only entrypoint —
   never target sub-SLS (`overstate_cis.selinux`, …) from top; they are
   included via `config.sls:1` to avoid orphans.
3. Add pillar (all keys optional; full list with defaults in
   `pillar.example:1`). Minimum useful production pillar:

   ```yaml
   overstate_cis:
     enforce: False   # flip True only for canary/fleet enforcement
     level: 1
   ```

4. Render-check, then audit, then enforce on a canary (see user guide).
   `init.sls` includes `packages`, `config`, `services` only when
   `enforce` is true; otherwise only `audit.sls` runs.

## Pillar reference

| Key | Default | Notes |
|---|---|---|
| `enforce` | `False` | Master switch. False = audit-only. |
| `level` | `1` | `2` enables L2 blocks (each still needs its flag). |
| `selinux_booleans` | `{}` | e.g. `{httpd_can_network_connect: 'on'}`. `persist: True`. |
| `legacy_apparmor_migration` | `False` | True only for pre-Feb-2025 / Leap 15.x imports. Manual reboot required. |
| `sshd_options` | `{}` | Merged over secure template defaults (`PermitRootLogin no`, …). |
| `sysctl` | `{}` | Extra keys merged over CIS base in `network.sls`. |
| `disable_ipv6` | `False` | True disables IPv6. Breaks Docker/k8s. |
| `disable_wireless` | `True` | Set False on WiFi laptops (masks `wpa_supplicant`). |
| `firewalld_default_zone` | `public` | Set via `firewall-cmd --set-default-zone`. |
| `pass_max_days/min_days/warn_age` | `365/1/7` | `login.defs` aging. |
| `pw_minlen` | `14` | `pwquality.conf` minimum length. |
| `faillock_deny/unlock_time` | `5/900` | `faillock.conf` lockout. |
| `tmout/tmout_enable` | `600/False` | L2 opt-in session timeout. |
| `umask_restrictive` | `False` | L2 opt-in `umask 027` in `/etc/profile`. |
| `usb_disable` | `False` | L2 opt-in `usb-storage` blacklist. |
| `audit_immutable` | `False` | L2 opt-in `-e 2` (needs reboot to change). |
| `audit_max_log_file_mb` | `50` | `auditd.conf` rotation size. |
| `audit_ww_files` | `True` | Toggle world-writable scan in audit. |
| `mask_services` | `[xinetd, avahi-daemon, cups, dhcpd, slpd]` | Extra services appended via pillar. Never AppArmor here. |
| `log_server` | `@localhost` | rsyslog forward target. |
| `lookup` | `{}` | OS-map overrides merged in `map.jinja`. Rarely needed. |

Goss L2 flags are environment, not pillar: `ENABLE_L2=1`.

## OS specifics

- **Fedora:** native SELinux enforcing/targeted. Packages
  `policycoreutils`, `policycoreutils-python-utils`,
  `selinux-policy-targeted`, `openssh-server`, `audit`. GPG via
  `/etc/dnf/dnf.conf` `gpgcheck=1`. Grub EFI path
  `/boot/efi/EFI/fedora/grub.cfg`.
- **openSUSE Tumbleweed / Leap 16:** SELinux enforcing/targeted is the
  default for new installs since the Feb 2025 snapshots; legacy hosts
  keep AppArmor until migrated. Packages `policycoreutils`,
  `selinux-policy-targeted`, `openssh` (server+client in one),
  `audit`. No Fedora-equivalent `policycoreutils-python-utils` split —
  tooling ships inside Suse packaging; the formula does not install the
  Fedora split name on Suse. GPG via `/etc/zypp/zypp.conf`.
  Bootloader `grub2-mkconfig -o /boot/grub2/grub.cfg` for BIOS and EFI.
- **Transactional systems:** `bootloader.sls` detects
  `transactional-update` and wraps `grub2-mkconfig` in
  `transactional-update run`. Non-transactional hosts run it directly,
  `onchanges` from the grub file edit.
- **Leap 16 policy gap:** userspace may exist without a loaded targeted
  policy. The formula installs the policy package and sets enforcing,
  but `audit.sls` warns instead of failing until `sestatus` shows a
  loaded policy. Complete relabel + reboot before trusting booleans.

## Legacy migration runbook (AppArmor → SELinux)

Default off. Run only on hosts provisioned pre-switch or imported from
Leap 15.x, one canary first:

```sh
salt 'canary*' state.apply overstate_cis.legacy_migration \
  pillar='{"overstate_cis": {"legacy_apparmor_migration": True}}'
```

This masks `apparmor`, strips `security=apparmor` / `apparmor=1` from
`/etc/default/grub`, installs SELinux policy, touches `/.autorelabel`,
and posts a `reboot required` notification. It never reboots. Reboot
manually in a window; expect a long first boot (full relabel). Running
both LSMs simultaneously is unsupported — do not set SELinux booleans
until after relabel + reboot, then enforce normally.

## Firewall model

`firewalld` with the `nftables` backend, `firewalld.conf`
`FirewallBackend=nftables`, default zone from
`firewalld_default_zone` (default `public`). The formula never disables
firewalld and never touches the `docker` zone. Raw nftables/iptables
rule files are out of scope by decision (Q4). L2 drop-zone tightening
is a commented block requiring explicit enable.

## Rollback

Every `file.managed` / `file.replace` sets `backup: minion` and the
runbook copies originals under
`/var/cache/salt/hardening-backup/<date>/`. To roll back one file,
copy it back from the newest backup dir, then re-apply with
`enforce: False` so the formula stops re-enforcing it. For grub,
restore `/etc/default/grub` and re-run the matching `grub2-mkconfig`
command (or the `transactional-update` wrapper). There is no
`clean.sls` — removal is restore-from-backup plus pillar `enforce:
False`, because CIS hardening has no safe "uninstall".

## Troubleshooting

- `state.show_sls` fails: Jinja/pillar error. Check `pillar.items`
  `overstate_cis` shape against `pillar.example`; `lookup` must be a
  dict, `selinux_booleans` a dict, `mask_services` a list.
- `selinux.mode` fails: SELinux exec module not loadable (container
  without SELinux, or policy missing on Leap). File checks in goss
  still validate `/etc/selinux/config` content.
- `firewall-cmd` fails in `unless`/`onlyif`: firewalld not running in
  containers or minimal images. Goss file-content checks still apply;
  start firewalld on real hosts before enforcing.
- `sshd -t -f` check fails the `sshd_config` state: a pillar
  `sshd_options` override introduced an invalid keyword. Revert the
  override; the backup in `/var/cache/salt/hardening-backup/` has the
  last good file.
- `augenrules --load` skipped: `/sbin/augenrules` missing (audit
  package not yet installed in the same run). Re-apply; the second run
  loads rules.
- Goss `ENABLE_L2` failures on L1 hosts: re-run without `ENABLE_L2=1`.
  L2 goss checks intentionally skip on L1.
