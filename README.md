### terminal-randomizer

**terminal-randomizer** is a small PowerShell utility that randomly applies a monospaced font and a color scheme to a specified Windows Terminal profile, then launches that profile. It supports both Store and non‑Store Windows Terminal installs, performs atomic writes to **settings.json**, and provides a machine‑readable **-DryRun** mode for CI or automation.

&nbsp;

### Features

- **Robust settings detection** for multiple Windows Terminal install locations  
- **Atomic writes** to avoid corrupting **settings.json**  
- **Font whitelist support** and fallback monospace detection  
- **DryRun JSON output** for safe previews and automation  
- **Optional backup and logging** with timestamped backups and log file support

&nbsp;

### Installation

1. Clone or download the repository into your projects folder.  
2. Ensure **PowerShell 7+** or Windows PowerShell with **System.Drawing** available.  
3. (Optional) Place a font whitelist at `config/fonts.json` (JSON array of font names) or pass a custom path with `-FontWhitelist`.

&nbsp;

### Usage

**Basic preview (no changes):**

```powershell
.\scripts\randomize.ps1 -Profile "PowerShell" -DryRun
```

**Apply changes and launch profile:**

```powershell
.\scripts\randomize.ps1 -Profile "PowerShell"
```

**Common options**

- **`-Profile <name>`** — **Required.** Exact profile name from **settings.json**.  
- **`-FontWhitelist <path>`** — Path to a JSON array of preferred fonts.  
- **`-DryRun`** — Print a JSON summary and do not modify **settings.json**.  
- **`-NoBackup`** — Skip creating a timestamped backup of **settings.json**.  
- **`-LogFile <path>`** — Append a timestamped log entry to the given file.

&nbsp;

### Triggering the randomizer on profile start

This project supports two practical ways to run `randomize.ps1` automatically when a Windows Terminal profile opens. Include one of these approaches in your profile **Command line** so visitors can enable the randomizer on startup.

#### Direct commandline method

**Description**  
Run PowerShell to invoke `randomize.ps1` and keep the shell open. This is the simplest and most transparent approach.

**Windows PowerShell example**

```json
"commandline": "powershell.exe -NoExit -ExecutionPolicy Bypass -Command \"& 'C:\\absolute\\path\\to\\terminal-randomizer\\scripts\\randomize.ps1' -Profile 'PowerShell' -LogFile 'C:\\Users\\you\\AppData\\Local\\terminal-randomizer\\randomize.log'\""
```

**PowerShell 7 example**

```json
"commandline": "C:\\Program Files\\PowerShell\\7\\pwsh.exe -NoExit -ExecutionPolicy Bypass -Command \"& 'C:\\absolute\\path\\to\\terminal-randomizer\\scripts\\randomize.ps1' -Profile 'PowerShell' -LogFile 'C:\\Users\\you\\AppData\\Local\\terminal-randomizer\\randomize.log'\""
```

**How to apply**

1. Open Windows Terminal → **Settings** → select the profile (for example PowerShell).  
2. Paste the appropriate `commandline` string into the **Command line** field.  
3. Save settings and open the profile to test.

**Why this works**

- **`-NoExit`** keeps the shell open after the script runs.  
- **`-ExecutionPolicy Bypass`** avoids policy blocks for one invocation.  
- The `& 'path'` form ensures PowerShell runs the script file path correctly.

#### VBScript wrapper method

**Description**  
Use a small `.vbs` wrapper when you want to control window visibility or perform extra orchestration before launching the interactive shell.

**Sample `launch_randomizer.vbs`**

```vbscript
Set WshShell = CreateObject("WScript.Shell")
psPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
scriptPath = "C:\absolute\path\to\terminal-randomizer\scripts\randomize.ps1"
cmd = """" & psPath & """ -NoExit -ExecutionPolicy Bypass -Command ""& '" & scriptPath & "' -Profile 'PowerShell' -LogFile 'C:\\Users\\you\\AppData\\Local\\terminal-randomizer\\randomize.log'"""
WshShell.Run cmd, 1, false
```

**Hidden invocation**  
Change the `1` to `0` in `WshShell.Run` to hide the PowerShell window (not recommended for debugging).

**Profile commandline to run the wrapper**

```json
"commandline": "wscript.exe \"C:\\absolute\\path\\to\\terminal-randomizer\\launch_randomizer.vbs\""
```

#### Example settings.json profile snippet

```json
{
  "guid": "{...}",
  "name": "PowerShell",
  "commandline": "powershell.exe -NoExit -ExecutionPolicy Bypass -Command \"& 'C:\\absolute\\path\\to\\terminal-randomizer\\scripts\\randomize.ps1' -Profile 'PowerShell'\"",
  "hidden": false
}
```

**Note** Use absolute paths and escape inner quotes when editing **settings.json** directly.

&nbsp;

### Best practices and troubleshooting

**Always test with DryRun first**

```powershell
.\scripts\randomize.ps1 -Profile "PowerShell" -DryRun
```

**Recommended practices**

- Use **absolute paths** for scripts and wrappers.  
- Keep **`-NoExit`** so the shell remains interactive after the script runs.  
- Use **`-ExecutionPolicy Bypass`** only for local trusted scripts. Consider signing scripts for stricter environments.  
- Add **`-LogFile`** to capture persistent logs for debugging.  
- Avoid long-running tasks in the script to keep profile startup snappy.

**Common issues**

- **Script not executed** — copy the `commandline` string and run it manually in PowerShell to see errors.  
- **Terminal closes immediately** — ensure `-NoExit` is present.  
- **Permission denied writing settings.json** — check file permissions and whether Terminal is running elevated.  
- **Quotes or escaping issues** — escape inner quotes with `\"` when editing JSON.  
- **Hidden wrapper shows nothing** — run without hidden mode to capture errors or check the log file.

&nbsp;

## Related Tools and Integrations

Besides randomizing Windows Terminal fonts and color schemes, you may also enjoy combining this project with other customization tools:

### Oh‑My‑Posh

[Oh‑My‑Posh](https://ohmyposh.dev/) is a prompt theme engine for PowerShell, Bash, and other shells.  
You can randomize themes at shell startup with a simple script:

**PowerShell example**

```powershell
$random_theme = Get-Item -Path "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\*" |
    Select-Object -Property Name | Get-Random
$theme_path = Join-Path "$env:LOCALAPPDATA\Programs\oh-my-posh\themes" $random_theme.Name
oh-my-posh init pwsh --config $theme_path | Invoke-Expression
```

**Linux Bash example**

```bash
randompick=$(find ~/.cache/oh-my-posh/themes -name "*.omp.json" -print0 | shuf -zn1 | tr -d '\0')
eval "$(oh-my-posh init bash --config $randompick)"
```

This way, each new shell session starts with a different prompt theme.

### WindowsTerminalThemes.dev

[WindowsTerminalThemes.dev](https://windowsterminalthemes.dev/) hosts over **4000 color schemes** for Windows Terminal.  
You can browse, preview, and download complete theme collections to expand your randomizer’s pool of schemes.

&nbsp;

### Contributing and License

Contributions are welcome. Open an issue or submit a pull request with a clear description and tests where applicable.  
This project is licensed under the **MIT License** — see the `LICENSE` file for full text.

&nbsp;

### Documentation suggestion

**Short answer** — include the trigger instructions in the main README under a dedicated section (as above).  
**When to create a separate document** — if you plan to add many platform-specific examples, screenshots, or troubleshooting steps, create `USAGE.md` or `docs/triggering.md` and link to it from the README. For now, the README section above is concise and user-friendly for most visitors.

&nbsp;

### Quick commit example

```powershell
git add README.md scripts/randomize.ps1 LICENSE
git commit -m "docs: add profile trigger instructions and usage examples"
git push
```
