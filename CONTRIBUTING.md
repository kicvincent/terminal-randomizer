# Contributing

Thanks for considering contributing!

## How to contribute
1. Fork the repo and create a branch for your change.
2. Run `Invoke-ScriptAnalyzer` locally on PowerShell scripts.
3. Open a pull request with a clear description and tests/examples if applicable.

## Adding fonts
Edit `config/fonts.json` with one font name per array element.

## Code style
- Use `$null`-left comparisons (e.g., `$null -eq $var`) for PSScriptAnalyzer compatibility.
- Preserve `font.size` and `font.cellHeight` when changing fonts.
