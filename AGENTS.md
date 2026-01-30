# Agent Instructions

This project uses **bd** (beads) for issue tracking. Run `bd onboard` to get started.

## Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --status in_progress  # Claim work
bd close <id>         # Complete work
bd sync               # Sync with git
```

## Landing the Plane (Session Completion)

**When ending a work session**, you MUST complete ALL steps below. Work is NOT complete until `jj git push` succeeds.

**MANDATORY WORKFLOW:**

1. **File issues for remaining work** - Create issues for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **PUSH TO REMOTE** - This is MANDATORY:
   ```bash
   git pull --rebase
   bd sync
   git push
   git status  # MUST show "up to date with origin"
   ```
5. **Clean up** - Clear stashes, prune remote branches
6. **Verify** - All changes committed AND pushed
7. **Hand off** - Provide context for next session

**CRITICAL RULES:**
- Work is NOT complete until `git push` succeeds
- NEVER stop before pushing - that leaves work stranded locally
- NEVER say "ready to push when you are" - YOU must push
- If push fails, resolve and retry until it succeeds


# Claude Instructions for this Repository

## FIRST THING: Check Beads

Before doing any work, run:
```bash
cd ~/nix && bd ready
```

This shows standing reminders and open tasks. Do this EVERY session.

## Version Control: Use jj, NOT git

This repo uses **jj (jujutsu)** for version control. NEVER use git commands directly.

| Instead of | Use |
|------------|-----|
| `git status` | `jj status` |
| `git add` | (not needed, jj tracks automatically) |
| `git commit` | `jj commit` or `jj describe` |
| `git push` | `jj git push` |
| `git pull` | `jj git fetch` then `jj rebase` |
| `git log` | `jj log` |
| `git diff` | `jj diff` |

## NixOS Rebuilds

Use `nh` for NixOS operations:
```bash
nh os switch .
```

## Adding Reminders

To add persistent reminders for future sessions:
```bash
bd create "Your reminder" -p 0 --description "Details here"
```
