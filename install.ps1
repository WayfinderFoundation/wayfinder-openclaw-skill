# install.ps1 — Install or update wayfinder-openclaw skills on Windows.
#
# Clones the repo (or pulls latest) into a cache directory, then creates
# directory junctions for each skill folder into the OpenClaw skills directory.
# Running it again updates everything in place.
#
# Usage:
#   .\install.ps1                          Install/update with defaults
#   .\install.ps1 -SkillsDir "C:\path"    Override skills install directory
#   .\install.ps1 -RepoDir "C:\path"      Override where the repo is cached
#   .\install.ps1 -Uninstall              Remove junctions and cached repo

param(
    [string]$SkillsDir,
    [string]$RepoDir,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$RepoUrl = "https://github.com/WayfinderFoundation/wayfinder-openclaw-skill.git"
$DefaultSkillsDir = Join-Path $env:USERPROFILE ".openclaw\workspace\skills"
$DefaultRepoDir = Join-Path $env:USERPROFILE ".openclaw\workspace\.repos\wayfinder-openclaw-skill"

if (-not $SkillsDir) { $SkillsDir = if ($env:OPENCLAW_SKILLS_DIR) { $env:OPENCLAW_SKILLS_DIR } else { $DefaultSkillsDir } }
if (-not $RepoDir) { $RepoDir = if ($env:OPENCLAW_REPO_DIR) { $env:OPENCLAW_REPO_DIR } else { $DefaultRepoDir } }

if ($Help) {
    Get-Help $MyInvocation.MyCommand.Path -Detailed
    exit 0
}

# --- Read skill directories from skill.json ---

function Get-SkillDirs {
    param([string]$SkillJson)
    $data = Get-Content $SkillJson -Raw | ConvertFrom-Json
    $dirs = @()
    foreach ($skill in $data.skills) {
        $entry = $skill.entry
        if ($entry -match "^([^/]+)/") {
            $dir = $Matches[1]
            if ($dirs -notcontains $dir) {
                $dirs += $dir
            }
        }
    }
    return $dirs
}

# --- Uninstall ---

if ($Uninstall) {
    Write-Host "Uninstalling wayfinder-openclaw skills..."

    $skillJson = Join-Path $RepoDir "skill.json"
    if (Test-Path $skillJson) {
        foreach ($dir in (Get-SkillDirs $skillJson)) {
            $link = Join-Path $SkillsDir $dir
            if (Test-Path $link) {
                $item = Get-Item $link -Force
                if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
                    cmd /c rmdir "$link" 2>$null
                    Write-Host "  Removed junction: $link"
                }
            }
        }

        $jsonLink = Join-Path $SkillsDir "wayfinder-openclaw-skill.json"
        if (Test-Path $jsonLink) {
            Remove-Item $jsonLink -Force
            Write-Host "  Removed: $jsonLink"
        }
    }

    if (Test-Path $RepoDir) {
        Remove-Item $RepoDir -Recurse -Force
        Write-Host "  Removed cached repo: $RepoDir"
    }

    Write-Host "Done."
    exit 0
}

# --- Install / Update ---

Write-Host "Wayfinder OpenClaw Skill Installer"
Write-Host "==================================="
Write-Host "Skills dir: $SkillsDir"
Write-Host "Repo cache: $RepoDir"
Write-Host ""

$gitDir = Join-Path $RepoDir ".git"
if (Test-Path $gitDir) {
    Write-Host "Updating existing repo..."
    $before = (git -C $RepoDir rev-parse HEAD).Trim()
    git -C $RepoDir pull --quiet
    $after = (git -C $RepoDir rev-parse HEAD).Trim()

    if ($before -eq $after) {
        Write-Host "Already up to date. ($($after.Substring(0,8)))"
    } else {
        Write-Host "Updated: $($before.Substring(0,8)) -> $($after.Substring(0,8))"
        $changed = git -C $RepoDir diff --name-only $before $after | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique
        Write-Host "Changed domains: $($changed -join ', ')"
    }
} else {
    Write-Host "Cloning repo..."
    $parentDir = Split-Path $RepoDir -Parent
    if (-not (Test-Path $parentDir)) { New-Item -ItemType Directory -Path $parentDir -Force | Out-Null }
    git clone --quiet $RepoUrl $RepoDir
    $ref = (git -C $RepoDir rev-parse --short HEAD).Trim()
    Write-Host "Cloned at $ref"
}

Write-Host ""

# Create skills directory
if (-not (Test-Path $SkillsDir)) { New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null }

# Create directory junctions for each skill
$skillDirs = Get-SkillDirs (Join-Path $RepoDir "skill.json")
$linked = 0
$skipped = 0

foreach ($dir in $skillDirs) {
    $src = Join-Path $RepoDir $dir
    $dest = Join-Path $SkillsDir $dir

    if (-not (Test-Path $src)) {
        Write-Host "  WARN: Skill directory '$dir' not found in repo, skipping"
        continue
    }

    if (Test-Path $dest) {
        $item = Get-Item $dest -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            # Already a junction — verify target
            $currentTarget = $item.Target
            if ($currentTarget -eq $src) {
                $skipped++
                continue
            } else {
                cmd /c rmdir "$dest" 2>$null
                Write-Host "  Relinked: $dir (was pointing to $currentTarget)"
            }
        } else {
            Write-Host "  WARN: $dest exists as a real directory, skipping (remove it manually to use junction)"
            continue
        }
    }

    # Create directory junction (no admin privileges required)
    cmd /c mklink /J "$dest" "$src" | Out-Null
    $linked++
    Write-Host "  Linked: $dir -> $src"
}

# Copy skill.json for discovery (junctions don't work for single files)
$skillJsonSrc = Join-Path $RepoDir "skill.json"
$skillJsonDest = Join-Path $SkillsDir "wayfinder-openclaw-skill.json"
if (-not (Test-Path $skillJsonDest)) {
    Copy-Item $skillJsonSrc $skillJsonDest
    Write-Host "  Copied: skill.json -> $skillJsonDest"
}

Write-Host ""
Write-Host "Done. $linked new links, $skipped already up to date."
Write-Host ""

Write-Host "Installed $($skillDirs.Count) skill domains:"
foreach ($dir in $skillDirs) {
    $dest = Join-Path $SkillsDir $dir
    if (Test-Path $dest) {
        Write-Host "  + $dir"
    }
}
