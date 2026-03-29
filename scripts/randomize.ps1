<#
.SYNOPSIS
  Randomize a Windows Terminal profile's font and color scheme, then launch the profile.

.DESCRIPTION
  Chooses a random monospaced font and a random color scheme (excluding light variants)
  and applies them to the specified Windows Terminal profile in settings.json.
  The script supports multiple Windows Terminal install locations, performs an atomic write
  to avoid corrupting settings.json, and provides a machine-readable DryRun output.

.PARAMETER Profile
  Exact profile name from settings.json. Required.

.PARAMETER FontWhitelist
  Optional path to a JSON array of font names. Defaults to ../config/fonts.json relative to the script.

.PARAMETER DryRun
  If set, prints a JSON summary of planned changes and does not modify settings.json.

.PARAMETER NoBackup
  If set, skip creating a timestamped backup of settings.json.

.PARAMETER LogFile
  Optional path to append a timestamped log entry.

.EXAMPLE
  .\randomize.ps1 -Profile "PowerShell" -DryRun

.EXAMPLE
  .\randomize.ps1 -Profile "Ubuntu" -FontWhitelist ".\config\fonts.json"

.INPUTS
  None

.OUTPUTS
  JSON summary when -DryRun is used; otherwise writes to settings.json and may launch wt.exe.

#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$Profile,

    [ValidateNotNullOrEmpty()]
    [string]$FontWhitelist = "$PSScriptRoot\..\config\fonts.json",

    [switch]$DryRun,

    [switch]$NoBackup,

    [string]$LogFile
)

Set-StrictMode -Version Latest

function Write-TerminalLog {
    param(
        [ValidateSet("DEBUG","INFO","WARN","ERROR")]
        [string]$Level,
        [string]$Message
    )
    $entry = "{0} | {1} | {2}" -f (Get-Date -Format o), $Level, $Message
    if ($LogFile) {
        try {
            $dir = Split-Path -Path $LogFile -Parent
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Add-Content -Path $LogFile -Value $entry -ErrorAction Stop
        } catch {
            Write-Verbose "Write-TerminalLog: Failed to write log file: $($_.Exception.Message)"
        }
    } else {
        switch ($Level) {
            "DEBUG" { Write-Verbose $entry }
            "INFO"  { Write-Verbose $entry }
            "WARN"  { Write-Warning $Message }
            "ERROR" { Write-Error $Message }
        }
    }
}

function Get-SettingsPath {
    # Probe known locations for Windows Terminal settings.json
    $possible = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json",
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json",
        "$env:LOCALAPPDATA\Packages\WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
    )

    foreach ($p in $possible) {
        if ($p -and (Test-Path $p)) { return $p }
    }

    # If not found, attempt a broader search under LocalAppData\Packages
    try {
        $packagesDir = Join-Path $env:LOCALAPPDATA "Packages"
        if (Test-Path $packagesDir) {
            $candidates = Get-ChildItem -Path $packagesDir -Directory -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -match 'WindowsTerminal' -or $_.Name -match 'WindowsTerminalPreview' } |
                ForEach-Object { Join-Path $_.FullName "LocalState\settings.json" } |
                Where-Object { Test-Path $_ }
            if ($candidates.Count -gt 0) { return $candidates[0] }
        }
    } catch {
        Write-TerminalLog "DEBUG" "Get-SettingsPath search failed: $($_.Exception.Message)"
    }

    return $null
}

# Locate settings.json
$settingsPath = Get-SettingsPath
if (-not $settingsPath) {
    Write-TerminalLog "ERROR" "Could not find Windows Terminal settings.json in known locations."
    Write-Error "Could not find Windows Terminal settings.json. Ensure Windows Terminal is installed."
    exit 1
}

# Load settings.json
try {
    $json = Get-Content -Path $settingsPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
} catch {
    Write-TerminalLog "ERROR" "Failed to read or parse settings.json at '$settingsPath': $($_.Exception.Message)"
    Write-Error "Failed to read or parse settings.json: $($_.Exception.Message)"
    exit 2
}

# Load font whitelist if present
$whitelist = @()
if ($FontWhitelist -and (Test-Path $FontWhitelist)) {
    try {
        $whitelist = Get-Content -Path $FontWhitelist -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($null -eq $whitelist) { $whitelist = @() }
    } catch {
        Write-TerminalLog "WARN" "Failed to load font whitelist from '$FontWhitelist': $($_.Exception.Message)"
        $whitelist = @()
    }
} else {
    if ($FontWhitelist -and ($FontWhitelist -ne "$PSScriptRoot\..\config\fonts.json")) {
        Write-TerminalLog "WARN" "FontWhitelist path '$FontWhitelist' not found; using defaults."
    }
}

# Default curated whitelist
$defaultWhitelist = @(
    "Cascadia Mono",
    "Cascadia Code PL",
    "FiraCode Nerd Font Mono",
    "Hack Nerd Font Mono",
    "MesloLGL Nerd Font Mono",
    "Consolas",
    "DejaVu Sans Mono"
)

$monoWhitelist = if ($whitelist.Count -gt 0) { $whitelist } else { $defaultWhitelist }

# Detect installed fonts
$available = @()
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $installed = [System.Drawing.FontFamily]::Families | ForEach-Object { $_.Name }
    $available = $monoWhitelist | Where-Object { $installed -contains $_ }
} catch {
    Write-TerminalLog "WARN" "System.Drawing font enumeration failed: $($_.Exception.Message)"
    $available = @()
}

# Fallback: detect monospace fonts by measuring glyph widths
if ($available.Count -eq 0) {
    try {
        $monoDetected = [System.Collections.Generic.List[string]]::new()
        $bitmap = New-Object System.Drawing.Bitmap 300,60
        $g = [System.Drawing.Graphics]::FromImage($bitmap)
        foreach ($fFamily in [System.Drawing.FontFamily]::Families) {
            $name = $fFamily.Name
            try {
                $f = New-Object System.Drawing.Font($name, 14)
                $w1 = $g.MeasureString("i",$f).Width
                $w2 = $g.MeasureString("W",$f).Width
                if ([math]::Abs($w1 - $w2) -lt 0.5) { $monoDetected.Add($name) }
                $f.Dispose()
            } catch {
                Write-TerminalLog "DEBUG" "Font probe failed for '$name': $($_.Exception.Message)"
            }
        }
        $g.Dispose(); $bitmap.Dispose()
        $available = $monoDetected
    } catch {
        Write-TerminalLog "WARN" "Fallback font detection failed: $($_.Exception.Message)"
        $available = @()
    }
}

if ($available.Count -eq 0) {
    Write-TerminalLog "WARN" "No monospaced fonts detected; font change will be skipped."
    $choiceFont = $null
} else {
    $choiceFont = Get-Random -InputObject $available
    Write-TerminalLog "DEBUG" "Selected font: $choiceFont"
}

# Choose random color scheme excluding light variants
$schemes = @()
try {
    if ($json.schemes) {
        $schemes = $json.schemes | Where-Object { $_.name -notmatch '(-|\s)?light$' } | ForEach-Object { $_.name }
    }
} catch {
    Write-TerminalLog "WARN" "Failed to enumerate schemes from settings.json: $($_.Exception.Message)"
    $schemes = @()
}
$randomScheme = if ($schemes.Count -gt 0) { Get-Random -InputObject $schemes } else { $null }
if ($randomScheme) { Write-TerminalLog "DEBUG" "Selected scheme: $randomScheme" }

# Clean tab title
$cleanTabTitle = if ($null -ne $randomScheme) { ($randomScheme -replace '[^\x00-\x7F]', '' -replace '^\s+|\s+$','') } else { $Profile }

# Find profile object
$profileObj = $null
try {
    if ($json.profiles -and $json.profiles.list) {
        $profileObj = $json.profiles.list | Where-Object { $_.name -eq $Profile } | Select-Object -First 1
    } elseif ($json.profiles) {
        $profileObj = $json.profiles | Where-Object { $_.name -eq $Profile } | Select-Object -First 1
    }
} catch {
    Write-TerminalLog "ERROR" "Failed to search profiles in settings.json: $($_.Exception.Message)"
    Write-Error "Failed to search profiles in settings.json: $($_.Exception.Message)"
    exit 2
}

if (-not $profileObj) {
    Write-TerminalLog "ERROR" "Profile '$Profile' not found in settings.json"
    Write-Error "Profile '$Profile' not found in settings.json"
    exit 2
}

# Preserve existing font size/cellHeight if present
$existingSize = $null; $existingCellHeight = $null
try {
    if ($profileObj.font) {
        if ($profileObj.font.PSObject.Properties.Name -contains 'size') { $existingSize = $profileObj.font.size }
        if ($profileObj.font.PSObject.Properties.Name -contains 'cellHeight') { $existingCellHeight = $profileObj.font.cellHeight }
    }
} catch {
    Write-TerminalLog "DEBUG" "Failed to read existing font properties: $($_.Exception.Message)"
}

# Apply font if chosen
if ($choiceFont) {
    try {
        $fontObj = [PSCustomObject]@{ face = $choiceFont }
        if ($existingSize) { $fontObj | Add-Member -NotePropertyName size -NotePropertyValue $existingSize -Force } else { $fontObj | Add-Member -NotePropertyName size -NotePropertyValue 11 -Force }
        if ($existingCellHeight) { $fontObj | Add-Member -NotePropertyName cellHeight -NotePropertyValue $existingCellHeight -Force }
        $profileObj.font = $fontObj
        if ($profileObj.PSObject.Properties.Name -contains 'fontFace') { $profileObj.fontFace = $choiceFont } else { $profileObj | Add-Member -NotePropertyName fontFace -NotePropertyValue $choiceFont -Force }
    } catch {
        Write-TerminalLog "ERROR" "Failed to apply font '$choiceFont' to profile '$Profile': $($_.Exception.Message)"
    }
}

# Apply scheme and tab title
if ($randomScheme) {
    try { $profileObj.colorScheme = $randomScheme } catch { Write-TerminalLog "ERROR" "Failed to set color scheme '$randomScheme': $($_.Exception.Message)" }
}
try { $profileObj.tabTitle = $cleanTabTitle } catch { Write-TerminalLog "DEBUG" "Failed to set tabTitle: $($_.Exception.Message)" }

# Dry run: output JSON summary and exit
if ($DryRun) {
    $summary = [PSCustomObject]@{
        Profile      = $Profile
        Font         = $choiceFont
        Scheme       = $randomScheme
        SettingsPath = $settingsPath
        Timestamp    = (Get-Date -Format o)
    }
    $summary | ConvertTo-Json -Depth 5
    return
}

# Backup unless disabled
if (-not $NoBackup) {
    try {
        $timeStamp = (Get-Date).ToString('yyyyMMddHHmmss')
        $backupPath = "$settingsPath.bak.$timeStamp"
        Copy-Item -Path $settingsPath -Destination $backupPath -ErrorAction Stop
        Write-TerminalLog "INFO" "Created backup: $backupPath"
    } catch {
        Write-TerminalLog "WARN" "Failed to create backup of settings.json: $($_.Exception.Message)"
    }
}

# Atomic write: write to temp file then move into place
try {
    $jsonString = $json | ConvertTo-Json -Depth 100
    $tmp = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tmp, $jsonString, [System.Text.Encoding]::UTF8)
    Move-Item -Path $tmp -Destination $settingsPath -Force
    Write-TerminalLog "INFO" "Updated settings.json for profile '$Profile' (Font: $choiceFont; Scheme: $randomScheme)"
} catch {
    Write-TerminalLog "ERROR" "Failed to write settings.json atomically: $($_.Exception.Message)"
    Write-Error "Failed to write settings.json: $($_.Exception.Message)"
    exit 3
}

# Optional logging to file
if ($LogFile) {
    try {
        $entry = "{0} | Profile:{1} | Font:{2} | Scheme:{3}" -f (Get-Date -Format o), $Profile, $choiceFont, $randomScheme
        Add-Content -Path $LogFile -Value $entry -ErrorAction Stop
    } catch {
        Write-TerminalLog "WARN" "Failed to append to log file: $($_.Exception.Message)"
    }
}

# Launch the requested profile
try {
    Start-Process wt.exe -ArgumentList "-p `"$Profile`""
} catch {
    Write-TerminalLog "ERROR" "Failed to launch Windows Terminal for profile '$Profile': $($_.Exception.Message)"
    Write-Error "Failed to launch Windows Terminal for profile '$Profile': $($_.Exception.Message)"
}
