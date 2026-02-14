---
name: wayfinder
description: DeFi trading, yield strategies, and portfolio management via the Wayfinder Paths CLI (`poetry run wayfinder`). Use when the user wants to check balances, swap tokens, bridge assets, trade perps, trade prediction markets (Polymarket), run automated yield strategies (stablecoin yield, basis trading, Moonwell loops, HyperLend, Boros HYPE), manage wallets, discover DeFi pools, look up token metadata, manage LP positions (Uniswap V3 / ProjectX), or execute one-off DeFi scripts. Supports Ethereum, Base, Arbitrum, Polygon, BSC, Avalanche, Plasma, and HyperEVM via protocol adapters.
metadata: {"openclaw":{"emoji":"🧭","homepage":"https://github.com/WayfinderFoundation/wayfinder-paths-sdk","requires":{"bins":["poetry"]},"install":[{"id":"brew","kind":"brew","formula":"poetry","bins":["poetry"],"label":"Install poetry"}]}}
---

# Wayfinder

DeFi trading, yield strategies, and portfolio management powered by [poetry run wayfinder Paths](https://github.com/WayfinderFoundation/wayfinder-paths-sdk).

## Conversation Style

Talk like a knowledgeable DeFi native, not like a tool manual. When a user asks about a token, protocol, or yield opportunity:

- **Lead with what matters to them** — what the thing is, how the yield works, what the risks are — in plain language. Don't open with adapter method signatures, API endpoint paths, or return types.
- **Weave commands in naturally** — present Wayfinder actions as "here's how to do it" steps, not as the main content. A swap should feel like "let me grab you a quote" not "calling the quote_swap CLI tool with parameters..."
- **Skip the plumbing** — never surface internal details like adapter module paths, `tuple[bool, Any]` return types, signing callbacks, or cache TTLs in conversation. Those exist for scripting, not chat.
- **Be direct about risks** — smart-contract risk, impermanent loss, liquidation thresholds, liquidity depth. If a pool is thin or a protocol is new, say so.
- **Don't invent data** — if you haven't fetched a rate, price, or APY, don't quote one. Fetch it first, then report what the chain says.
- **Never assume amounts** — don't pick dollar amounts, token quantities, or position sizes on the user's behalf. Always ask how much they want to deposit, swap, bridge, or trade. "How much do you want to bridge?" not "I'll bridge $25 for you."
- **Show results cleanly** — when you run commands, translate raw JSON into readable summaries (see [references/adapters.md](references/adapters.md) § Presenting Adapter Data). Users want "$1,200 USDC on Base" not `{"balance_raw": 1200000000, "decimals": 6}`.

The goal: a user should feel like they're talking to someone who deeply understands DeFi and happens to have a terminal open — not like they're reading API documentation.

## Pre-Flight Check

Before running any commands, verify that poetry run wayfinder Paths is installed and reachable:

```bash
# SDK location (override by setting WAYFINDER_SDK_PATH)
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"

# Check if wayfinder-paths-sdk directory exists
if [ ! -d "$WAYFINDER_SDK_PATH" ]; then
  echo "ERROR: wayfinder-paths-sdk is not installed at: $WAYFINDER_SDK_PATH"
  echo "Set WAYFINDER_SDK_PATH or run the First-Time Setup below."
  exit 1
fi

# Config path (override by setting WAYFINDER_CONFIG_PATH)
export WAYFINDER_CONFIG_PATH="${WAYFINDER_CONFIG_PATH:-$WAYFINDER_SDK_PATH/config.json}"

# Check if the config exists
if [ ! -f "$WAYFINDER_CONFIG_PATH" ]; then
  echo "ERROR: config not found at $WAYFINDER_CONFIG_PATH. Run the First-Time Setup below."
  exit 1
fi

# Check if the CLI is functional
cd "$WAYFINDER_SDK_PATH"
if ! poetry run wayfinder --help > /dev/null 2>&1; then
  echo "ERROR: poetry run wayfinder CLI is not working. Run 'cd $WAYFINDER_SDK_PATH && poetry install' to fix."
  exit 1
fi

echo "poetry run wayfinder Paths is installed and ready."
```

If either check fails, follow the **First-Time Setup** instructions below before proceeding.

## Quick Start

### First-Time Setup

**Important:** The SDK must be installed from GitHub via `git clone`. Do NOT install from PyPI (`pip install wayfinder-paths` will not work).

**Before starting:** You need a Wayfinder API key (format: `wk_...`). Get one at **https://strategies.wayfinder.ai**. The guided setup will prompt you for this key.

```bash
# Clone wayfinder-paths-sdk from GitHub (required — do NOT pip install)
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
if [ ! -d "$WAYFINDER_SDK_PATH" ]; then
  git clone https://github.com/WayfinderFoundation/wayfinder-paths-sdk.git "$WAYFINDER_SDK_PATH"
fi

cd "$WAYFINDER_SDK_PATH"
poetry install

# Run guided setup (creates/updates config.json + local wallets)
# You will need your API key from https://strategies.wayfinder.ai (format: wk_...)
# --mnemonic generates a BIP-39 seed phrase and stores it as `wallet_mnemonic` in config.json
# It then derives MetaMask-style EVM wallets (main + one per strategy) from that mnemonic
python3 scripts/setup.py --mnemonic
```

**Wallet security:**
- **NEVER output private keys or seed phrases into the conversation.** These are secrets — they must stay on the machine, never in chat.
- The `--mnemonic` flag stores the seed phrase in `config.json` under `wallet_mnemonic` and derives `address` + `private_key_hex` for each wallet. Without `--mnemonic`, setup generates random (non-recoverable) wallets instead.
- For a long-running bot, prefer a seed phrase stored in your backend/secret manager rather than generating random wallets on the server.
- On first-time setup, the user should retrieve the seed phrase directly from their machine or secret manager. Only offer to display the seed phrase if the user explicitly confirms they cannot access the machine to retrieve it themselves.
- See `references/setup.md` for detailed wallet setup instructions.

### Verify Setup

```bash
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
export WAYFINDER_CONFIG_PATH="${WAYFINDER_CONFIG_PATH:-$WAYFINDER_SDK_PATH/config.json}"
cd "$WAYFINDER_SDK_PATH"
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder resource wayfinder://wallets
poetry run wayfinder resource wayfinder://balances/main
```

## Commands

All commands run from `$WAYFINDER_SDK_PATH`. Returns `{"ok": true, "result": {...}}` on success. For full parameter tables see [references/commands.md](references/commands.md).

- **`resource`** — Read-only MCP resource queries (adapters, strategies, wallets, balances, tokens, Hyperliquid data). Always start here for lookups.
  `poetry run wayfinder resource wayfinder://balances/main`

- **`quote_swap`** — Get a swap/bridge quote via the BRAP aggregator (read-only, no on-chain effects). Supports same-chain swaps and cross-chain bridges across all supported networks. Always search token IDs first — never guess them. Returns the best route, expected output amount, gas estimate, and a ready-to-use `suggested_execute_request` you can pass straight into `execute`.
  `poetry run wayfinder quote_swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 500`

- **`execute`** — Execute on-chain transactions. Supports three kinds: `swap` (token swaps and cross-chain bridges via BRAP), `send` (transfer tokens to another address — use `token: "native"` + `chain_id` for native gas sends), and `hyperliquid_deposit` (bridge USDC to Hyperliquid L1 — minimum 5 USDC or funds are lost). A tx hash does NOT mean success — the SDK waits for the receipt and raises on revert. **Live — confirm with user first.** For full parameter details see [references/commands.md](references/commands.md).
  `poetry run wayfinder execute --kind swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 500`

- **`hyperliquid`** — Wait for Hyperliquid deposits or withdrawals to settle before proceeding. Use `resource wayfinder://hyperliquid/...` for read-only queries (account state, positions, funding rates, order books, mid prices, candles). For full Hyperliquid capabilities see [references/hyperliquid.md](references/hyperliquid.md).
  `poetry run wayfinder hyperliquid --action wait_for_deposit --wallet_label main --expected_increase 100`

- **`hyperliquid_execute`** — Trade perps and spot on Hyperliquid. Actions: `place_order` (market/limit), `cancel_order`, `cancel_all_orders`, `update_leverage` (cross or isolated), `update_isolated_margin`, `place_trigger_order` (TP/SL — always reduce-only), `withdraw` (USDC back to Arbitrum), `spot_transfer`, `hypercore_to_hyperevm`. Supports `--usd_amount_kind margin` (collateral) vs `notional` (position size) — clarify with the user which they mean. **Live — confirm with user first.** For full parameter details see [references/hyperliquid.md](references/hyperliquid.md).
  `poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5`

- **`polymarket`** — Read-only Polymarket queries. Actions: `search` (find markets by keyword), `status` (wallet positions, balances, open orders, PnL breakdown), `order_book` (bids/asks for a market), `prices` (current YES/NO prices), `candles` (price history). For full capabilities see [references/polymarket.md](references/polymarket.md).
  `poetry run wayfinder polymarket --action search --query "bitcoin above 100k" --limit 5`

- **`polymarket_execute`** — Trade prediction markets on Polymarket. Actions: `bridge_deposit` / `bridge_withdraw` (move USDC between Polygon wallet and Polymarket), `buy` / `sell` (market orders on YES/NO outcomes), `place_limit_order`, `cancel_order`, `cancel_all`, `redeem` (claim winnings from resolved markets). Polymarket uses Polygon USDC — bridge funds in first. **Live — confirm with user first.** For full parameter details see [references/polymarket.md](references/polymarket.md).
  `poetry run wayfinder polymarket_execute --action buy --wallet_label main --market_slug "some-slug" --outcome YES --amount_usdc 2`

- **`run_strategy`** — Strategy lifecycle: status, analyze, quote, deposit, update, withdraw, exit.
  `poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action status`

- **`wallets`** — Create wallets, annotate positions, discover cross-protocol portfolio.
  `poetry run wayfinder wallets --action discover_portfolio --wallet_label main --parallel`

- **`run_script`** — Execute sandboxed Python scripts from `.wayfinder_runs/`.
  `poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--dry-run"]' --wallet_label main`

## Safety

- **NEVER output private keys or seed phrases into the conversation.** These are secrets that must stay on the machine. Only offer to display a seed phrase if the user explicitly confirms they cannot access the machine to retrieve it themselves.
- **Execution commands are live.** Require explicit user confirmation before running `execute`, `hyperliquid_execute`, `polymarket_execute`, or any script that broadcasts transactions.
- **NEVER guess or fabricate token IDs.** Before any token operation (swap, send, quote, balance check):
  - For **native gas tokens** (ETH, HYPE): use `poetry run wayfinder resource wayfinder://tokens/gas/<chain_code>`
  - For **ERC20 tokens**: use `poetry run wayfinder resource wayfinder://tokens/search/<chain_code>/<query>` (fuzzy search) and use the exact token ID from the result
  - Do not construct IDs by combining symbols with chain names — the coingecko ID is unpredictable. Do not call `tokens/resolve` with a guessed ID — it hits a different API than search.
- **Bridging to a new chain (first time):** bridge native gas to the destination chain first (use `tokens/gas/<chain_code>` or see [references/tokens-and-pools.md](references/tokens-and-pools.md)), then bridge/swap for the target asset.
- Start with small test amounts.
- Withdraw and exit are separate steps: `withdraw` liquidates positions, `exit` transfers funds home.
- **Hyperliquid deposits must be >= 5 USDC** — amounts below 5 are lost on the bridge.
- Market order slippage is capped at 25% (`--slippage 0.25`).
- Scripts are sandboxed to the runs directory — no arbitrary file execution.
- **Sizing for perp orders:** when a user says "$X at Yx leverage", clarify: `--usd_amount_kind margin` = $X is collateral (notional = X * leverage); `--usd_amount_kind notional` = $X is position size. `--usd_amount` and `--size` are mutually exclusive.

## Common Workflows

### Check Before Trading

```bash
poetry run wayfinder resource wayfinder://balances/main
# ALWAYS look up tokens first — never guess IDs
poetry run wayfinder resource wayfinder://tokens/search/base/usdc   # Search for USDC → get token ID from result
poetry run wayfinder resource wayfinder://tokens/gas/base            # Get native ETH on Base
# Use the exact token IDs from the lookup results
poetry run wayfinder resource wayfinder://hyperliquid/prices/ETH
poetry run wayfinder quote_swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 1000
```

### Deploy a Strategy

```bash
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action status
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action deposit --main_token_amount 100 --gas_token_amount 0.01
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action update
```

### Open a Hyperliquid Position

```bash
poetry run wayfinder resource wayfinder://hyperliquid/main/state
poetry run wayfinder hyperliquid_execute --action update_leverage --wallet_label main --coin ETH --leverage 5
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5
```

### Wind Down Everything

```bash
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action withdraw
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action exit
```

## Custom Scripts

For multi-step flows, conditional logic, or protocol combinations, write a Python script using the SDK's coding interface. Scripts live in `$WAYFINDER_SDK_PATH/.wayfinder_runs/` (sandboxed).

**Before writing any script**, pull the SDK reference docs for the adapter you need:

```bash
./scripts/pull-sdk-ref.sh moonwell           # Pull docs for a specific adapter
./scripts/pull-sdk-ref.sh --list             # List available topics
```

**Available topics:** `strategies`, `setup`, `boros`, `hyperlend`, `hyperliquid`, `polymarket`, `moonwell`, `pendle`, `uniswap`, `projectx`, `data`

**Quick start:**

```python
#!/usr/bin/env python3
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter

async def main():
    adapter = get_adapter(MoonwellAdapter, "main")  # Auto-wires config + signing
    success, result = await adapter.lend(mtoken="0x...", amount=100_000_000)
    print(f"Result: {result}" if success else f"Error: {result}")

if __name__ == "__main__":
    asyncio.run(main())
```

Always test with `--dry-run` before live execution. See [references/coding-interface.md](references/coding-interface.md) for the full adapter API, examples, and patterns.

## Protocol References

- [references/commands.md](references/commands.md) — Full command reference with parameter tables and config structure
- [references/errors.md](references/errors.md) — Error taxonomy, details object, and troubleshooting
- [references/setup.md](references/setup.md) — First-time setup, configuration, and wallet management
- [references/strategies.md](references/strategies.md) — Strategy details, parameters, and workflows
- [references/adapters.md](references/adapters.md) — Adapter capabilities and method signatures
- [references/coding-interface.md](references/coding-interface.md) — Custom Python scripting with adapters
- [references/tokens-and-pools.md](references/tokens-and-pools.md) — Token IDs, supported chains, pool discovery, balance reads
- [references/hyperliquid.md](references/hyperliquid.md) — Hyperliquid trading, deposits, funding
- [references/polymarket.md](references/polymarket.md) — Polymarket markets, bridging, and trading
- [references/ccxt.md](references/ccxt.md) — Centralized exchanges (Aster/Binance/etc.) via CCXT (use carefully)
- [references/moonwell.md](references/moonwell.md) — Moonwell lending, mToken addresses, gotchas
- [references/pendle.md](references/pendle.md) — Pendle PT/YT markets, swap execution
- [references/boros.md](references/boros.md) — Boros fixed-rate markets, rate locking
- [references/uniswap.md](references/uniswap.md) — Uniswap V3 LP positions and fee collection
- [references/projectx.md](references/projectx.md) — ProjectX (V3 fork) LP positions, swaps, and strategy notes
- [references/hyperlend.md](references/hyperlend.md) — HyperLend lending, supply/withdraw flows

## Best Practices

### Security
1. Never share private keys or commit config.json
2. Start with small test amounts
3. Use dedicated wallets per strategy for isolation
4. Verify addresses before large transfers
5. Use stop losses for leverage trading

### Trading
1. Always quote before executing swaps
2. Specify chain for lesser-known tokens
3. Consider gas costs (use Base for small amounts)
4. Check balance before trades
5. Use limit orders for better prices on Hyperliquid
