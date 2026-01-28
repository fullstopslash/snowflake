## Context

Currently, KWallet PAM integration is configured for `login`, `sddm`, and `sddm-greeter` services in `roles/hyprland.nix`. However, the system uses `ly` as the display manager (configured in `roles/greetd.nix`), which is not included in the PAM configuration. This means KWallet is not automatically unlocked when logging in via ly.

Additionally, while `bitwarden-cli` (`bw`) has an auto-unlock mechanism that retrieves the master password from KWallet, `rbw` (the Rust Bitwarden CLI wrapper) has no equivalent. The existing `rbw-sync` service only syncs if rbw is already unlocked—it doesn't perform the unlock itself.

## Goals / Non-Goals

**Goals:**
- KWallet automatically unlocks when logging in via the ly display manager
- rbw automatically unlocks at Hyprland session startup using credentials from KWallet
- Single login password entry grants access to all secrets (KWallet, bw, rbw)

**Non-Goals:**
- Changing the display manager from ly to something else
- Replacing KWallet with gnome-keyring or another keyring
- Modifying how `bw` (bitwarden-cli) authentication works
- Automatic initial setup of rbw master password in KWallet (one-time manual step)

## Decisions

### 1. Add `ly` to KWallet PAM services

**Decision:** Add `security.pam.services.ly.kwallet.enable = true` alongside existing sddm entries.

**Rationale:** This is the minimal change needed. The `kwallet-pam` package is already installed, and the PAM module is already configured for other services. Adding ly follows the same pattern.

**Alternatives considered:**
- Switch to sddm: Would work but changes the login experience unnecessarily
- Use gnome-keyring instead: Would require migrating all KWallet-dependent services

### 2. Create `rbw-autounlock` systemd user service

**Decision:** Add a new systemd user service in `bitwarden-automation.nix` that:
1. Waits for `graphical-session.target` (ensures KWallet is available)
2. Retrieves the rbw master password from KWallet using `kwallet-query`
3. Pipes it to `rbw unlock`

**Rationale:** Mirrors the existing `bitwarden-autologin` pattern. Uses the same KWallet folder (`bitwarden`) for consistency but with a distinct entry name (`rbw-master-password`).

**Alternatives considered:**
- Use the same password entry as bw: Risky if passwords differ; explicit separation is safer
- Use SOPS for rbw password: SOPS secrets require root; KWallet is user-accessible and already unlocked by PAM

### 3. Service ordering: after kwalletd, before rbw-sync

**Decision:** `rbw-autounlock` should:
- `After=` kwalletd.service (ensures KWallet daemon is running)
- `Before=` rbw-sync.timer (ensures rbw is unlocked before sync attempts)
- `WantedBy=` graphical-session.target

**Rationale:** Guarantees the unlock happens at the right time in the session startup sequence.

### 4. Fail gracefully if password not in KWallet

**Decision:** If `kwallet-query` returns empty, log a message with setup instructions and exit 0 (success). Don't block session startup.

**Rationale:** Matches the existing `bitwarden-autologin` behavior. First-time users need to store the password manually; subsequent logins work automatically.

## Risks / Trade-offs

**[Risk] Password stored in KWallet in cleartext** → KWallet itself is encrypted and only unlocked after PAM authentication. This is the standard approach for keyring-based secret storage.

**[Risk] rbw and bw passwords could diverge** → Using separate KWallet entries (`bitwarden-master-password` vs `rbw-master-password`) allows for this flexibility. Documentation should note they're typically the same.

**[Risk] ly PAM service name might not match** → Verify the actual PAM service name used by ly. It should be `ly` but could be `ly-dm` or similar. Test after implementation.

**[Trade-off] One-time manual setup required** → Users must run `kwallet-query -f bitwarden -w rbw-master-password` once. This is acceptable for security (never prompts for password in scripts).
