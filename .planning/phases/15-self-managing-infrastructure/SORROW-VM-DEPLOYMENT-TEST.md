# Sorrow VM Deployment Test Results

**Date:** 2025-12-16
**Test Type:** Fresh deployment from scratch with comprehensive verification
**Deployment Method:** nixos-anywhere via `just vm-fresh sorrow`

---

## Executive Summary

✅ **Deployment Success:** VM deployed and boots reliably in 7.5 minutes
⚠️ **Configuration Issues:** Multiple discrepancies between config and actual system
❌ **Headless Status:** Functionally headless but GUI packages present in closure
❌ **Critical Bug:** Deployed as "mitosis" instead of "sorrow"

---

## Deployment Metrics

| Metric | Value |
|--------|-------|
| **Total Time** | 462 seconds (7 min 42 sec) |
| **Start Time** | 2025-12-16 10:30:20 |
| **SSH Ready** | 2025-12-16 10:38:02 |
| **Total Packages** | 996 packages |
| **Running Services** | 13 services |
| **Enabled Services** | 72 unit files |

### Deployment Breakdown
- VM preparation and nixos-anywhere: ~7 minutes
- System reboot and SSH availability: ~30 seconds

---

## Critical Issues

### 1. Hostname Mismatch ❌
**Expected:** sorrow
**Actual:** mitosis

```bash
# Evidence
$ ssh -p 22223 root@127.0.0.1 hostname
mitosis

$ ssh -p 22223 root@127.0.0.1 "nix-store --query --requisites /run/current-system | grep nixos-system"
/nix/store/...-nixos-system-mitosis-25.05.20251128.9a7b80b
```

**Root Cause:** The nixos-anywhere deployment appears to have used a cached or incorrect configuration. The flake shows only `sorrow` as an available configuration, but the deployed system is `mitosis`.

**Impact:** Configuration validation and auto-upgrade features may fail due to hostname assumptions.

---

## Headless Verification

### Display Managers ✅
**Status:** NONE RUNNING

```bash
# Verified no display managers active
$ systemctl list-units --type=service --state=running | grep -E '(ly|gdm|sddm|lightdm|display-manager)'
# No results - GOOD
```

### GUI Packages ❌
**Status:** PRESENT BUT NOT RUNNING

The following GUI packages were found in the system closure:

1. `gsettings-desktop-schemas-48.0`
2. `wayland-1.23.1`
3. `gtk+3-3.24.49`
4. `gtk4-4.18.6`
5. `webkitgtk-2.50.2+abi=4.1`
6. `perl5.40.0-File-DesktopEntry-0.22`
7. `nixos-manual.desktop`

**Root Cause:** NetworkManager pulls in VPN plugins that depend on GTK:
- `NetworkManager-openvpn-1.12.0`
- `NetworkManager-vpnc-1.4.0`
- `NetworkManager-l2tp-gnome-1.20.20`
- `NetworkManager-openconnect-1.2.10`

**Impact:**
- Adds ~50-100MB of unnecessary GUI libraries
- Functionally still headless (no services run these)
- System is bloated beyond what's needed for a test VM

---

## Package Analysis

### Total Package Count: 996

This is relatively minimal for NixOS with networking, but includes unexpected GUI bloat.

### Tools-Core Status: INCOMPLETE

#### Present ✅
- git
- vim
- curl
- wget
- zsh

#### Missing ❌
- fzf
- tmux
- ripgrep (rg)
- bat
- eza
- jq
- yq

**Analysis:** The `tools-core` module from `apps.cli` is only partially applied. Basic tools are present but advanced CLI tools are missing.

---

## Service Analysis

### Running Services (13 total)

```
1. avahi-daemon.service        - Avahi mDNS/DNS-SD Stack
2. dbus.service                - D-Bus System Message Bus
3. getty@tty1.service          - Getty on tty1
4. NetworkManager.service      - Network Manager
5. nscd.service                - Name Service Cache Daemon
6. sshd.service               ✅ SSH Daemon
7. systemd-journald.service    - Journal Service
8. systemd-logind.service      - User Login Management
9. systemd-oomd.service        - Userspace OOM Killer
10. systemd-timesyncd.service  - Network Time Sync
11. systemd-udevd.service      - Device Event Manager
12. user@0.service             - User Manager for root
13. user@1000.service          - User Manager for rain (UID 1000)
```

**Assessment:** Very lean - only essential services running. No desktop or GUI services active.

### Networking Services

#### SSH ✅
- **Status:** Active and running
- **Port:** 22223 (forwarded)
- **Memory:** 8.8M
- **Authentication:** Publickey working correctly

#### Tailscale ❌
- **Status:** NOT INSTALLED
- **Expected:** Declared in config but not present
- **Config Reference:** Line 26 in `roles/form-vm-headless.nix`

**Critical Bug:** The config declares tailscale in networking services:
```nix
services = {
  networking = [
    "openssh"
    "ssh"
    "tailscale"  # ← Declared but not installed
  ];
};
```

And references it in validation checks:
```nix
# hosts/sorrow/default.nix:64
validationChecks = [
  "systemctl --quiet is-enabled tailscaled"  # ← This FAILS
];

# hosts/sorrow/default.nix:77
validateServices = [
  "tailscaled.service"  # ← This FAILS
];
```

**Impact:** Auto-upgrade validation will FAIL, causing rollbacks or preventing upgrades entirely.

---

## Configuration vs Reality

### Expected (from hosts/sorrow/default.nix)

```nix
roles = [
  "vmHeadless"
  "test"
];

modules = {
  apps = {
    cli = [ "tools-core" ];
  };
};

hostSpec = {
  hostName = "sorrow";  # ← Should be sorrow
  primaryUsername = "rain";
};
```

### Actual System

| Config Item | Expected | Actual | Status |
|-------------|----------|--------|--------|
| Hostname | sorrow | mitosis | ❌ FAIL |
| SSH | Enabled | ✅ Running | ✅ PASS |
| Tailscale | Enabled | ❌ Missing | ❌ FAIL |
| tools-core | Full set | Partial | ⚠️ PARTIAL |
| Display Manager | None | None | ✅ PASS |
| GUI Libraries | None | Present | ❌ FAIL |

---

## Verdict

### Is the VM Headless?

**Functionally:** YES ✅
- No display managers running
- No graphical services active
- Console-only access

**Technically:** NO ❌
- GUI libraries present in closure
- NetworkManager VPN GUI dependencies
- Desktop schemas and Wayland libraries included

### Is the VM Minimal?

**Running State:** YES ✅
- Only 13 running services (very lean)
- Minimal memory footprint
- Fast boot time

**Package Closure:** QUESTIONABLE ⚠️
- 996 packages is reasonable
- But includes 50-100MB of GUI bloat
- NetworkManager brings unnecessary dependencies

### Is the Configuration Correct?

**NO** ❌

Critical issues:
1. Wrong hostname (mitosis vs sorrow)
2. Missing tailscale despite config declaration
3. Auto-upgrade validation checks will fail
4. tools-core incomplete
5. GUI packages present despite headless role

---

## Recommendations

### 1. Fix Hostname Issue (Critical)

Investigate and fix why nixos-anywhere deployed "mitosis" instead of "sorrow":
- Check hostname derivation in flake
- Verify `hostSpec.hostName` is properly used
- Test with explicit hostname in nixos-anywhere call

### 2. Fix Tailscale Configuration (Critical)

Choose one:
- **Option A:** Actually enable tailscale service in the config
- **Option B:** Remove tailscale from validation checks (lines 64, 77 in hosts/sorrow/default.nix)

Current state will cause auto-upgrade failures.

### 3. Remove GUI Dependencies (High Priority)

Options:
- Replace NetworkManager with systemd-networkd for headless VMs
- Package NetworkManager without GUI/VPN plugins
- Override NetworkManager to exclude gnome/gtk dependencies

This would eliminate:
- GTK3, GTK4, WebKit from closure
- Wayland libraries
- Desktop schemas
- ~50-100MB of disk space

### 4. Complete tools-core (Medium Priority)

Verify and fix the tools-core module to include all expected packages:
- fzf, tmux, ripgrep, bat, eza, jq, yq

### 5. Test Auto-Upgrade

Before considering this VM production-ready:
- Fix tailscaled validation checks
- Test auto-upgrade with `just test-auto-upgrade sorrow`
- Verify golden generation pinning works
- Confirm rollback functionality

---

## Test Commands Used

```bash
# Package count
nix-store --query --requisites /run/current-system | wc -l

# GUI packages check
nix-store --query --requisites /run/current-system | grep -i -E '(xorg|wayland|hypr|desktop|gtk|qt|firefox|chrome)'

# Display managers check
systemctl list-units | grep -i -E '(ly|gdm|sddm|lightdm|display)'

# Enabled services
systemctl list-unit-files --state=enabled

# Running services
systemctl list-units --type=service --state=running

# Check tools
command -v git vim curl wget zsh fzf tmux ripgrep bat eza jq yq

# Check tailscale
systemctl status tailscaled.service
```

---

## Deployment Logs

Full deployment output showing:
- Age key generation and registration
- nix-secrets flake update
- nixos-anywhere deployment
- Disk formatting and partitioning
- System installation
- Reboot and SSH availability

Total process: Clean, automated, reproducible (modulo the hostname bug).

---

## Conclusion

The sorrow VM deployment infrastructure works well from an automation perspective - the deployment is fast, reliable, and reproducible. However, the actual system has significant configuration issues that prevent it from being truly minimal and headless.

**Priority fixes:**
1. Hostname deployment bug (critical)
2. Tailscale validation checks (critical - breaks auto-upgrade)
3. GUI package bloat from NetworkManager (high)
4. Incomplete tools-core (medium)

Once these are resolved, sorrow will be an excellent fast-testing headless VM for GitOps workflows.
