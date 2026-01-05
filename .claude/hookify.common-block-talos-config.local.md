---
name: block-talos-config
enabled: true
event: file
action: block
conditions:
  - field: file_path
    operator: regex_match
    pattern: talos/clusterconfig/
---

🚫 **Blocked: Reading Talos cluster configuration**

**What was blocked:** Reading files in `talos/clusterconfig/`

**Why:** This directory contains machine secrets and sensitive cluster configuration.

**If you need this:** Ask the user to:

- Share specific non-sensitive configuration sections
- Describe what information you need instead
