<#
.SYNOPSIS
  Randomize Windows Terminal profile font and color scheme, then launch the profile.

.PARAMETER Profile
  Exact profile name from settings.json (required).

.PARAMETER FontWhitelist
  Optional path to JSON array of font names.

.PARAMETER DryRun
  If set, prints planned changes without writing settings.json.

.PARAMETER NoBackup
  If set, skip creating a timestamped backup.

.PARAMETER LogFile
  Optional path to append a timestamped log entry.
#>

param(
    [Parameter(Mandatory = $true)][string]$Profile,
    [string]$FontWhitelist = "$PSScriptRoot\..\config\fonts.json",
    [switch]$DryRun,
    [switch]$NoBackup,
    [string]$LogFile
)

function Write-TerminalLog {
    param([string]$Level, [string]$Message)
    $entry = "{0} | {1} | {2}" -f (Get-Date -Format o), $Level, $Message
    if ($LogFile) {
        try { Add-Content -Path $LogFile -Value $entry } catch { Write-Verbose "Failed to write log: $($_.Exception.Message)" }
    }
    else {
        Write-Verbose $entry
    }
}


# Path to Windows Terminal settings.json (Store build)
$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
if (-not (Test-Path $settingsPath)) {
    Write-Error "settings.json not found at $settingsPath"
    exit 1
}

# Load settings
try {
    $json = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
}
catch {
    Write-Error "Failed to read or parse settings.json: $($_.Exception.Message)"
    exit 1
}

# Load whitelist if present
$whitelist = @()
if (Test-Path $FontWhitelist) {
    try {
        $whitelist = Get-Content $FontWhitelist -Raw | ConvertFrom-Json
        if ($null -eq $whitelist) { $whitelist = @() }
    }
    catch {
        Write-Log "WARN" "Failed to load font whitelist from '$FontWhitelist': $($_.Exception.Message)"
        $whitelist = @()
    }
}

# Curated fallback whitelist
$defaultWhitelist = @(
    "Cascadia Mono",
    "FiraCode Nerd Font Mono",
    "Hack Nerd Font Mono",
    "MesloLGL Nerd Font Mono"
)

$monoWhitelist = if ($whitelist.Count -gt 0) { $whitelist } else { $defaultWhitelist }

# Detect installed fonts
$available = @()
try {
    Add-Type -AssemblyName System.Drawing -ErrorAction Stop
    $installed = [System.Drawing.FontFamily]::Families | ForEach-Object { $_.Name }
    $available = $monoWhitelist | Where-Object { $installed -contains $_ }
}
catch {
    Write-Log "WARN" "System.Drawing font enumeration failed: $($_.Exception.Message)"
    $available = @()
}

# Fallback detection of monospace fonts if whitelist not available
if ($null -eq $available -or $available.Count -eq 0) {
    try {
        $monoDetected = [System.Collections.Generic.List[string]]::new()
        $bitmap = New-Object System.Drawing.Bitmap 300, 60
        $g = [System.Drawing.Graphics]::FromImage($bitmap)
        foreach ($fFamily in [System.Drawing.FontFamily]::Families) {
            $name = $fFamily.Name
            try {
                $f = New-Object System.Drawing.Font($name, 14)
                $w1 = $g.MeasureString("i", $f).Width
                $w2 = $g.MeasureString("W", $f).Width
                if ([math]::Abs($w1 - $w2) -lt 0.5) { $monoDetected.Add($name) }
                $f.Dispose()
            }
            catch {
                Write-Log "DEBUG" "Font probe failed for '$name': $($_.Exception.Message)"
            }
        }
        $g.Dispose(); $bitmap.Dispose()
        $available = $monoDetected
    }
    catch {
        Write-Log "WARN" "Fallback font detection failed: $($_.Exception.Message)"
        $available = @()
    }
}

if ($null -eq $available -or $available.Count -eq 0) {
    Write-Warning "No monospaced fonts found. Font change will be skipped."
    $choiceFont = $null
}
else {
    $choiceFont = Get-Random -InputObject $available
}

# Choose random color scheme excluding light variants
$schemes = @()
if ($json.schemes) {
    try {
        $schemes = $json.schemes | Where-Object { $_.name -notmatch '(-|\s)?light$' } | ForEach-Object { $_.name }
    }
    catch {
        Write-Log "WARN" "Failed to enumerate schemes from settings.json: $($_.Exception.Message)"
        $schemes = @()
    }
}
$randomScheme = if ($schemes.Count -gt 0) { Get-Random -InputObject $schemes } else { $null }
$cleanTabTitle = if ($null -ne $randomScheme) { $randomScheme -replace '[^\x00-\x7F]', '' -replace '^\s+|\s+$', '' } else { $Profile }

# Find profile object
$profile1 = $null
try {
    if ($json.profiles -and $json.profiles.list) {
        $profile1 = $json.profiles.list | Where-Object { $_.name -eq $Profile } | Select-Object -First 1
    }
    elseif ($json.profiles) {
        $profile1 = $json.profiles | Where-Object { $_.name -eq $Profile } | Select-Object -First 1
    }
}
catch {
    Write-Error "Failed to search profiles in settings.json: $($_.Exception.Message)"
    exit 2
}

if ($null -eq $profile1) {
    Write-Error "Profile '$Profile' not found in settings.json"
    exit 2
}

# Preserve existing size/cellHeight
$existingSize = $null; $existingCellHeight = $null
if ($null -ne $profile1.font) {
    try {
        if ($profile1.font.PSObject.Properties.Name -contains 'size') { $existingSize = $profile1.font.size }
        if ($profile1.font.PSObject.Properties.Name -contains 'cellHeight') { $existingCellHeight = $profile1.font.cellHeight }
    }
    catch {
        Write-Log "DEBUG" "Failed to read existing font properties: $($_.Exception.Message)"
    }
}

# Apply font if chosen
if ($null -ne $choiceFont) {
    try {
        $fontObj = [PSCustomObject]@{ face = $choiceFont }
        if ($null -ne $existingSize) { $fontObj | Add-Member -NotePropertyName size -NotePropertyValue $existingSize -Force } else { $fontObj | Add-Member -NotePropertyName size -NotePropertyValue 11 -Force }
        if ($null -ne $existingCellHeight) { $fontObj | Add-Member -NotePropertyName cellHeight -NotePropertyValue $existingCellHeight -Force }
        $profile1.font = $fontObj
        if ($profile1.PSObject.Properties.Name -contains 'fontFace') { $profile1.fontFace = $choiceFont } else { $profile1 | Add-Member -NotePropertyName fontFace -NotePropertyValue $choiceFont -Force }
    }
    catch {
        Write-Log "ERROR" "Failed to apply font '$choiceFont' to profile '$Profile': $($_.Exception.Message)"
    }
}

# Apply scheme and tab title
if ($null -ne $randomScheme) {
    try { $profile1.colorScheme = $randomScheme } catch { Write-Log "ERROR" "Failed to set color scheme '$randomScheme': $($_.Exception.Message)" }
}
try { $profile1.tabTitle = $cleanTabTitle } catch { Write-Log "DEBUG" "Failed to set tabTitle: $($_.Exception.Message)" }

# Dry run prints planned changes
if ($DryRun) {
    Write-Output "DryRun: Profile = $Profile"
    Write-Output "DryRun: Font = $choiceFont"
    Write-Output "DryRun: Scheme = $randomScheme"
    return
}

# Backup unless disabled
if (-not $NoBackup) {
    try {
        $timeStamp = (Get-Date).ToString('yyyyMMddHHmmss')
        Copy-Item -Path $settingsPath -Destination "$settingsPath.bak.$timeStamp" -ErrorAction Stop
    }
    catch {
        Write-Log "WARN" "Failed to create backup of settings.json: $($_.Exception.Message)"
    }
}

# Write settings.json once (UTF8 no BOM)
try {
    $jsonString = $json | ConvertTo-Json -Depth 100
    [System.IO.File]::WriteAllText($settingsPath, $jsonString, [System.Text.Encoding]::UTF8)
    Write-Log "INFO" "Updated settings.json for profile '$Profile' (Font: $choiceFont; Scheme: $randomScheme)"
}
catch {
    Write-Error "Failed to write settings.json: $($_.Exception.Message)"
    exit 3
}

# Optional logging
if ($LogFile) {
    try {
        $entry = "{0} | Profile:{1} | Font:{2} | Scheme:{3}" -f (Get-Date -Format o), $Profile, $choiceFont, $randomScheme
        Add-Content -Path $LogFile -Value $entry
    }
    catch {
        Write-Verbose "Failed to append to log file: $($_.Exception.Message)"
    }
}

# Launch only the requested profile
try {
    Start-Process wt.exe -ArgumentList "-p `"$Profile`""
}
catch {
    Write-Error "Failed to launch Windows Terminal for profile '$Profile': $($_.Exception.Message)"
}
