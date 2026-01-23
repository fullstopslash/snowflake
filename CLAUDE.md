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
