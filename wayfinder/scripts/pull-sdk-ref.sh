#!/usr/bin/env bash
# pull-sdk-ref.sh — Pull reference docs from wayfinder-paths-sdk skill files.
#
# Usage:
#   ./pull-sdk-ref.sh <topic>          Show docs for a specific topic
#   ./pull-sdk-ref.sh --list           List available topics
#   ./pull-sdk-ref.sh --all            Show all reference docs
#   ./pull-sdk-ref.sh --commit <ref>   Read docs from a specific SDK git ref (no checkout)
#   ./pull-sdk-ref.sh --version        Show the pinned SDK version from sdk-version.md
#
# Topics:
#   strategies   Developing Wayfinder strategies (workflow, manifests, safety, data sources)
#   setup        First-time SDK setup
#   data         Pool, token, and balance data (pool discovery, token metadata, ledger)
#   brap         BRAP swap/bridge adapter (quotes + execution gotchas)
#   aave         Aave V3 adapter (markets, positions, execution)
#   morpho       Morpho adapter (Morpho Blue + MetaMorpho vaults)
#   moonwell     Moonwell adapter (Base lending/borrowing)
#   hyperlend    HyperLend adapter (HyperEVM lending)
#   pendle       Pendle adapter (PT/YT markets)
#   boros        Boros adapter (fixed-rate markets, rate locking, funding swaps)
#   hyperliquid  Hyperliquid adapter (perps, spot, deposits/withdrawals)
#   polymarket   Polymarket adapter (prediction markets, trading, bridging)
#   ccxt         CCXT adapter (centralized exchanges, multi-exchange factory)
#   uniswap      Uniswap V3 adapter (concentrated liquidity)
#   projectx     ProjectX adapter (Uniswap V3 fork on HyperEVM)
#   simulation   Dry-run on fork RPCs (Gorlami)
#   promote      Promote a scratch run script into the local library

set -euo pipefail

# --- Parse --commit flag ---
SDK_REF=""

# Check for sdk-version.md file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_VERSION_FILE="$REPO_ROOT/sdk-version.md"

if [[ -f "$SDK_VERSION_FILE" ]]; then
    SDK_REF="$(tr -d '[:space:]' < "$SDK_VERSION_FILE")"
fi

# Command-line --commit overrides sdk-version.md
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --commit)
            SDK_REF="$2"
            shift 2
            ;;
        --version|-v)
            if [[ -n "$SDK_REF" ]]; then
                echo "Pinned SDK version: $SDK_REF"
            else
                echo "No SDK version pinned (no sdk-version.md file and no --commit flag)."
            fi
            exit 0
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done
set -- "${ARGS[@]+"${ARGS[@]}"}"

# --- Resolve SDK path ---
if [[ -n "${WAYFINDER_SDK_PATH:-}" ]] && [[ -d "$WAYFINDER_SDK_PATH" ]]; then
    SDK_ROOT="$WAYFINDER_SDK_PATH"
elif [[ -d "$REPO_ROOT/../wayfinder-paths-sdk" ]]; then
    SDK_ROOT="$(cd "$REPO_ROOT/../wayfinder-paths-sdk" && pwd)"
elif [[ -d "$HOME/wayfinder-paths-sdk" ]]; then
    SDK_ROOT="$HOME/wayfinder-paths-sdk"
else
    echo "ERROR: Cannot find wayfinder-paths-sdk." >&2
    echo "Tried:" >&2
    echo "  \$WAYFINDER_SDK_PATH (not set or missing)" >&2
    echo "  $REPO_ROOT/../wayfinder-paths-sdk" >&2
    echo "  $HOME/wayfinder-paths-sdk" >&2
    echo "" >&2
    echo "Set WAYFINDER_SDK_PATH or clone the SDK next to this repo." >&2
    exit 1
fi

SKILLS_DIR="$SDK_ROOT/.claude/skills"
SKILLS_DIR_GIT=".claude/skills"

HAS_GIT=0
if git -C "$SDK_ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    HAS_GIT=1
fi

MODE="fs"
if [[ -n "$SDK_REF" ]] && [[ "$HAS_GIT" -eq 1 ]]; then
    MODE="git"
fi

if [[ "$MODE" == "fs" ]] && [[ ! -d "$SKILLS_DIR" ]]; then
    echo "ERROR: Skills directory not found at $SKILLS_DIR" >&2
    echo "Tip: Set a git ref in $SDK_VERSION_FILE and ensure the SDK is a git checkout." >&2
    exit 1
fi

# --- Topic → directory mapping (bash 3.2 compatible; no assoc arrays) ---
topic_dir() {
    case "$1" in
        strategies) echo "developing-wayfinder-strategies" ;;
        setup) echo "setup" ;;
        data) echo "using-pool-token-balance-data" ;;
        brap) echo "using-brap-adapter" ;;
        aave) echo "using-aave-v3-adapter" ;;
        morpho) echo "using-morpho-adapter" ;;
        moonwell) echo "using-moonwell-adapter" ;;
        hyperlend) echo "using-hyperlend-adapter" ;;
        pendle) echo "using-pendle-adapter" ;;
        boros) echo "using-boros-adapter" ;;
        hyperliquid) echo "using-hyperliquid-adapter" ;;
        polymarket) echo "using-polymarket-adapter" ;;
        ccxt) echo "using-ccxt-adapter" ;;
        uniswap) echo "using-uniswap-adapter" ;;
        projectx) echo "using-projectx-adapter" ;;
        simulation) echo "simulation-dry-run" ;;
        promote) echo "promote-wayfinder-script" ;;
        *) return 1 ;;
    esac
}

# --- Functions ---

print_topic_header() {
    local topic="$1"
    local dir_name="$2"
    echo ""
    echo "================================================================================"
    echo "  $topic  ($dir_name)"
    echo "================================================================================"
    echo ""
}

print_file() {
    local filepath="$1"
    local relpath="${filepath#$SKILLS_DIR/}"
    echo "--- $relpath ---"
    echo ""
    cat "$filepath"
    echo ""
}

print_git_file() {
    local gitpath="$1"
    local relpath="${gitpath#$SKILLS_DIR_GIT/}"
    echo "--- $relpath ---"
    echo ""
    git -C "$SDK_ROOT" show "$SDK_REF:$gitpath"
    echo ""
    echo ""
}

list_git_md_files() {
    local gitdir="$1"
    git -C "$SDK_ROOT" ls-tree -r --name-only "$SDK_REF" "$gitdir" 2>/dev/null | awk '/\\.md$/ {print}' | sort
}

show_topic() {
    local topic="$1"
    local dir_name=""
    dir_name="$(topic_dir "$topic" 2>/dev/null || true)"
    if [[ -z "$dir_name" ]]; then
        echo "ERROR: Unknown topic '$topic'." >&2
        echo "Run with --list to see available topics." >&2
        exit 1
    fi

    local skill_dir="$SKILLS_DIR/$dir_name"
    local skill_dir_git="$SKILLS_DIR_GIT/$dir_name"

    print_topic_header "$topic" "$dir_name"

    if [[ "$MODE" == "git" ]]; then
        # Validate ref early for clearer errors
        if ! git -C "$SDK_ROOT" rev-parse --verify "$SDK_REF^{commit}" >/dev/null 2>&1; then
            echo "ERROR: SDK ref not found: $SDK_REF" >&2
            exit 1
        fi

        # Print SKILL.md first
        print_git_file "$skill_dir_git/SKILL.md"

        # Print all rules files sorted
        if git -C "$SDK_ROOT" cat-file -e "$SDK_REF:$skill_dir_git/rules" 2>/dev/null; then
            while IFS= read -r rule_path; do
                [[ -n "$rule_path" ]] && print_git_file "$rule_path"
            done < <(list_git_md_files "$skill_dir_git/rules")
        fi
    else
        if [[ ! -d "$skill_dir" ]]; then
            echo "ERROR: Skill directory not found: $skill_dir" >&2
            exit 1
        fi

        # Print SKILL.md first
        if [[ -f "$skill_dir/SKILL.md" ]]; then
            print_file "$skill_dir/SKILL.md"
        fi

        # Print all rules files sorted
        if [[ -d "$skill_dir/rules" ]]; then
            for rule_file in "$skill_dir/rules"/*.md; do
                [[ -f "$rule_file" ]] && print_file "$rule_file"
            done
        fi
    fi
}

show_list() {
    echo "Available topics:"
    echo ""
    echo "  strategies   Developing Wayfinder strategies (workflow, manifests, safety, data sources)"
    echo "  setup        First-time SDK setup"
    echo "  data         Pool, token, and balance data (pool discovery, token metadata, ledger)"
    echo "  brap         BRAP swap/bridge adapter (quotes + execution gotchas)"
    echo "  aave         Aave V3 adapter (markets, positions, execution)"
    echo "  morpho       Morpho adapter (Morpho Blue + MetaMorpho vaults)"
    echo "  moonwell     Moonwell adapter (Base lending/borrowing)"
    echo "  hyperlend    HyperLend adapter (HyperEVM lending)"
    echo "  pendle       Pendle adapter (PT/YT markets)"
    echo "  boros        Boros adapter (fixed-rate markets, rate locking, funding swaps)"
    echo "  hyperliquid  Hyperliquid adapter (perps, spot, deposits/withdrawals)"
    echo "  polymarket   Polymarket adapter (prediction markets, trading, bridging)"
    echo "  ccxt         CCXT adapter (centralized exchanges, multi-exchange factory)"
    echo "  uniswap      Uniswap V3 adapter (concentrated liquidity)"
    echo "  projectx     ProjectX adapter (Uniswap V3 fork on HyperEVM)"
    echo "  simulation   Dry-run on fork RPCs (Gorlami)"
    echo "  promote      Promote a scratch run script into the local library"
    echo ""
    echo "Usage:"
    echo "  $0 <topic>          Show docs for a topic"
    echo "  $0 --all            Show all docs"
    echo "  $0 --list           This list"
    echo "  $0 --commit <ref>   Read docs from a specific SDK git ref (no checkout)"
    echo "  $0 --version        Show the pinned SDK version"
    echo ""
    echo "SDK path: $SDK_ROOT"
    if [[ -n "$SDK_REF" ]]; then
        echo "SDK ref: $SDK_REF"
    fi
}

show_all() {
    for topic in strategies setup data brap aave morpho moonwell hyperlend pendle boros hyperliquid polymarket ccxt uniswap projectx simulation promote; do
        show_topic "$topic"
    done
}

# --- Main ---

if [[ $# -eq 0 ]]; then
    show_list
    exit 0
fi

case "$1" in
    --list|-l)
        show_list
        ;;
    --all|-a)
        show_all
        ;;
    --help|-h)
        show_list
        ;;
    *)
        # Support multiple topics: pull-sdk-ref.sh boros moonwell
        for topic in "$@"; do
            show_topic "$topic"
        done
        ;;
esac
