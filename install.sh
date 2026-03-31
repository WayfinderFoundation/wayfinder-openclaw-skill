#!/usr/bin/env bash
# install.sh — Install or update wayfinder-openclaw skills.
#
# Clones the repo (or pulls latest) into a cache directory, then symlinks
# each skill folder into the OpenClaw skills directory. Running it again
# updates everything in place.
#
# Usage:
#   ./install.sh                   Install/update with defaults
#   ./install.sh --skills-dir DIR  Override skills install directory
#   ./install.sh --repo-dir DIR    Override where the repo is cached
#   ./install.sh --uninstall       Remove symlinks and cached repo
#
# Environment:
#   OPENCLAW_SKILLS_DIR   Override default skills directory (~/.openclaw/workspace/skills)
#   OPENCLAW_REPO_DIR     Override default repo cache (~/.openclaw/workspace/.repos/wayfinder-openclaw-skill)

set -euo pipefail

# Portable resolve_path (macOS ships BSD readlink which lacks -f)
resolve_path() {
    local target="$1"
    cd "$(dirname "$target")" 2>/dev/null
    target=$(basename "$target")
    while [[ -L "$target" ]]; do
        target=$(readlink "$target")
        cd "$(dirname "$target")" 2>/dev/null
        target=$(basename "$target")
    done
    echo "$(pwd -P)/$target"
}

REPO_URL="https://github.com/WayfinderFoundation/wayfinder-openclaw-skill.git"
DEFAULT_SKILLS_DIR="$HOME/.openclaw/workspace/skills"
DEFAULT_REPO_DIR="$HOME/.openclaw/workspace/.repos/wayfinder-openclaw-skill"

SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-$DEFAULT_SKILLS_DIR}"
REPO_DIR="${OPENCLAW_REPO_DIR:-$DEFAULT_REPO_DIR}"
UNINSTALL=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --skills-dir)
            SKILLS_DIR="$2"
            shift 2
            ;;
        --repo-dir)
            REPO_DIR="$2"
            shift 2
            ;;
        --uninstall)
            UNINSTALL=true
            shift
            ;;
        --help|-h)
            head -17 "$0" | tail -15
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# --- Read skill directories from skill.json ---

get_skill_dirs() {
    local skill_json="$1"
    # Extract unique top-level directories from each skill's entry path
    python3 -c "
import json, os
with open('$skill_json') as f:
    data = json.load(f)
for skill in data.get('skills', []):
    entry = skill.get('entry', '')
    skill_dir = entry.split('/')[0] if '/' in entry else ''
    if skill_dir:
        print(skill_dir)
" | sort -u
}

# --- Uninstall ---

if $UNINSTALL; then
    echo "Uninstalling wayfinder-openclaw skills..."

    if [[ -f "$REPO_DIR/skill.json" ]]; then
        for dir in $(get_skill_dirs "$REPO_DIR/skill.json"); do
            link="$SKILLS_DIR/$dir"
            if [[ -L "$link" ]]; then
                rm "$link"
                echo "  Removed symlink: $link"
            fi
        done
        # Also remove top-level skill.json symlink
        if [[ -L "$SKILLS_DIR/wayfinder-openclaw-skill.json" ]]; then
            rm "$SKILLS_DIR/wayfinder-openclaw-skill.json"
            echo "  Removed symlink: $SKILLS_DIR/wayfinder-openclaw-skill.json"
        fi
    fi

    if [[ -d "$REPO_DIR" ]]; then
        rm -rf "$REPO_DIR"
        echo "  Removed cached repo: $REPO_DIR"
    fi

    echo "Done."
    exit 0
fi

# --- Install / Update ---

echo "Wayfinder OpenClaw Skill Installer"
echo "==================================="
echo "Skills dir: $SKILLS_DIR"
echo "Repo cache: $REPO_DIR"
echo ""

# Clone or pull
if [[ -d "$REPO_DIR/.git" ]]; then
    echo "Updating existing repo..."
    git -C "$REPO_DIR" fetch --quiet
    BEFORE=$(git -C "$REPO_DIR" rev-parse HEAD)
    git -C "$REPO_DIR" pull --quiet
    AFTER=$(git -C "$REPO_DIR" rev-parse HEAD)

    if [[ "$BEFORE" == "$AFTER" ]]; then
        echo "Already up to date. ($(echo "$AFTER" | cut -c1-8))"
    else
        echo "Updated: $(echo "$BEFORE" | cut -c1-8) -> $(echo "$AFTER" | cut -c1-8)"
        # Show what changed
        CHANGED_SKILLS=$(git -C "$REPO_DIR" diff --name-only "$BEFORE" "$AFTER" | cut -d/ -f1 | sort -u)
        echo "Changed domains: $CHANGED_SKILLS"
    fi
else
    echo "Cloning repo..."
    mkdir -p "$(dirname "$REPO_DIR")"
    git clone --quiet "$REPO_URL" "$REPO_DIR"
    echo "Cloned at $(git -C "$REPO_DIR" rev-parse --short HEAD)"
fi

echo ""

# Create skills directory
mkdir -p "$SKILLS_DIR"

# Symlink each skill directory
SKILL_DIRS=$(get_skill_dirs "$REPO_DIR/skill.json")
LINKED=0
SKIPPED=0

for dir in $SKILL_DIRS; do
    src="$REPO_DIR/$dir"
    dest="$SKILLS_DIR/$dir"

    if [[ ! -d "$src" ]]; then
        echo "  WARN: Skill directory '$dir' not found in repo, skipping"
        continue
    fi

    if [[ -L "$dest" ]]; then
        # Already a symlink — verify it points to the right place
        current_target=$(resolve_path "$dest")
        expected_target=$(resolve_path "$src")
        if [[ "$current_target" == "$expected_target" ]]; then
            SKIPPED=$((SKIPPED + 1))
            continue
        else
            rm "$dest"
            echo "  Relinked: $dir (was pointing to $current_target)"
        fi
    elif [[ -d "$dest" ]]; then
        echo "  WARN: $dest exists as a real directory, skipping (remove it manually to use symlink)"
        continue
    fi

    ln -s "$src" "$dest"
    LINKED=$((LINKED + 1))
    echo "  Linked: $dir -> $src"
done

# Symlink the top-level skill.json for discovery
SKILL_JSON_LINK="$SKILLS_DIR/wayfinder-openclaw-skill.json"
if [[ ! -L "$SKILL_JSON_LINK" ]]; then
    ln -s "$REPO_DIR/skill.json" "$SKILL_JSON_LINK"
    echo "  Linked: skill.json -> $REPO_DIR/skill.json"
fi

echo ""
echo "Done. $LINKED new links, $SKIPPED already up to date."
echo ""

# Summary
TOTAL=$(echo "$SKILL_DIRS" | wc -w)
echo "Installed $TOTAL skill domains:"
for dir in $SKILL_DIRS; do
    if [[ -L "$SKILLS_DIR/$dir" ]]; then
        echo "  + $dir"
    fi
done
