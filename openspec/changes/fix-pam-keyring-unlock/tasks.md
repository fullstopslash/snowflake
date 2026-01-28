## 1. PAM Configuration

- [x] 1.1 Add `security.pam.services.ly.kwallet.enable = true` in `roles/hyprland.nix`
- [x] 1.2 Verify the PAM service name matches what ly actually uses (check `/etc/pam.d/` after rebuild)

## 2. rbw-autounlock Script

- [x] 2.1 Create `rbw-autounlock` shell script in `bitwarden-automation.nix` that:
  - Retrieves password from KWallet using `kwallet-query -f bitwarden -r rbw-master-password`
  - Pipes password to `rbw unlock`
  - Logs success or failure
- [x] 2.2 Add graceful handling: if password not found, log setup instructions and exit 0
- [x] 2.3 Include setup instructions in the log message showing the exact `kwallet-query -w` command

## 3. Systemd Service

- [x] 3.1 Create `rbw-autounlock` systemd user service in `bitwarden-automation.nix`
- [x] 3.2 Configure service ordering: `After=kwalletd.service`, `Before=rbw-sync.timer`
- [x] 3.3 Set `WantedBy=graphical-session.target`
- [x] 3.4 Set service type to `oneshot` with `RemainAfterExit=true`

## 4. Testing

- [x] 4.1 Rebuild NixOS configuration with `nh os switch .`
- [ ] 4.2 Store rbw password in KWallet: `echo 'password' | kwallet-query -f bitwarden -w rbw-master-password`
- [ ] 4.3 Log out and log back in via ly
- [ ] 4.4 Verify KWallet is unlocked without prompt: `kwallet-query -l`
- [ ] 4.5 Verify rbw is unlocked: `rbw unlocked` should return true
- [ ] 4.6 Verify rbw can retrieve secrets: `rbw get <some-entry>`
