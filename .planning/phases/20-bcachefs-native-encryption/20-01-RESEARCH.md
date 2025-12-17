---
phase: 20-bcachefs-native-encryption
type: research
topic: Bcachefs native encryption with disko and boot unlock automation
---

<session_initialization>
Before beginning research, verify today's date:
!`date +%Y-%m-%d`

Use this date when searching for "current" or "latest" information.
Example: If today is 2025-12-17, search for "2025" not "2024".
</session_initialization>

<research_objective>
Research bcachefs native encryption implementation patterns to inform Phase 20 bcachefs native encryption layouts.

Purpose: Determine how to declaratively configure bcachefs ChaCha20/Poly1305 encryption in disko, implement automatic boot unlock (since systemd-cryptenroll doesn't support bcachefs), and integrate with Phase 17 password management infrastructure.

Scope: Disko configuration patterns, boot unlock mechanisms, passphrase management, comparison with LUKS approach

Output: FINDINGS.md with structured recommendations for implementation
</research_objective>

<research_scope>
<include>
- Disko bcachefs encryption configuration patterns (format options, encryption flags)
- Boot unlock mechanisms (bcachefs unlock, systemd units, initrd integration)
- Passphrase management (bcachefs set-passphrase, kernel keyring, /tmp/disko-password integration)
- ChaCha20/Poly1305 vs LUKS security model comparison
- Impermanence pattern with encrypted bcachefs (partition layouts)
- TPM integration possibilities (if bcachefs supports it)
- Recovery scenarios (passphrase reset, emergency access)
</include>

<exclude>
- LUKS implementation details (already completed in Phase 17)
- General disko usage patterns (already understood)
- Bcachefs performance tuning (separate concern)
- Multi-device bcachefs setups (RAID patterns)
</exclude>

<sources>
Official documentation (with exact URLs):
- https://bcachefs.org/Encryption/
- https://bcachefs-docs.readthedocs.io/en/latest/feat-encryption.html
- https://wiki.nixos.org/wiki/Bcachefs
- https://github.com/nix-community/disko (examples directory)
- https://github.com/nix-community/disko/blob/master/example/bcachefs.nix

Search queries for WebSearch:
- "disko bcachefs encryption configuration 2025"
- "bcachefs unlock boot systemd NixOS 2025"
- "bcachefs set-passphrase kernel keyring 2025"
- "bcachefs TPM unlock NixOS 2025"
- "bcachefs initrd unlock systemd-ask-password 2025"

WebFetch for deep documentation reading
Prefer current/recent sources (2025 documentation)
</sources>
</research_scope>

<verification_checklist>
**Configuration Options:**
□ Enumerate ALL bcachefs encryption format options:
  □ Encryption algorithm specification (ChaCha20/Poly1305)
  □ Passphrase vs keyfile options
  □ Disko-specific configuration syntax
  □ Format-time vs mount-time options
□ Document exact disko configuration syntax for encrypted bcachefs
□ Verify if disko supports declarative bcachefs encryption (check examples)
□ Check for NixOS-specific bcachefs encryption options

**Boot Unlock Mechanisms:**
□ Enumerate ALL boot unlock approaches:
  □ systemd-ask-password integration
  □ Custom initrd scripts
  □ systemd unit before mount
  □ bcachefs unlock command placement
□ Document exact systemd unit requirements
□ Verify initrd integration requirements
□ Check for plymouth password prompt integration

**Passphrase Management:**
□ bcachefs format --encrypt passphrase handling
□ bcachefs set-passphrase workflow
□ Kernel keyring integration patterns
□ /tmp/disko-password bootstrap compatibility
□ TPM unlock support and configuration

**For all research:**
□ Verify negative claims ("systemd-cryptenroll doesn't support bcachefs") with official sources
□ Confirm all primary claims have authoritative sources
□ Check both current docs AND recent updates/changelogs (2024-2025)
□ Test multiple search queries to avoid missing information
□ Check for NixOS-specific variations vs general Linux approaches
</verification_checklist>

<research_quality_assurance>
Before completing research, perform these checks:

<completeness_check>
- [ ] All encryption configuration options documented with evidence
- [ ] All boot unlock mechanisms documented with examples
- [ ] Official documentation cited for critical claims
- [ ] Contradictory information resolved or flagged
- [ ] NixOS-specific patterns identified vs general Linux patterns
</completeness_check>

<blind_spots_review>
Ask yourself: "What might I have missed?"
- [ ] Are there disko configuration options I didn't investigate?
- [ ] Did I check for NixOS-specific bcachefs options in nixpkgs?
- [ ] Did I verify claims that seem definitive ("cannot", "only", "must")?
- [ ] Did I look for recent bcachefs updates (6.7+ kernel changes)?
- [ ] Did I check for existing NixOS bcachefs encryption implementations?
</blind_spots_review>

<critical_claims_audit>
For any statement like "X is not possible" or "Y is the only way":
- [ ] Is this verified by official bcachefs documentation?
- [ ] Have I checked for recent updates to bcachefs or disko?
- [ ] Are there alternative approaches I haven't considered?
- [ ] Did I check the disko issue tracker for bcachefs encryption discussions?
</critical_claims_audit>
</research_quality_assurance>

<incremental_output>
**CRITICAL: Write findings incrementally to prevent token limit failures**

Instead of generating full FINDINGS.md at the end:
1. Create FINDINGS.md with structure skeleton
2. Write each finding as you discover it (append immediately)
3. Add code examples as found (append immediately)
4. Finalize summary and metadata at end

This ensures zero lost work if token limits are hit.

<workflow>
Step 1 - Initialize:
```bash
cat > .planning/phases/20-bcachefs-native-encryption/20-01-FINDINGS.md <<'EOF'
# Bcachefs Native Encryption Research Findings

## Summary
[Will complete at end]

## Recommendations
[Will complete at end]

## Key Findings

### Disko Configuration Patterns
[Append findings here as discovered]

### Boot Unlock Mechanisms
[Append findings here as discovered]

### Passphrase Management
[Append findings here as discovered]

### Security Model Comparison
[Append findings here as discovered]

## Code Examples
[Append examples here as found]

## Metadata
[Will complete at end]
EOF
```

Step 2 - Append findings as discovered:
After researching each aspect, immediately append to appropriate Key Findings section

Step 3 - Finalize at end:
Complete Summary, Recommendations, and Metadata sections
</workflow>
</incremental_output>

<output_structure>
Create `.planning/phases/20-bcachefs-native-encryption/20-01-FINDINGS.md`:

# Bcachefs Native Encryption Research Findings

## Summary
[2-3 paragraph executive summary covering: disko configuration patterns, boot unlock approach, passphrase management integration, security benefits vs LUKS]

## Recommendations

### Primary Recommendation
[Recommended approach for implementing bcachefs native encryption with disko]
- Disko configuration pattern
- Boot unlock mechanism
- Passphrase management integration
- Migration path from LUKS layouts

### Alternatives Considered
[Other approaches evaluated and why they were not selected]

## Key Findings

### Disko Configuration Patterns
- Finding with source URL
- Relevance to our implementation
- Disko-specific syntax requirements

### Boot Unlock Mechanisms
- Finding with source URL
- systemd integration approach
- initrd requirements

### Passphrase Management
- Finding with source URL
- Phase 17 infrastructure compatibility
- Bootstrap workflow

### Security Model Comparison
- ChaCha20/Poly1305 benefits
- Authenticated encryption advantages
- LUKS comparison and use cases

## Code Examples

### Disko Configuration Example
```nix
[Actual working disko configuration for encrypted bcachefs]
```

### Systemd Unlock Unit Example
```nix
[Actual working systemd unit for boot unlock]
```

### NixOS Configuration Integration
```nix
[How to integrate unlock automation in NixOS configuration]
```

## Metadata

<metadata>
<confidence level="high|medium|low">
[Why this confidence level - based on official docs, examples found, testing required]
</confidence>

<dependencies>
- Linux kernel 6.7+ (bcachefs mainline)
- bcachefs-tools package
- Disko version with bcachefs support
- NixOS initrd bcachefs support
</dependencies>

<open_questions>
- [What couldn't be determined from documentation]
- [What requires testing to verify]
</open_questions>

<assumptions>
- [What was assumed about disko behavior]
- [What was assumed about NixOS bcachefs support]
</assumptions>

<quality_report>
  <sources_consulted>
    [List URLs of official documentation and primary sources]
  </sources_consulted>
  <claims_verified>
    [Key findings verified with official sources]
  </claims_verified>
  <claims_assumed>
    [Findings based on inference or incomplete information]
  </claims_assumed>
  <confidence_by_finding>
    - Disko configuration: [High/Medium/Low] (reason)
    - Boot unlock: [High/Medium/Low] (reason)
    - Passphrase management: [High/Medium/Low] (reason)
    - Security comparison: [High/Medium/Low] (reason)
  </confidence_by_finding>
</quality_report>
</metadata>
</output_structure>

<success_criteria>
- All scope questions answered
- All verification checklist items completed
- Sources are current and authoritative (2024-2025 documentation)
- Clear primary recommendation with implementation approach
- Disko configuration pattern documented with examples
- Boot unlock mechanism documented with systemd units
- Passphrase management integration with Phase 17 defined
- Metadata captures uncertainties and testing requirements
- Quality report distinguishes verified from assumed
- Ready to inform 20-02-PLAN.md and 20-03-PLAN.md creation
</success_criteria>
