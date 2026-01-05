---
name: block-sops-decrypt
enabled: true
event: bash
pattern: sops\s+(-d|--decrypt)
action: block
---

🚫 **Blocked: SOPS decrypt to stdout**

**What was blocked:** `sops -d` or `sops --decrypt`

**Why:** Decrypting secrets to stdout exposes them in:

- Process list
- Shell history
- Terminal logs

**If you need this:** Ask the user to:

- Run the command manually
- Use `sops exec-env` to inject secrets without exposing them
