# 中文说明（Chinese）

&nbsp;

## 概述

**terminal-randomizer** 是一个小型 PowerShell 工具，用于随机为指定的 Windows Terminal 配置文件应用等宽字体和配色方案，然后启动该配置文件。支持 Store 与非 Store 安装，采用原子写入 `settings.json`，并提供适合 CI 的机器可读 `-DryRun` 模式。

&nbsp;

## 功能

- **多位置设置检测**，兼容多种 Windows Terminal 安装路径  
- **原子写入**，避免损坏 `settings.json`  
- **字体白名单支持**，并提供等宽字体检测回退  
- **DryRun JSON 输出**，便于预览与自动化  
- **可选备份与日志**，支持时间戳备份与日志记录

&nbsp;

## 安装

1. 将仓库克隆或下载到你的项目目录。  
2. 确保安装 **PowerShell 7+** 或 Windows PowerShell 并可用 `System.Drawing`。  
3. （可选）在 `config/fonts.json` 放置字体白名单（JSON 数组），或通过 `-FontWhitelist` 指定路径。

&nbsp;

## 使用

**预览（不修改）**

```powershell
.\scripts\randomize.ps1 -Profile "PowerShell" -DryRun
```

**应用更改并启动配置文件**

```powershell
.\scripts\randomize.ps1 -Profile "PowerShell"
```

### 常用选项

- **`-Profile <name>`** — **必需。** 与 `settings.json` 中的配置文件名称完全匹配。  
- **`-FontWhitelist <path>`** — 指定首选字体的 JSON 文件路径。  
- **`-DryRun`** — 输出 JSON 摘要，不修改 `settings.json`。  
- **`-NoBackup`** — 跳过创建时间戳备份。  
- **`-LogFile <path>`** — 将时间戳日志追加到指定文件。

&nbsp;

## 在配置文件启动时触发随机器

提供两种常用方式，在 Windows Terminal 配置文件打开时自动运行 `randomize.ps1`。将其中一种方法的命令填入配置文件的 **Command line** 字段即可。

### A — 直接命令行（推荐）

**说明**  
通过 PowerShell 调用 `randomize.ps1` 并保持 shell 打开，最简单直接。

**Windows PowerShell 示例**

```json
"commandline": "powershell.exe -NoExit -ExecutionPolicy Bypass -Command \"& 'C:\\absolute\\path\\to\\terminal-randomizer\\scripts\\randomize.ps1' -Profile 'PowerShell' -LogFile 'C:\\Users\\you\\AppData\\Local\\terminal-randomizer\\randomize.log'\""
```

**PowerShell 7 示例**

```json
"commandline": "C:\\Program Files\\PowerShell\\7\\pwsh.exe -NoExit -ExecutionPolicy Bypass -Command \"& 'C:\\absolute\\path\\to\\terminal-randomizer\\scripts\\randomize.ps1' -Profile 'PowerShell' -LogFile 'C:\\Users\\you\\AppData\\Local\\terminal-randomizer\\randomize.log'\""
```

**如何应用**

1. 打开 Windows Terminal → **Settings** → 选择目标配置文件（例如 PowerShell）。  
2. 在 **Command line** 字段粘贴对应命令。  
3. 保存并打开该配置文件进行测试。

### B — VBScript 包装器（可选）

**说明**  
使用 `.vbs` 包装器可控制窗口可见性或在启动交互 shell 前做额外处理。

**示例 `launch_randomizer.vbs`**

```vbscript
Set WshShell = CreateObject("WScript.Shell")
psPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
scriptPath = "C:\absolute\path\to\terminal-randomizer\scripts\randomize.ps1"
cmd = """" & psPath & """ -NoExit -ExecutionPolicy Bypass -Command ""& '" & scriptPath & "' -Profile 'PowerShell' -LogFile 'C:\\Users\\you\\AppData\\Local\\terminal-randomizer\\randomize.log'"""
WshShell.Run cmd, 1, false
```

**隐藏运行**  
将 `1` 改为 `0` 可隐藏 PowerShell 窗口（调试时不建议隐藏）。

**配置文件中运行包装器的命令**

```json
"commandline": "wscript.exe \"C:\\absolute\\path\\to\\terminal-randomizer\\launch_randomizer.vbs\""
```

### `settings.json` 示例片段

```json
{
  "guid": "{...}",
  "name": "PowerShell",
  "commandline": "powershell.exe -NoExit -ExecutionPolicy Bypass -Command \"& 'C:\\absolute\\path\\to\\terminal-randomizer\\scripts\\randomize.ps1' -Profile 'PowerShell'\"",
  "hidden": false
}
```

**注意** 编辑 `settings.json` 时请使用绝对路径并正确转义内层引号。

&nbsp;

## 最佳实践与故障排查

**先用 DryRun 测试**

```powershell
.\scripts\randomize.ps1 -Profile "PowerShell" -DryRun
```

**推荐做法**

- 使用 **绝对路径**。  
- 保持 **`-NoExit`**，以便脚本运行后保留交互 shell。  
- 仅对受信任的本地脚本使用 **`-ExecutionPolicy Bypass`**，更严格的环境请签名脚本。  
- 使用 **`-LogFile`** 记录日志便于排查。  
- 避免在启动脚本中执行耗时任务，保持启动快速。

**常见问题**

- **脚本未执行** — 将 `commandline` 的命令复制到普通 PowerShell 中运行以查看错误。  
- **终端立即关闭** — 检查是否包含 `-NoExit`。  
- **写入 settings.json 权限被拒绝** — 检查文件权限或 Terminal 是否以不同权限运行。  
- **引号/转义问题** — 编辑 JSON 时使用 `\"` 转义内层引号。  
- **隐藏包装器无输出** — 取消隐藏或查看日志文件以获取错误信息。

&nbsp;

# 相关工具与集成

除了随机化 Windows Terminal 的字体和配色方案，本项目还可以与其他定制工具结合使用：

### Oh‑My‑Posh

[Oh‑My‑Posh](https://ohmyposh.dev/) 是一个跨平台的命令行提示主题引擎。  
你可以在 shell 启动时随机选择主题：

**PowerShell 示例**

```powershell
$random_theme = Get-Item -Path "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\*" |
    Select-Object -Property Name | Get-Random
$theme_path = Join-Path "$env:LOCALAPPDATA\Programs\oh-my-posh\themes" $random_theme.Name
oh-my-posh init pwsh --config $theme_path | Invoke-Expression
```

**Linux Bash 示例**

```bash
randompick=$(find ~/.cache/oh-my-posh/themes -name "*.omp.json" -print0 | shuf -zn1 | tr -d '\0')
eval "$(oh-my-posh init bash --config $randompick)"
```

这样，每次打开新的 shell 会话时都会加载不同的提示主题。

### WindowsTerminalThemes.dev

[WindowsTerminalThemes.dev](https://windowsterminalthemes.dev/) 提供超过 **4000 种 Windows Terminal 配色方案**。  
你可以浏览、预览并下载完整的主题集合，用来扩展随机器的配色库。

&nbsp;

## 贡献与许可证

欢迎贡献。请提交 issue 或 PR，并尽量包含测试或复现步骤。  
本项目采用 **MIT License**，详见 `LICENSE` 文件。

&nbsp;

## 快速提交示例

```powershell
git add scripts/randomize.ps1 README.md LICENSE
git commit -m "docs: add profile trigger instructions and bilingual README"
git push
```
