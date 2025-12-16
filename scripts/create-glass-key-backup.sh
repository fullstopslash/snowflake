#!/usr/bin/env bash
# scripts/create-glass-key-backup.sh
# Creates offline backup bundle for disaster recovery
#
# This script creates a complete glass-key backup containing:
# - nix-config repository (full copy + git bundle)
# - nix-secrets repository (full copy + git bundle)
# - master-recovery-key.txt (age private key)
# - Recovery instructions
# - Verification checklist
# - Manifest with checksums
#
# Usage:
#   ./scripts/create-glass-key-backup.sh [backup_dir] [master_key_path]
#
# Arguments:
#   backup_dir       - Directory to create backup in (default: ~/glass-key-backup-YYYYMMDD)
#   master_key_path  - Path to master age key (default: ~/master-recovery-key.txt)
#
# Examples:
#   ./scripts/create-glass-key-backup.sh
#   ./scripts/create-glass-key-backup.sh /mnt/usb/backup-20251216
#   ./scripts/create-glass-key-backup.sh ~/backup ~/master-key.txt

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
error() {
	echo -e "${RED}ERROR: $1${NC}" >&2
}

success() {
	echo -e "${GREEN}✓ $1${NC}"
}

info() {
	echo -e "${BLUE}$1${NC}"
}

warn() {
	echo -e "${YELLOW}WARNING: $1${NC}"
}

# Configuration
BACKUP_DIR="${1:-$HOME/glass-key-backup-$(date +%Y%m%d)}"
MASTER_KEY="${2:-$HOME/master-recovery-key.txt}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GIT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
NIX_SECRETS_DIR="${NIX_SECRETS_DIR:-$(cd "$GIT_ROOT/../nix-secrets" 2>/dev/null && pwd || echo "")}"

# Validate prerequisites
validate_prerequisites() {
	info "Validating prerequisites..."

	# Check git
	if ! command -v git &>/dev/null; then
		error "git not found. Install with: nix-shell -p git"
		exit 1
	fi

	# Check nix-config repo
	if [ ! -d "$GIT_ROOT/.git" ]; then
		error "Not in a git repository. Run from nix-config directory."
		exit 1
	fi

	# Check nix-secrets repo
	if [ -z "$NIX_SECRETS_DIR" ] || [ ! -d "$NIX_SECRETS_DIR/.git" ]; then
		error "nix-secrets repository not found."
		error "Expected at: $GIT_ROOT/../nix-secrets"
		error "Set NIX_SECRETS_DIR environment variable if in different location."
		exit 1
	fi

	# Check master key (optional - warn if missing)
	if [ ! -f "$MASTER_KEY" ]; then
		warn "Master key not found at: $MASTER_KEY"
		warn "Backup will be created without master key."
		warn "You must manually copy master key to backup directory."
		MASTER_KEY=""
	fi

	success "Prerequisites validated"
}

# Create backup directory structure
create_backup_directory() {
	info "Creating backup directory: $BACKUP_DIR"

	if [ -d "$BACKUP_DIR" ]; then
		warn "Backup directory already exists: $BACKUP_DIR"
		read -p "Overwrite? (y/N) " -n 1 -r
		echo
		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			error "Backup cancelled by user"
			exit 1
		fi
		rm -rf "$BACKUP_DIR"
	fi

	mkdir -p "$BACKUP_DIR"
	success "Backup directory created"
}

# Backup nix-config repository
backup_nix_config() {
	info "Backing up nix-config repository..."

	# Copy repository
	cp -r "$GIT_ROOT" "$BACKUP_DIR/nix-config"

	# Create git bundle
	cd "$BACKUP_DIR/nix-config"
	git bundle create ../nix-config.bundle --all
	cd - >/dev/null

	# Get commit hash
	NIX_CONFIG_COMMIT=$(cd "$GIT_ROOT" && git rev-parse HEAD)

	success "nix-config backed up (commit: ${NIX_CONFIG_COMMIT:0:8})"
}

# Backup nix-secrets repository
backup_nix_secrets() {
	info "Backing up nix-secrets repository..."

	# Copy repository
	cp -r "$NIX_SECRETS_DIR" "$BACKUP_DIR/nix-secrets"

	# Create git bundle
	cd "$BACKUP_DIR/nix-secrets"
	git bundle create ../nix-secrets.bundle --all
	cd - >/dev/null

	# Get commit hash
	NIX_SECRETS_COMMIT=$(cd "$NIX_SECRETS_DIR" && git rev-parse HEAD)

	success "nix-secrets backed up (commit: ${NIX_SECRETS_COMMIT:0:8})"
}

# Copy master recovery key
copy_master_key() {
	if [ -n "$MASTER_KEY" ]; then
		info "Including master recovery key..."
		cp "$MASTER_KEY" "$BACKUP_DIR/master-recovery-key.txt"
		chmod 600 "$BACKUP_DIR/master-recovery-key.txt"
		success "Master key included"
	else
		warn "Skipping master key (not found)"
		echo "MASTER_KEY_MISSING" >"$BACKUP_DIR/MASTER_KEY_MISSING.txt"
		echo "You must manually copy the master recovery key to this backup!" >>"$BACKUP_DIR/MASTER_KEY_MISSING.txt"
	fi
}

# Create recovery instructions
create_recovery_instructions() {
	info "Creating recovery instructions..."

	cat >"$BACKUP_DIR/RECOVERY.md" <<'EOF'
# Glass-Key Disaster Recovery

This bundle contains everything needed to rebuild from total infrastructure loss.

## Contents

- `nix-config/` - Full configuration repository
- `nix-config.bundle` - Git bundle (works without GitHub)
- `nix-secrets/` - All encrypted secrets
- `nix-secrets.bundle` - Git bundle (works without GitHub)
- `master-recovery-key.txt` - Age key to decrypt all secrets
- `RECOVERY.md` - This file
- `VERIFICATION.md` - Verification checklist
- `MANIFEST.txt` - File list and checksums

## Quick Recovery Steps

### 1. Install Base NixOS

Boot NixOS installer USB and install minimal system:

```bash
# After installation, install required tools
nix-shell -p git age sops
```

### 2. Restore Repositories

Clone from git bundles (no GitHub needed):

```bash
# From this backup directory
git clone nix-config.bundle nix-config
git clone nix-secrets.bundle nix-secrets

# Verify clones
cd nix-config && git log -1
cd ../nix-secrets && git log -1
cd ..
```

Alternatively, clone from GitHub if available:

```bash
git clone https://github.com/[your-username]/nix-config
git clone https://github.com/[your-username]/nix-secrets
```

### 3. Decrypt Secrets with Master Key

```bash
# Set master key for SOPS
export SOPS_AGE_KEY_FILE=~/master-recovery-key.txt

# Copy master key from backup
cp master-recovery-key.txt ~/master-recovery-key.txt
chmod 600 ~/master-recovery-key.txt

# Test decryption
sops -d nix-secrets/sops/shared.yaml
# Should display decrypted YAML
```

### 4. Bootstrap First Host

```bash
cd nix-config

# Run bootstrap with master key available
sudo SOPS_AGE_KEY_FILE=~/master-recovery-key.txt \
  ./scripts/bootstrap-nixos.sh \
  -n [hostname] \
  -d /dev/sda \
  -k ~/.ssh/id_ed25519

# Bootstrap will:
# 1. Generate NEW host age key
# 2. Add to .sops.yaml
# 3. Rekey secrets (still encrypted for master)
# 4. Deploy system
```

### 5. Verify First Host

```bash
# Check secrets decrypted
sudo ls /run/secrets/

# Check services running
systemctl status

# Test SSH
ssh localhost
```

### 6. Rebuild Infrastructure

- Bootstrap remaining hosts using same procedure
- Each host gets new age key
- All secrets encrypted with master key
- Services come online incrementally

### 7. Update Glass-Key Backups

After recovery:

```bash
# New hosts = new .sops.yaml
cd nix-config
./scripts/create-glass-key-backup.sh

# Create fresh physical backups if master key changed
# Update paper/metal backups
# Store securely
```

## Detailed Documentation

For complete step-by-step recovery procedure, see:

```
nix-config/docs/disaster-recovery/total-recovery.md
```

## Recovery Time Estimates

- Base system: 2-4 hours
- First host: 4-8 hours
- All hosts (5): 2-3 days
- Full services: 5-7 days

## Dependencies

- Network access (for Nix packages)
- Glass-key backups accessible
- Hardware available
- Time to rebuild (not instant)

## Emergency Contacts

[Add your emergency contact information here]

## Last Updated

See MANIFEST.txt for backup creation date and git commits.
EOF

	success "Recovery instructions created"
}

# Create verification checklist
create_verification_checklist() {
	info "Creating verification checklist..."

	cat >"$BACKUP_DIR/VERIFICATION.md" <<'EOF'
# Glass-Key Backup Verification Checklist

## Before Storing

Verify backup integrity before storing:

- [ ] `nix-config/` repository copied
- [ ] `nix-secrets/` repository copied
- [ ] `nix-config.bundle` created
- [ ] `nix-secrets.bundle` created
- [ ] Git bundles verified: `git bundle verify *.bundle`
- [ ] Master key included: `master-recovery-key.txt`
- [ ] Recovery instructions present: `RECOVERY.md`
- [ ] Verification checklist present: `VERIFICATION.md` (this file)
- [ ] Manifest created: `MANIFEST.txt`
- [ ] All files readable and accessible
- [ ] Checksums verified: `sha256sum -c MANIFEST.txt`

## Test Recovery (Annually)

Perform full recovery test at least once per year:

- [ ] Boot test VM (clean environment)
- [ ] Install minimal NixOS
- [ ] Clone from git bundles: `git clone *.bundle`
- [ ] Decrypt test secret: `sops -d nix-secrets/sops/shared.yaml`
- [ ] Bootstrap test host: `./scripts/bootstrap-nixos.sh`
- [ ] Verify secrets accessible: `sudo ls /run/secrets/`
- [ ] Verify services start: `systemctl status`
- [ ] Document test results: `.planning/phases/17-physical-security/recovery-test-YYYY-MM-DD.md`

## Update Schedule

Maintain backup freshness:

- [ ] **Monthly**: Quick verification (checksums, bundle validity)
- [ ] **Quarterly**: Update USB backup with latest configs
- [ ] **Annually**: Full recovery test
- [ ] **After major changes**: Re-snapshot immediately
- [ ] **After key rotation**: Create new backups

## Storage Verification

Verify all backup locations:

- [ ] Home safe: Paper + USB backup accessible
- [ ] Off-site: Safety deposit box / trusted person backup accessible
- [ ] Storage locations documented offline
- [ ] Physical backups legible (no fading, corrosion)
- [ ] USB encryption tested (LUKS passphrase works)
- [ ] Geographic diversity (not all in same location)

## Security Verification

Verify security properties:

- [ ] Master key NEVER stored digitally (only physical backups)
- [ ] USB encrypted with LUKS
- [ ] Paper backups laminated (water resistant)
- [ ] All copies stored in secure locations (safe, safety deposit box)
- [ ] No digital copies of master key exist
- [ ] Backup locations documented offline only

## Emergency Preparedness

Verify recovery readiness:

- [ ] Know where ALL backups are located
- [ ] Have access to at least one backup location immediately
- [ ] Know USB LUKS passphrase (if different from disk passphrase)
- [ ] Recovery instructions readable without this documentation
- [ ] Emergency contact has backup copy (optional)
- [ ] Executor knows backup locations (estate planning)

## Checklist Completion

Date verified: _________________
Verified by: _________________
Next verification due: _________________ (1 year from now)
Next update due: _________________ (3 months from now)

## Notes

[Add any notes about issues found, remediations performed, etc.]
EOF

	success "Verification checklist created"
}

# Create manifest with checksums
create_manifest() {
	info "Creating manifest..."

	cat >"$BACKUP_DIR/MANIFEST.txt" <<EOF
Glass-Key Backup Manifest
═══════════════════════════════════════════════════════════════

Created: $(date)
Hostname: $(hostname)
User: $(whoami)
Backup Directory: $BACKUP_DIR

Git Commits
───────────────────────────────────────────────────────────────
nix-config:  $NIX_CONFIG_COMMIT
nix-secrets: $NIX_SECRETS_COMMIT

Contents
───────────────────────────────────────────────────────────────
EOF

	{
		# List files with sizes
		find "$BACKUP_DIR" -type f -exec ls -lh {} \; | awk '{printf "%-60s %10s\n", $9, $5}'

		echo ""
		echo "Checksums (SHA256)"
		echo "───────────────────────────────────────────────────────────────"
	} >>"$BACKUP_DIR/MANIFEST.txt"

	# Generate checksums
	cd "$BACKUP_DIR"
	find . -type f -not -name "MANIFEST.txt" -exec sha256sum {} \; >>MANIFEST.txt
	cd - >/dev/null

	success "Manifest created"
}

# Verify backup integrity
verify_backup() {
	info "Verifying backup integrity..."

	# Verify git bundles
	info "  Verifying nix-config.bundle..."
	if git bundle verify "$BACKUP_DIR/nix-config.bundle" >/dev/null 2>&1; then
		success "  nix-config.bundle is valid"
	else
		error "nix-config.bundle verification failed!"
		exit 1
	fi

	info "  Verifying nix-secrets.bundle..."
	if git bundle verify "$BACKUP_DIR/nix-secrets.bundle" >/dev/null 2>&1; then
		success "  nix-secrets.bundle is valid"
	else
		error "nix-secrets.bundle verification failed!"
		exit 1
	fi

	# Verify checksums
	info "  Verifying checksums..."
	cd "$BACKUP_DIR"
	if sha256sum -c MANIFEST.txt >/dev/null 2>&1; then
		success "  All checksums verified"
	else
		error "Checksum verification failed!"
		exit 1
	fi
	cd - >/dev/null

	success "Backup integrity verified"
}

# Print summary
print_summary() {
	echo ""
	echo "═══════════════════════════════════════════════════════════════"
	success "Glass-Key Backup Created Successfully"
	echo "═══════════════════════════════════════════════════════════════"
	echo ""
	info "Backup Location: $BACKUP_DIR"
	echo ""
	echo "Contents:"
	echo "  • nix-config repository + bundle"
	echo "  • nix-secrets repository + bundle"
	if [ -n "$MASTER_KEY" ]; then
		echo "  • master-recovery-key.txt (age private key)"
	else
		warn "  • MASTER KEY NOT INCLUDED - Manual copy required!"
	fi
	echo "  • RECOVERY.md (recovery instructions)"
	echo "  • VERIFICATION.md (verification checklist)"
	echo "  • MANIFEST.txt (file list and checksums)"
	echo ""
	echo "Next Steps:"
	echo "  1. Review VERIFICATION.md checklist"
	echo "  2. Copy to USB drive: cp -r $BACKUP_DIR /mnt/usb/"
	echo "  3. Encrypt USB with LUKS (see docs/disaster-recovery/glass-key-creation.md)"
	echo "  4. Verify checksums on USB: cd /mnt/usb/... && sha256sum -c MANIFEST.txt"
	echo "  5. Store USB securely offline (fireproof safe)"
	echo "  6. Update paper backups if master key changed"
	echo "  7. Test recovery procedure (docs/disaster-recovery/total-recovery.md)"
	echo ""
	warn "SECURITY REMINDER:"
	echo "  • This backup contains your master age key"
	echo "  • Can decrypt ALL secrets in your infrastructure"
	echo "  • Store in fireproof safe, never upload to cloud"
	echo "  • Never store all copies in same physical location"
	echo ""
	echo "═══════════════════════════════════════════════════════════════"
}

# Main execution
main() {
	echo "═══════════════════════════════════════════════════════════════"
	echo "           Glass-Key Backup Creation Script"
	echo "═══════════════════════════════════════════════════════════════"
	echo ""

	validate_prerequisites
	create_backup_directory
	backup_nix_config
	backup_nix_secrets
	copy_master_key
	create_recovery_instructions
	create_verification_checklist
	create_manifest
	verify_backup
	print_summary
}

# Run main function
main
