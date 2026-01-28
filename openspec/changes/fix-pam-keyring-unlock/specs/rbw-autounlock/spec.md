## ADDED Requirements

### Requirement: PAM unlocks KWallet for ly display manager
The system SHALL configure PAM to automatically unlock KWallet when the user authenticates via the ly display manager.

#### Scenario: Login via ly unlocks KWallet
- **WHEN** user logs in through the ly display manager with correct credentials
- **THEN** KWallet is automatically unlocked without requiring a second password prompt

#### Scenario: KWallet available to user services after login
- **WHEN** user session starts after ly authentication
- **THEN** kwallet-query can retrieve stored secrets without prompting for password

### Requirement: rbw-autounlock service retrieves password from KWallet
The system SHALL provide a systemd user service that retrieves the rbw master password from KWallet and uses it to unlock the rbw vault.

#### Scenario: rbw unlocks automatically at session start
- **WHEN** graphical-session.target is reached AND rbw master password exists in KWallet
- **THEN** rbw vault is unlocked without user interaction

#### Scenario: Service runs after KWallet daemon is available
- **WHEN** rbw-autounlock service starts
- **THEN** it waits for kwalletd.service to be running before attempting password retrieval

#### Scenario: rbw-sync can access secrets after unlock
- **WHEN** rbw-autounlock completes successfully
- **THEN** rbw-sync timer can sync the vault without "vault locked" errors

### Requirement: Graceful handling when password not stored
The system SHALL handle the case where rbw master password is not yet stored in KWallet without blocking session startup.

#### Scenario: First-time user without stored password
- **WHEN** rbw-autounlock runs AND no password exists in KWallet entry `rbw-master-password`
- **THEN** service logs setup instructions and exits with success (exit code 0)

#### Scenario: Session startup not blocked
- **WHEN** password retrieval fails for any reason
- **THEN** the graphical session continues to start normally

### Requirement: KWallet entry naming convention
The system SHALL store the rbw master password in KWallet under a consistent, documented location.

#### Scenario: Password stored in expected location
- **WHEN** user stores their rbw password for automation
- **THEN** it is stored in KWallet folder `bitwarden` with entry name `rbw-master-password`

#### Scenario: Documentation matches implementation
- **WHEN** service logs setup instructions
- **THEN** the kwallet-query command shown uses folder `bitwarden` and entry `rbw-master-password`
