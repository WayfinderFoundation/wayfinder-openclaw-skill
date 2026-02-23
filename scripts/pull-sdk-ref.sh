#!/usr/bin/env bash
# pull-sdk-ref.sh — Pull reference docs from wayfinder-paths-sdk skill files.
#
# Usage:
#   ./pull-sdk-ref.sh <topic>          Show docs for a specific topic
#   ./pull-sdk-ref.sh --list           List available topics
#   ./pull-sdk-ref.sh --all            Show all reference docs
#   ./pull-sdk-ref.sh --version        Show the pinned SDK version from sdk-version.md
#
# Topics:
#   contracts    Contract compilation/deployment/interactions
#   simulation   Simulation patterns (Gorlami forks)
#   strategies   Developing Wayfinder strategies (workflow, manifests, safety, data sources)
#   setup        First-time SDK setup
#   adapters     Adapter overview (protocol integrations, composing adapters)
#   brap         BRAP adapter (cross-chain quotes/execution)
#   boros        Boros adapter (fixed-rate markets, rate locking, funding swaps)
#   ccxt         CCXT adapter (centralized exchanges, multi-exchange factory)
#   coding       Coding interface (custom Python scripts for complex DeFi ops)
#   hyperlend    HyperLend adapter (HyperEVM lending)
#   hyperliquid  Hyperliquid adapter (perps, spot, deposits/withdrawals)
#   polymarket   Polymarket adapter (prediction markets, trading, bridging)
#   moonwell     Moonwell adapter (Base lending/borrowing)
#   pendle       Pendle adapter (PT/YT markets)
#   uniswap      Uniswap V3 adapter (concentrated liquidity)
#   projectx     ProjectX adapter (Uniswap V3 fork on HyperEVM)
#   aave         Aave V3 adapter (multi-chain lending)
#   morpho       Morpho adapter (Blue + MetaMorpho)
#   data         Pool, token, and balance data (pool discovery, token metadata, ledger)

set -euo pipefail

# --- Parse flags ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SDK_VERSION_FILE="$REPO_ROOT/sdk-version.md"
SDK_COMMIT=""

if [[ -f "$SDK_VERSION_FILE" ]]; then
    SDK_COMMIT="$(tr -d '[:space:]' < "$SDK_VERSION_FILE")"
fi

ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --version|-v)
            if [[ -n "$SDK_COMMIT" ]]; then
                echo "Pinned SDK version: $SDK_COMMIT"
            else
                echo "No SDK version pinned (no sdk-version.md file)."
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
elif [[ -d "$HOME/Documents/wayfinder-paths-sdk" ]]; then
    SDK_ROOT="$HOME/Documents/wayfinder-paths-sdk"
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

# --- Warn if SDK ref differs from pinned version ---
if [[ -n "$SDK_COMMIT" ]]; then
    CURRENT_REF="$(cd "$SDK_ROOT" && git rev-parse HEAD 2>/dev/null)"
    PINNED_FULL="$(cd "$SDK_ROOT" && git rev-parse --verify -q "$SDK_COMMIT^{commit}" 2>/dev/null || true)"
    if [[ -z "$PINNED_FULL" ]]; then
        echo "NOTE: Pinned SDK ref not found in local clone: $SDK_COMMIT" >&2
        echo "      Reading from the SDK's current ref instead." >&2
    elif [[ "$CURRENT_REF" != "$PINNED_FULL" ]]; then
        echo "NOTE: SDK is at $(echo "$CURRENT_REF" | cut -c1-12) but pinned version is $SDK_COMMIT" >&2
        echo "      Reading from the SDK's current ref." >&2
    fi
fi

SKILLS_DIR="$SDK_ROOT/.claude/skills"

if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "ERROR: Skills directory not found at $SKILLS_DIR" >&2
    exit 1
fi

# --- Functions ---

dir_for_topic() {
    local topic="$1"
    case "$topic" in
        adapters) echo "using-adapters" ;;
        strategies) echo "developing-wayfinder-strategies" ;;
        setup) echo "setup" ;;
        contracts) echo "contract-development" ;;
        simulation) echo "simulation-dry-run" ;;
        brap) echo "using-brap-adapter" ;;
        boros) echo "using-boros-adapter" ;;
        ccxt) echo "using-ccxt-adapter" ;;
        coding) echo "coding-interface" ;;
        hyperlend) echo "using-hyperlend-adapter" ;;
        hyperliquid) echo "using-hyperliquid-adapter" ;;
        polymarket) echo "using-polymarket-adapter" ;;
        moonwell) echo "using-moonwell-adapter" ;;
        pendle) echo "using-pendle-adapter" ;;
        uniswap) echo "using-uniswap-adapter" ;;
        projectx) echo "using-projectx-adapter" ;;
        aave) echo "using-aave-v3-adapter" ;;
        morpho) echo "using-morpho-adapter" ;;
        data) echo "using-pool-token-balance-data" ;;
        *) echo "" ;;
    esac
}

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

show_topic() {
    local topic="$1"
    local dir_name
    dir_name="$(dir_for_topic "$topic")"

    if [[ -z "$dir_name" ]]; then
        echo "ERROR: Unknown topic '$topic'." >&2
        echo "Run with --list to see available topics." >&2
        exit 1
    fi

    local skill_dir="$SKILLS_DIR/$dir_name"

    if [[ ! -d "$skill_dir" ]]; then
        echo "ERROR: Skill directory not found: $skill_dir" >&2
        exit 1
    fi

    print_topic_header "$topic" "$dir_name"

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
}

show_list() {
    echo "Available topics:"
    echo ""
    echo "  contracts    Contract compilation/deployment/interactions"
    echo "  simulation   Simulation patterns (Gorlami forks)"
    echo "  adapters     Adapter overview (protocol integrations, composing adapters)"
    echo "  strategies   Developing Wayfinder strategies (workflow, manifests, safety, data sources)"
    echo "  setup        First-time SDK setup"
    echo "  brap         BRAP adapter (cross-chain quotes/execution)"
    echo "  boros        Boros adapter (fixed-rate markets, rate locking, funding swaps)"
    echo "  ccxt         CCXT adapter (centralized exchanges, multi-exchange factory)"
    echo "  coding       Coding interface (custom Python scripts for complex DeFi ops)"
    echo "  hyperlend    HyperLend adapter (HyperEVM lending)"
    echo "  hyperliquid  Hyperliquid adapter (perps, spot, deposits/withdrawals)"
    echo "  polymarket   Polymarket adapter (prediction markets, trading, bridging)"
    echo "  moonwell     Moonwell adapter (Base lending/borrowing)"
    echo "  pendle       Pendle adapter (PT/YT markets)"
    echo "  uniswap      Uniswap V3 adapter (concentrated liquidity)"
    echo "  projectx     ProjectX adapter (Uniswap V3 fork on HyperEVM)"
    echo "  aave         Aave V3 adapter (multi-chain lending)"
    echo "  morpho       Morpho adapter (Blue + MetaMorpho)"
    echo "  data         Pool, token, and balance data (pool discovery, token metadata, ledger)"
    echo ""
    echo "Usage:"
    echo "  $0 <topic>          Show docs for a topic"
    echo "  $0 --all            Show all docs"
    echo "  $0 --list           This list"
    echo "  $0 --version        Show the pinned SDK version"
    echo ""
    echo "SDK path: $SDK_ROOT"
    if [[ -n "$SDK_COMMIT" ]]; then
        echo "SDK ref: $SDK_COMMIT"
    fi
}

show_all() {
    for topic in contracts simulation adapters strategies setup brap boros ccxt coding hyperlend hyperliquid polymarket moonwell pendle uniswap projectx aave morpho data; do
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
