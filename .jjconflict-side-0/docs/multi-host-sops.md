# Multi-Host SOPS Deployment Guide

This guide explains how to deploy SOPS secrets management across multiple hosts in your NixOS configuration.

## **The Challenge**

When setting up a new host, you face a **chicken-and-egg problem**:
- You need the age public key to encrypt secrets
- You need secrets to configure the new host
- The new host doesn't have your age keys yet

## **Solution Strategies**

### **Strategy 1: Pre-encrypted Secrets (Recommended)**

**Workflow:**
1. **On your main development machine** (with age keys):
   - Create and encrypt all secrets for new hosts
   - Commit encrypted secrets to repository
   - Deploy to new hosts

2. **On new hosts**:
   - Clone repository with pre-encrypted secrets
   - Import age private key
   - Build and deploy

#### **Step 1: Export Your Age Public Key**

```bash
# On your main development machine
./scripts/host-init.sh export-key
```

This outputs your age public key:
```
age1sut4v7ers2hc8du0quar20ld99xece2z6fwhsdwp60q47ym5gysqq3crqh
```

#### **Step 2: Create New Host Setup**

```bash
# Create complete setup for new host
./scripts/host-init.sh setup-new-host laptop
```

This creates:
- `hosts/laptop/.sops.yaml` - SOPS configuration
- `hosts/laptop/secrets.yaml` - Host-specific secrets template

#### **Step 3: Edit and Encrypt Secrets**

```bash
# Edit host-specific secrets
sops hosts/laptop/secrets.yaml

# Encrypt the file
sops -e -i hosts/laptop/secrets.yaml
```

#### **Step 4: Create Host Configuration**

Create `hosts/laptop/default.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware.nix
    ../../roles/desktop.nix
    ../../roles/development.nix
    ../../roles/secrets.nix  # Important: include secrets role
  ];

  networking.hostName = "laptop";
  system.stateVersion = "24.11";
  
  # Host-specific settings...
}
```

#### **Step 5: Add Host to Registry**

Add to `hosts/default.nix`:

```nix
{
  laptop = import ./laptop { inherit config lib pkgs; };
}
```

#### **Step 6: Deploy to New Host**

**On the new host:**

1. **Clone repository:**
   ```bash
   git clone <your-repo> nix
   cd nix
   ```

2. **Import age private key:**
   ```bash
   # Copy your age private key to the new host
   mkdir -p ~/.config/sops/age/
   # Copy your keys.txt file to ~/.config/sops/age/keys.txt
   ```

3. **Build and deploy:**
   ```bash
   nh os switch --flake .#laptop
   ```

### **Strategy 2: Shared Age Key Distribution**

**For trusted environments** where you can securely distribute age keys:

1. **Generate a shared age key pair:**
   ```bash
   age-keygen -o shared-key.txt
   ```

2. **Distribute the private key** to all hosts securely

3. **Use the same public key** in all `.sops.yaml` files

### **Strategy 3: Host-Specific Keys**

**For maximum security** with separate keys per host:

1. **Generate host-specific keys** on each host
2. **Encrypt secrets** with multiple public keys
3. **Each host** can only decrypt its own secrets

## **Host-Specific vs Global Secrets**

### **Global Secrets (`secrets.yaml`)**
- Shared across all hosts
- API keys, database credentials
- Network configurations

### **Host-Specific Secrets (`hosts/<hostname>/secrets.yaml`)**
- Unique to each host
- Device IDs, host-specific credentials
- Local configurations

## **Best Practices**

### **1. Key Management**
- **Keep private keys secure** - Never commit them
- **Use different keys** for different environments
- **Rotate keys regularly** - Update encryption periodically

### **2. Secret Organization**
- **Global secrets** in root `secrets.yaml`
- **Host-specific secrets** in `hosts/<hostname>/secrets.yaml`
- **Clear structure** with comments and sections

### **3. Deployment Workflow**
- **Pre-encrypt everything** on development machine
- **Test configurations** before deployment
- **Use version control** for encrypted secrets

### **4. Security Considerations**
- **Never commit unencrypted secrets**
- **Use strong age keys** (256-bit)
- **Limit key distribution** to trusted hosts
- **Monitor for key compromise**

## **Troubleshooting**

### **Common Issues**

1. **"age: no identity found"**
   - Ensure age private key is in `~/.config/sops/age/keys.txt`
   - Check file permissions (should be 600)

2. **"sops: no rule found"**
   - Verify `.sops.yaml` configuration
   - Check file path regex patterns

3. **"failed to decrypt"**
   - Verify age public key matches private key
   - Check SOPS configuration syntax

### **Debugging Commands**

```bash
# Validate SOPS configuration
sops -d secrets.yaml

# Check age key
age-keygen -y ~/.config/sops/age/keys.txt

# Test encryption/decryption
echo "test" | sops -e /dev/stdin | sops -d /dev/stdin
```

## **Advanced Patterns**

### **Multi-Key Encryption**

Encrypt secrets with multiple public keys (for different hosts):

```yaml
# .sops.yaml
creation_rules:
  - path_regex: secrets\.yaml$
    age:
      - age1sut4v7ers2hc8du0quar20ld99xece2z6fwhsdwp60q47ym5gysqq3crqh  # Main key
      - age1ql3z7hjy54pw3hyww5ayyfg7zqgvc7w3j2elw8zmrj2kg5sfn9aqmcac8p  # Backup key
```

### **Environment-Specific Secrets**

```yaml
# secrets.yaml
environments:
  production:
    api_key: "prod_key_here"
  development:
    api_key: "dev_key_here"
```

### **Conditional Secret Loading**

In your NixOS configuration:

```nix
{ config, lib, pkgs, ... }:

let
  # Load host-specific secrets if they exist
  hostSecrets = if builtins.pathExists ./secrets.yaml
    then { sopsFile = ./secrets.yaml; }
    else {};
in
{
  # Apply host-specific secrets
  sops.secrets = hostSecrets;
}
```

## **Migration Guide**

### **From Single Host to Multi-Host**

1. **Export your current age public key**
2. **Create host-specific directories**
3. **Move host-specific secrets** to `hosts/<hostname>/secrets.yaml`
4. **Update SOPS configurations**
5. **Test on each host**

### **From Unencrypted to Encrypted**

1. **Backup current secrets**
2. **Create SOPS configuration**
3. **Encrypt existing secrets**
4. **Update NixOS configurations**
5. **Test thoroughly**

## **Conclusion**

The **pre-encrypted secrets approach** is recommended for most setups because it:
- ✅ **Simplifies deployment** - No key distribution needed
- ✅ **Maintains security** - All secrets encrypted
- ✅ **Works with CI/CD** - Can automate deployments
- ✅ **Scales well** - Easy to add new hosts

The key is to **prepare everything on your development machine** before deploying to new hosts. 