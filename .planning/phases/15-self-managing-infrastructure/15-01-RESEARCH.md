---
phase: 15-self-managing-infrastructure
type: research
topic: NixOS Golden Boot Entries and Boot Validation
---

<session_initialization>
Before beginning research, verify today's date:
!`date +%Y-%m-%d`

Use this date when searching for "current" or "latest" information.
Example: If today is 2025-12-13, search for "2025" not "2024".
</session_initialization>

<research_objective>
Research NixOS golden boot entry systems and boot validation mechanisms to inform Phase 15-01 implementation.

Purpose: Design a safe golden boot entry system that:
- Pins known-good generations to survive garbage collection
- Validates boots quickly (not 24h uptime requirement)
- Detects boot failures and enables rollback
- Follows NixOS community best practices

Scope: NixOS-specific generation management, boot validation, systemd integration
Output: FINDINGS.md with structured recommendations for implementation
</research_objective>

<research_scope>
<include>
- **NixOS generation pinning methods**
  - How to create permanent GC roots for specific generations
  - Where to store pinned generations (gcroots structure)
  - Best practices for naming and organization

- **Boot success validation mechanisms**
  - systemd boot success detection (systemd-boot-check-no-failures.service)
  - systemd watchdog integration
  - Login success as validation signal
  - Time-based validation vs event-based validation
  - Boot completion markers

- **NixOS community implementations**
  - How NixOS servers handle failsafe generations
  - Examples from production deployments
  - Tools/modules from nixpkgs or community
  - Best practices from NixOS manual/wiki

- **Generation management**
  - Difference between system.activationScripts and systemd services
  - When to pin (boot success vs uptime vs manual)
  - How to unpin old golden generations
  - Impact on garbage collection

- **Rollback mechanisms**
  - systemd-boot menu integration
  - Automatic vs manual rollback triggers
  - How to detect "this boot failed" vs "previous boot failed"
</include>

<exclude>
- Non-NixOS boot management systems
- GRUB vs systemd-boot implementation details (we use systemd-boot)
- Full disaster recovery procedures
- Remote boot validation (only local for now)
</exclude>

<sources>
Official documentation (prioritize):
- https://nixos.org/manual/nixos/stable/
- https://nixos.wiki/
- https://github.com/NixOS/nixpkgs (search for boot, generation, pinning patterns)
- systemd documentation for boot success/watchdog

Search queries for WebSearch:
- "NixOS generation pinning best practices 2025"
- "NixOS boot success validation"
- "systemd-boot-check-no-failures NixOS"
- "NixOS automatic rollback boot failure"
- "NixOS golden generation gc root"
- "systemd boot watchdog NixOS"

Prefer current/recent sources (2024-2025)
</sources>
</research_scope>

<verification_checklist>
**For boot validation options:**
□ Document ALL methods NixOS uses to detect boot success:
  □ systemd boot success services
  □ Watchdog mechanisms
  □ User login detection
  □ Uptime thresholds
  □ Manual confirmation
□ Identify fastest reliable validation method
□ Check for existing NixOS modules or services for this

**For generation pinning:**
□ Verify exact commands/APIs for creating GC roots
□ Document standard gcroot locations in NixOS
□ Check if nixpkgs has existing utilities for this
□ Verify pinning survives nix-collect-garbage

**For rollback:**
□ Check how systemd-boot integrates with NixOS generations
□ Verify automatic rollback is possible (vs manual selection)
□ Document any existing NixOS options for this behavior
</verification_checklist>

<research_quality_assurance>
Before completing research, perform these checks:

<completeness_check>
- [ ] All boot validation methods documented with evidence
- [ ] Official NixOS documentation cited for generation management
- [ ] Community examples found and verified
- [ ] systemd integration patterns confirmed
</completeness_check>

<blind_spots_review>
Ask yourself: "What might I have missed?"
- [ ] Are there NixOS-specific utilities I haven't found?
- [ ] Did I check nixpkgs source code for existing patterns?
- [ ] Did I verify these patterns work with systemd-boot (not just GRUB)?
- [ ] Did I check for recent NixOS releases with relevant features?
</blind_spots_review>

<critical_claims_audit>
For statements like "fastest method is X" or "NixOS doesn't support Y":
- [ ] Verified by official documentation or nixpkgs source?
- [ ] Checked for recent updates in NixOS 23.11, 24.05, 24.11?
- [ ] Considered alternative approaches?
</critical_claims_audit>
</research_quality_assurance>

<incremental_output>
**CRITICAL: Write findings incrementally to prevent token limit failures**

Workflow:
```bash
# Step 1 - Create skeleton
cat > .planning/phases/15-self-managing-infrastructure/15-01-FINDINGS.md <<'EOF'
# NixOS Golden Boot Entries and Boot Validation - Research Findings

## Summary
[Will complete at end]

## Recommendations
[Will complete at end]

## Key Findings

### Generation Pinning Methods
[Append findings as discovered]

### Boot Validation Mechanisms
[Append findings as discovered]

### Community Implementations
[Append findings as discovered]

### Rollback Mechanisms
[Append findings as discovered]

## Code Examples
[Append examples as found]

## Metadata
[Will complete at end]
EOF
```

Step 2 - Append findings as discovered
Step 3 - Finalize Summary, Recommendations, and Metadata at end
</incremental_output>

<output_structure>
Create `.planning/phases/15-self-managing-infrastructure/15-01-FINDINGS.md`:

# NixOS Golden Boot Entries and Boot Validation - Research Findings

## Summary
[2-3 paragraph executive summary of research]

## Recommendations

### Primary Recommendation
[Recommended approach for golden boot entries and validation]

### Alternatives Considered
[Other approaches evaluated and why they weren't chosen]

## Key Findings

### Generation Pinning Methods
- How to create GC roots in NixOS
- Standard locations and naming
- nixpkgs utilities (if any)

### Boot Validation Mechanisms
- Fastest reliable method for detecting boot success
- systemd integration patterns
- Comparison of validation approaches

### Community Implementations
- Examples from production NixOS deployments
- Existing modules or tools
- Best practices from NixOS manual/wiki

### Rollback Mechanisms
- How to trigger automatic rollback
- systemd-boot integration
- Boot failure detection patterns

## Code Examples
[NixOS module snippets, systemd service examples, etc.]

## Metadata

<metadata>
<confidence level="high|medium|low">
[Why this confidence level]
</confidence>

<dependencies>
[What's needed to proceed with implementation]
</dependencies>

<open_questions>
[What couldn't be determined - may need user decision or testing]
</open_questions>

<assumptions>
[What was assumed during research]
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
    - Generation pinning: [High/Medium/Low] - [why]
    - Boot validation: [High/Medium/Low] - [why]
    - Rollback mechanisms: [High/Medium/Low] - [why]
  </confidence_by_finding>
</quality_report>
</metadata>
</output_structure>

<success_criteria>
- All scope questions answered
- Clear recommendation for fastest reliable boot validation
- GC root creation method documented with examples
- systemd integration patterns identified
- Community best practices captured
- Ready to inform 15-01-PLAN.md creation
</success_criteria>
