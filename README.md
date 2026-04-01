# Wayfinder OpenClaw Skills

OpenClaw skill pack for [Wayfinder Paths SDK](https://github.com/WayfinderFoundation/wayfinder-paths-sdk.git) — DeFi trading, yield strategies, and portfolio management via the `wayfinder` CLI.

## Install

**macOS / Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/WayfinderFoundation/wayfinder-openclaw-skill/main/install.sh | bash
```

**Windows (PowerShell):**

```powershell
git clone https://github.com/WayfinderFoundation/wayfinder-openclaw-skill.git
cd wayfinder-openclaw-skill
.\install.ps1
```

Or clone and run on any platform:

```bash
git clone https://github.com/WayfinderFoundation/wayfinder-openclaw-skill.git
cd wayfinder-openclaw-skill
./install.sh        # macOS / Linux
.\install.ps1       # Windows
```

## Update

Re-run the install script — it pulls latest and copies updated skill files:

```bash
# macOS / Linux
~/.openclaw/workspace/.repos/wayfinder-openclaw-skill/install.sh

# Windows (PowerShell)
& "$env:USERPROFILE\.openclaw\workspace\.repos\wayfinder-openclaw-skill\install.ps1"
```

## Uninstall

```bash
# macOS / Linux
~/.openclaw/workspace/.repos/wayfinder-openclaw-skill/install.sh --uninstall

# Windows (PowerShell)
& "$env:USERPROFILE\.openclaw\workspace\.repos\wayfinder-openclaw-skill\install.ps1" -Uninstall
```

All skills are auto-discovered by OpenClaw on next startup — no config changes needed.

## Upgrading from older versions

Older versions installed the skill as a single git clone (e.g. `~/.openclaw/workspace/skills/wayfinder/`). The new version uses separate folders per skill domain. Remove the old install first, then run the installer:

```bash
# macOS / Linux
rm -rf ~/.openclaw/workspace/skills/wayfinder
curl -fsSL https://raw.githubusercontent.com/WayfinderFoundation/wayfinder-openclaw-skill/main/install.sh | bash
```

```powershell
# Windows (PowerShell)
Remove-Item -Recurse -Force "$env:USERPROFILE\.openclaw\workspace\skills\wayfinder"
git clone https://github.com/WayfinderFoundation/wayfinder-openclaw-skill.git
cd wayfinder-openclaw-skill; .\install.ps1
```

The installer will replace the old single-directory layout with the new per-domain structure.

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
