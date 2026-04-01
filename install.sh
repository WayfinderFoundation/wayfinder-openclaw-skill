#!/usr/bin/env bash
# install.sh — Install or update wayfinder-openclaw skills.
#
# Copies each skill folder from the repo into the OpenClaw skills directory.
# Running it again updates everything in place.
#
# Usage:
#   ./install.sh                   Install/update with defaults
#   ./install.sh --skills-dir DIR  Override skills install directory
#   ./install.sh --repo-dir DIR    Override repo source directory (default: directory containing this script)
#   ./install.sh --uninstall       Remove installed skills
#
# Environment:
#   OPENCLAW_SKILLS_DIR   Override default skills directory (~/.openclaw/workspace/skills)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_SKILLS_DIR="$HOME/.openclaw/workspace/skills"

SKILLS_DIR="${OPENCLAW_SKILLS_DIR:-$DEFAULT_SKILLS_DIR}"
REPO_DIR="$SCRIPT_DIR"
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
            head -14 "$0" | tail -12
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
    python3 -c "
import json
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
            target="$SKILLS_DIR/$dir"
            if [[ -d "$target" ]]; then
                rm -rf "$target"
                echo "  Removed: $target"
            fi
        done
        if [[ -f "$SKILLS_DIR/wayfinder-openclaw-skill.json" ]]; then
            rm "$SKILLS_DIR/wayfinder-openclaw-skill.json"
            echo "  Removed: $SKILLS_DIR/wayfinder-openclaw-skill.json"
        fi
    fi

    echo "Done."
    exit 0
fi

# --- Install / Update ---

echo "Wayfinder OpenClaw Skill Installer"
echo "==================================="
echo "Skills dir: $SKILLS_DIR"
echo "Source:     $REPO_DIR"
echo ""

if [[ ! -f "$REPO_DIR/skill.json" ]]; then
    echo "Error: skill.json not found in $REPO_DIR" >&2
    exit 1
fi

# Create skills directory
mkdir -p "$SKILLS_DIR"

# Copy each skill directory
SKILL_DIRS=$(get_skill_dirs "$REPO_DIR/skill.json")
COPIED=0
UPDATED=0

for dir in $SKILL_DIRS; do
    src="$REPO_DIR/$dir"
    dest="$SKILLS_DIR/$dir"

    if [[ ! -d "$src" ]]; then
        echo "  WARN: Skill directory '$dir' not found in repo, skipping"
        continue
    fi

    # Remove old symlinks from previous install method
    if [[ -L "$dest" ]]; then
        rm "$dest"
        echo "  Migrated from symlink: $dir"
    fi

    if [[ -d "$dest" ]]; then
        # Update existing copy
        rm -rf "$dest"
        cp -R "$src" "$dest"
        UPDATED=$((UPDATED + 1))
    else
        cp -R "$src" "$dest"
        COPIED=$((COPIED + 1))
        echo "  Installed: $dir"
    fi
done

# Copy skill.json for discovery
cp "$REPO_DIR/skill.json" "$SKILLS_DIR/wayfinder-openclaw-skill.json"

echo ""
echo "Done. $COPIED new, $UPDATED updated."
echo ""

# Summary
TOTAL=$(echo "$SKILL_DIRS" | wc -w)
echo "Installed $TOTAL skill domains:"
for dir in $SKILL_DIRS; do
    if [[ -d "$SKILLS_DIR/$dir" ]]; then
        echo "  + $dir"
    fi
done
