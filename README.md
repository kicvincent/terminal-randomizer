# terminal-randomizer

**terminal-randomizer** is a small PowerShell utility that randomly applies a monospaced font and a color scheme to a specified Windows Terminal profile, then launches that profile. It supports both Store and non‑Store Windows Terminal installs, performs atomic writes to `settings.json`, and provides a machine‑readable `-DryRun` mode for CI or automation.

## Features

- **Robust settings detection** for multiple Windows Terminal install locations  
- **Atomic writes** to avoid corrupting `settings.json`  
- **Font whitelist support** and fallback monospace detection  
- **DryRun JSON output** for safe previews and automation  
- **Optional backup and logging** with timestamped backups and log file support

## Installation

1. Clone or download the repository into your projects folder.  
2. Ensure **PowerShell 7+** or Windows PowerShell with `System.Drawing` available.  
3. (Optional) Place a font whitelist at `config/fonts.json` (JSON array of font names) or pass a custom path with `-FontWhitelist`.

## Usage

**Basic preview (no changes):**
```powershell
.\scripts\randomize.ps1 -Profile "PowerShell" -DryRun
