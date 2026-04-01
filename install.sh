#!/usr/bin/env bash
# install.sh — Install or update wayfinder-openclaw skills.
#
# Clones the repo (or pulls latest) into a cache directory, then copies
# each skill folder into the OpenClaw skills directory. Running it again
# updates everything in place.
#
# Usage:
#   ./install.sh                   Install/update with defaults
#   ./install.sh --skills-dir DIR  Override skills install directory
#   ./install.sh --repo-dir DIR    Override where the repo is cached
#   ./install.sh --uninstall       Remove installed skills and cached repo
#
# Environment:
#   OPENCLAW_SKILLS_DIR   Override default skills directory (~/.openclaw/workspace/skills)
#   OPENCLAW_REPO_DIR     Override default repo cache (~/.openclaw/workspace/.repos/wayfinder-openclaw-skill)

set -euo pipefail

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
