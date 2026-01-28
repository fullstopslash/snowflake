z# Todo

## Project Overview
Create a comprehensive NixOS deployment system that enables single-command deployment with custom ISO generation, secure secret management via SOPS, and automated configuration deployment from a public git repository while keeping private keys separate for maximum security.

## Current State
- Basic NixOS configuration working
- SOPS integration implemented for secrets management
- Looking to achieve fully automated deployment capability

## Implementation Goals
1. Generate custom NixOS ISO with pre-configured settings
2. Maintain public git repository for configuration with encrypted secrets
3. Implement secure private key management separate from main configuration
4. Enable single-command deployment to new systems
5. Support remote deployments via SSH

## Action Plan

### Phase 1: Repository Structure & Foundation
- [ ] **Set up optimal repository structure**
  - [x] Create `flake.nix` with proper inputs and outputs
  - [x] Organize `hosts/` directory for different machine configurations
  - [x] Set up `modules/` for shared configuration components
  - [ ] Create `secrets/` directory with SOPS configuration
  - [x] Add `iso/` directory for custom installer configuration
  - [ ] Reference: [NixOS Flakes Guide](https://nixos.wiki/wiki/Flakes)

- [ ] **Configure SOPS integration properly**
  - [x] Set up `.sops.yaml` with public keys only
  - [x] Create encrypted `secrets.yaml` file structure
  - [x] Implement age key management strategy
  - [ ] Reference: [SOPS-nix documentation](https://github.com/Mic92/sops-nix)

### Phase 2: Custom ISO Generation
- [x] **Install and configure nixos-generators**
  - [x] Add nixos-generators to flake inputs
  - [x] Create custom ISO configuration in `iso/installer.nix`
  - [ ] Reference: [nixos-generators GitHub](https://github.com/nix-community/nixos-generators)

- [ ] **Configure custom ISO features**
  - [x] Include SSH server with authorized keys
  - [x] Add essential packages (git, curl, age, sops)
  - [ ] Create deployment script embedded in ISO
  - [x] Configure automatic network detection
  - [x] Add console/serial support for headless systems
  - [x] Enforce key-only SSH (no passwords) for public deployments

- [ ] **Create ISO build automation**
  - [x] Add flake output for ISO generation
  - [x] Create build script for different architectures
  - [x] Test ISO boot and connectivity

### Phase 3: Secret Management Architecture
- [ ] **Design private key storage strategy**
  - [ ] Choose between: USB drive, YubiKey, separate private repo, or remote key server
  - [ ] Implement key mounting/fetching mechanism
  - [ ] Create secure key backup strategy

- [ ] **Implement deployment-time secret handling**
  - [ ] Create script to mount/access private keys during deployment
  - [ ] Ensure keys are never stored in public repository
  - [ ] Implement proper cleanup after deployment

### Phase 4: Deployment Automation
- [ ] **Install and configure nixos-anywhere**
  - [x] Add to flake inputs and system packages
  - [ ] Configure for remote deployment scenarios
  - [ ] Reference: [nixos-anywhere documentation](https://github.com/nix-community/nixos-anywhere)

- [ ] **Create deployment scripts**
  - [ ] Local deployment script for ISO-based installation
  - [x] Remote deployment script using nixos-anywhere
  - [ ] Configuration validation before deployment
  - [ ] Post-deployment verification

### Phase 4.1: Testing Harness
- [x] Quickemu orchestration: build ISO → boot VM → boot smoke test → poweroff
- [x] Boot smoke test: assert sshd listening on forwarded port (no auth)
- [ ] Add nixos-anywhere `--vm-test` wrapper/script for CI
- [ ] Optional: CI job to run orchestrator and vm-test on PRs

- [ ] **Implement deploy-rs integration**
  - [ ] Add deploy-rs to flake configuration
  - [ ] Configure deployment profiles for different hosts
  - [ ] Set up rollback mechanisms
  - [ ] Reference: [deploy-rs GitHub](https://github.com/serokell/deploy-rs)

### Phase 5: Advanced Features & Testing
- [ ] **Add configuration validation**
  - [ ] Pre-deployment configuration checks
  - [ ] Automated testing of configurations
  - [ ] Integration with CI/CD if desired

- [ ] **Implement backup and recovery**
  - [ ] Automated SOPS key backup procedures
  - [ ] System configuration rollback mechanisms
  - [ ] Recovery procedures documentation

- [ ] **Multi-environment support**
  - [ ] Staging and production deployment targets
  - [ ] Environment-specific secret management
  - [ ] Configuration drift detection

## Technical Requirements

### Required Nix Packages
```nix
# Essential packages to include
pkgs.git
pkgs.curl
pkgs.age
pkgs.sops
pkgs.nixos-generators
pkgs.nh
pkgs.deploy-rs
```

### Partial Flake Structure Template
```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix.url = "github:Mic92/sops-nix";
    nixos-generators.url = "github:nix-community/nixos-generators";
    deploy-rs.url = "github:serokell/deploy-rs";
  };
  
  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations = {
      # Host configurations
    };
    
    packages.x86_64-linux = {
      # Custom ISO outputs
    };
    
    deploy.nodes = {
      # Deployment configurations
    };
  };
}
```

### Security Considerations
- Private age keys must never be committed to public repository
- Implement proper key rotation procedures
- Use hardware security modules when possible (YubiKey)
- Ensure encrypted secrets are properly configured in SOPS
- Validate that no secrets leak into Nix store paths

## Reference Documentation
- [NixOS Manual](https://nixos.org/manual/nixos/stable/)
- [Nix Flakes](https://nixos.wiki/wiki/Flakes)
- [SOPS-nix](https://github.com/Mic92/sops-nix)
- [nixos-generators](https://github.com/nix-community/nixos-generators)
- [nixos-anywhere](https://github.com/nix-community/nixos-anywhere)
- [deploy-rs](https://github.serokell/deploy-rs)
- [Age Encryption](https://age-encryption.org/)
- [Quickemu](https://github.com/quickemu-project/quickemu)

## Expected Deliverables
1. Fully configured flake-based NixOS repository
2. Custom ISO that can bootstrap system deployment
3. Automated deployment scripts for local and remote scenarios
4. All testable via quickemu.
5. Secure secret management implementation
6. Documentation for deployment procedures
7. Testing and validation procedures

## Success Criteria
- Single command can generate bootable ISO with embedded configuration
- New system can be fully deployed from ISO without manual configuration
- Secrets are properly encrypted and securely managed
- Remote deployments work via SSH
- Deployments can be made to a container that is brought up with quickemu
- Configuration can be updated and redeployed easily
- Private keys remain separate and secure throughout process
