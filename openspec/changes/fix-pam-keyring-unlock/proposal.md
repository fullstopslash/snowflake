## Why

When logging into Hyprland via the `ly` display manager, KWallet is not automatically unlocked by PAM. This requires entering the password a second time to access secrets, breaking the expected flow where login credentials unlock the keyring. Additionally, `rbw` (Bitwarden CLI wrapper) has no automatic unlock mechanism, so even with KWallet unlocked, rbw remains locked until manually authenticated.

## What Changes

- Enable KWallet PAM integration for the `ly` display manager service (currently only configured for `login`, `sddm`, `sddm-greeter`)
- Create a new systemd user service that automatically unlocks `rbw` at session startup using the master password stored in KWallet
- Store the rbw master password in KWallet (one-time setup step)

## Capabilities

### New Capabilities

- `rbw-autounlock`: Automatic unlocking of rbw vault at Hyprland session startup, retrieving the master password from KWallet

### Modified Capabilities

None - this change adds new PAM configuration and a new service without modifying existing spec-level behavior.

## Impact

- **Files modified**: `roles/hyprland.nix` (PAM service config), `roles/bitwarden-automation.nix` (new rbw-autounlock service)
- **Dependencies**: Requires `kwallet-query` or equivalent for password retrieval from KWallet
- **User action required**: One-time setup to store rbw master password in KWallet
- **Systems affected**: Login flow, secrets access for any service depending on rbw
