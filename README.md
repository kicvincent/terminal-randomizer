Overview
terminal-randomizer is a small PowerShell utility that randomly applies a monospaced font and a color scheme to a specified Windows Terminal profile, then launches that profile. It supports both Store and non‑Store Windows Terminal installs, performs atomic writes to settings.json, and provides a machine‑readable -DryRun mode for CI or automation.

Features
Robust settings detection for multiple Windows Terminal install locations.

Atomic writes to avoid corrupting settings.json.

Font whitelist support and fallback monospace detection.

DryRun JSON output for safe previews and automation.

Optional backup and logging with timestamped backups and log file support.

Installation
Clone or download the repository into your projects folder.

Ensure PowerShell 7+ or Windows PowerShell with System.Drawing available.

Place optional font whitelist at config/fonts.json (JSON array of font names) or pass a custom path with -FontWhitelist.

Usage
Basic preview (no changes):

powershell
.\scripts\randomize.ps1 -Profile "PowerShell" -DryRun
Apply changes and launch profile:

powershell
.\scripts\randomize.ps1 -Profile "PowerShell"
Common options

-Profile <name> — Required. Exact profile name from settings.json.

-FontWhitelist <path> — Path to a JSON array of preferred fonts.

-DryRun — Print a JSON summary and do not modify settings.json.

-NoBackup — Skip creating a timestamped backup of settings.json.

-LogFile <path> — Append a timestamped log entry to the given file.

Sample DryRun output

json
{
  "Profile": "PowerShell",
  "Font": "FiraCode Nerd Font Mono",
  "Scheme": "LiquidCarbon",
  "SettingsPath": "C:\\Users\\you\\AppData\\Local\\Packages\\...\\LocalState\\settings.json",
  "Timestamp": "2026-03-29T19:28:59.4120280+08:00"
}
