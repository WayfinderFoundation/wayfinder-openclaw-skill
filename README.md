# Wayfinder OpenClaw Skills

OpenClaw (Moltbot) skill provider for [Wayfinder Paths SDK](https://github.com/WayfinderFoundation/wayfinder-paths-sdk.git) — DeFi trading, yield strategies, and portfolio management via the `wayfinder` CLI.

## Skills

| Skill | Description |
|-------|-------------|
| [wayfinder](wayfinder/SKILL.md) | DeFi trading, yield strategies, portfolio management, perps, and protocol adapters (Hyperliquid, Polymarket, Moonwell, Pendle, Uniswap, ProjectX, etc.) |

## Setup

```bash
# Clone the SDK (or set WAYFINDER_SDK_PATH to your existing clone)
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
if [ ! -d "$WAYFINDER_SDK_PATH" ]; then
  git clone https://github.com/WayfinderFoundation/wayfinder-paths-sdk.git "$WAYFINDER_SDK_PATH"
fi

cd "$WAYFINDER_SDK_PATH"

# Create/update config.json + wallets
python3 scripts/setup.py

# Verify
export WAYFINDER_CONFIG_PATH="${WAYFINDER_CONFIG_PATH:-$WAYFINDER_SDK_PATH/config.json}"
poetry run wayfinder resource wayfinder://strategies
```

See [references/setup.md](wayfinder/references/setup.md) for detailed instructions.
