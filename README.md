# Wayfinder OpenClaw Skills

OpenClaw skill pack for [Wayfinder Paths SDK](https://github.com/WayfinderFoundation/wayfinder-paths-sdk.git) — DeFi trading, yield strategies, and portfolio management via the `wayfinder` CLI.

## Install

```bash
git clone https://github.com/user/wayfinder-openclaw-skill.git ~/.agents/skills/wayfinder
```

All 10 skills are auto-discovered by OpenClaw on next startup — no config changes needed.

## Skills

| Skill | Description |
|-------|-------------|
| wayfinder | DeFi trading, swaps, bridges, wallets, portfolio management |
| wayfinder-hyperliquid | Perpetual futures and spot trading on Hyperliquid |
| wayfinder-polymarket | Prediction market trading on Polymarket |
| wayfinder-coding-interface | Custom Python scripts using Wayfinder SDK adapters |
| wayfinder-contracts | Compile, deploy, and interact with Solidity smart contracts |
| wayfinder-strategies | Automated DeFi yield strategies |
| wayfinder-aave | Aave V3 lending and borrowing |
| wayfinder-lido | Lido liquid staking (stETH/wstETH) |
| wayfinder-lending-protocols | Moonwell, Morpho, Euler V2, HyperLend, Ethena, SparkLend |
| wayfinder-other-protocols | Boros, Pendle, Uniswap, ProjectX, Aerodrome, Avantis, EigenCloud, ether.fi, CCXT |

## SDK Setup

```bash
# Clone the SDK (or set WAYFINDER_SDK_PATH to your existing clone)
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
if [ ! -d "$WAYFINDER_SDK_PATH" ]; then
  git clone https://github.com/WayfinderFoundation/wayfinder-paths-sdk.git "$WAYFINDER_SDK_PATH"
fi

cd "$WAYFINDER_SDK_PATH"

# Create/update config.json + wallets
python3 scripts/setup.py --mnemonic

# Verify
export WAYFINDER_CONFIG_PATH="${WAYFINDER_CONFIG_PATH:-$WAYFINDER_SDK_PATH/config.json}"
poetry run wayfinder resource wayfinder://strategies
```

See [skills/wayfinder/references/setup.md](skills/wayfinder/references/setup.md) for detailed instructions.
