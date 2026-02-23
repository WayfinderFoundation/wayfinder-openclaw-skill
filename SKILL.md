---
name: wayfinder
description: DeFi trading, yield strategies, and portfolio management via the Wayfinder Paths CLI (`poetry run wayfinder`). Use when the user wants to check balances, swap tokens, bridge assets (BRAP), trade perps (Hyperliquid), trade prediction markets (Polymarket), lend/borrow (Moonwell, HyperLend, Aave V3, Morpho), deposit/withdraw vaults (Avantis), run automated strategies, manage wallets, discover DeFi pools, manage LP positions (Uniswap V3 / ProjectX), execute one-off DeFi scripts, or compile/deploy Solidity contracts and interact with deployed contracts. Supports Ethereum, Base, Arbitrum, Polygon, BSC, Avalanche, Plasma, and HyperEVM via protocol adapters.
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

## Context Hygiene (Fetch, Don't Guess)

Keep this skill's top-level context lean. Prefer fetching source-of-truth data on demand:

- **Discovery first:** use `poetry run wayfinder resource wayfinder://adapters` and `wayfinder://adapters/{name}` for the canonical adapter list/capabilities (from adapter `manifest.yaml` + README excerpt).
- **Token correctness:** always use `wayfinder://tokens/search/...` (or `wayfinder://tokens/gas/...`) before quoting/swapping/sending. Never invent token IDs or decimals.
- **Adapter specifics:** when you're about to use an adapter, open the relevant file under `references/` first, then confirm details in the SDK adapter's `manifest.yaml` + `README.md` + `adapter.py` if needed.
- **Deep dives:** if you still need the SDK's internal workflow notes, use `./scripts/pull-sdk-ref.sh <topic>` (reads the SDK's `.claude/skills` at the pinned `sdk-version.md`) instead of expanding `SKILL.md`.
- **Load only what you need:** open a single file under `references/` for the protocol in question (don't bulk-load all references).

## Intent (Tools → Adapters → Scripts → Strategies)

The job is to complete the user's request using the Wayfinder tools. When the tool surface area is too coarse, drop down to adapters, write a small script, and keep anything reusable:

1) **Tools first:** use `resource` + `quote_swap`/`execute`/`wallets`/etc. for the quickest correct result.
2) **Adapters next:** if the request needs custom logic, read `references/<protocol>.md`, then confirm exact method names/params in the SDK adapter code.
3) **Scripts when needed:** write a minimal Python script for multi-step flows (and save it as a reusable snippet in this repo if it's broadly useful).
4) **Strategies for automation:** promote repeated, policy-driven workflows into strategies (strategies should still call adapters; they don't replace adapter understanding).

**Solidity contracts:** Wayfinder can compile/deploy Solidity contracts and interact with deployed contracts. Use `compile_contract`, `deploy_contract`, `contract_call`, and `contract_execute`, and browse locally-deployed artifacts via `wayfinder://contracts`. See `references/contracts.md` for the workflow and safety notes.

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

## Command Reference

All commands should be run from `$WAYFINDER_SDK_PATH` and require `WAYFINDER_CONFIG_PATH` (default: `$WAYFINDER_SDK_PATH/config.json`). All responses return `{"ok": true, "result": {...}}` on success or `{"ok": false, "error": {"code": "...", "message": "..."}}` on failure.

---

### `resource` — Read MCP resources by URI

Read-only access to adapters, strategies, wallets, balances, tokens, Hyperliquid market data, and local contract deployment artifacts via URI-based resources. Use `--list` to see all available resources and templates.

**Asset/data sourcing rule:** When the user asks you to look up token/pool/market/protocol data, first use Wayfinder's adapter/strategy discovery resources (`poetry run wayfinder resource wayfinder://adapters`, `wayfinder://adapters/{name}`, `wayfinder://strategies`, `wayfinder://tokens/*`). Only fall back to other methods if Wayfinder doesn't expose the required data or the user explicitly asks.

```bash
# List all available resources and templates
poetry run wayfinder resource --list
```

#### Static Resources

| URI | Description |
|-----|-------------|
| `wayfinder://adapters` | List all adapters with capabilities |
| `wayfinder://strategies` | List all strategies with adapter dependencies |
| `wayfinder://wallets` | List all configured wallets |
| `wayfinder://hyperliquid/prices` | All Hyperliquid mid prices |
| `wayfinder://hyperliquid/markets` | Perp market metadata, funding rates, and asset contexts |
| `wayfinder://hyperliquid/spot-assets` | Spot asset metadata |
| `wayfinder://contracts` | List locally-deployed contracts (artifact store) |

```bash
poetry run wayfinder resource wayfinder://adapters
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder resource wayfinder://wallets
poetry run wayfinder resource wayfinder://hyperliquid/prices
poetry run wayfinder resource wayfinder://hyperliquid/markets
poetry run wayfinder resource wayfinder://hyperliquid/spot-assets
poetry run wayfinder resource wayfinder://contracts
```

#### Resource Templates

| URI Template | Description |
|--------------|-------------|
| `wayfinder://adapters/{name}` | Describe a single adapter (e.g. `moonwell_adapter`) |
| `wayfinder://strategies/{name}` | Describe a single strategy (e.g. `stablecoin_yield_strategy`) |
| `wayfinder://wallets/{label}` | Get a single wallet by label |
| `wayfinder://balances/{label}` | Enriched multi-chain balances for a wallet |
| `wayfinder://activity/{label}` | Recent transaction activity for a wallet |
| `wayfinder://tokens/search/{chain_code}/{query}` | **Fuzzy token search** (hits `/tokens/fuzzy/`) — ALWAYS use this first |
| `wayfinder://tokens/resolve/{query}` | Resolve a token by known ID (hits `/tokens/detail/`) — only use with IDs from search |
| `wayfinder://tokens/gas/{chain_code}` | **Native gas token** for a chain (ETH, HYPE) — use for native tokens |
| `wayfinder://hyperliquid/{label}/state` | Perp positions + PnL for a wallet |
| `wayfinder://hyperliquid/{label}/spot` | Spot balances on Hyperliquid for a wallet |
| `wayfinder://hyperliquid/prices/{coin}` | Mid price for a single coin |
| `wayfinder://hyperliquid/book/{coin}` | Order book for a coin |
| `wayfinder://contracts/{chain_id}/{address}` | Get deployed contract metadata + ABI (local artifacts) |

**Token lookup order — always search or use gas endpoint first:**

```bash
# 1. For native gas tokens (ETH, HYPE): use the gas endpoint
poetry run wayfinder resource wayfinder://tokens/gas/ethereum    # ETH on Ethereum
poetry run wayfinder resource wayfinder://tokens/gas/base        # ETH on Base
poetry run wayfinder resource wayfinder://tokens/gas/hyperevm    # HYPE on HyperEVM

# 2. For ERC20 tokens: ALWAYS fuzzy search first
poetry run wayfinder resource wayfinder://tokens/search/base/usdc
poetry run wayfinder resource wayfinder://tokens/search/arbitrum/eth
poetry run wayfinder resource wayfinder://tokens/search/ethereum/weth

# 3. Then resolve with the exact ID from search results
poetry run wayfinder resource wayfinder://tokens/resolve/usd-coin-base
```

```bash
poetry run wayfinder resource wayfinder://adapters/moonwell_adapter
poetry run wayfinder resource wayfinder://strategies/stablecoin_yield_strategy
poetry run wayfinder resource wayfinder://wallets/main
poetry run wayfinder resource wayfinder://balances/main
poetry run wayfinder resource wayfinder://activity/main
poetry run wayfinder resource wayfinder://hyperliquid/main/state
poetry run wayfinder resource wayfinder://hyperliquid/main/spot
poetry run wayfinder resource wayfinder://hyperliquid/prices/ETH
poetry run wayfinder resource wayfinder://hyperliquid/book/ETH
```

---

### `wallets` — Manage wallets and discover positions

Create, annotate, and discover cross-protocol positions. Use `resource wayfinder://wallets` to list wallets and `resource wayfinder://wallets/{label}` to get a single wallet.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `"create"` \| `"annotate"` \| `"discover_portfolio"` | **Yes** | — | — |
| `label` | string | **create** | — | Must be non-empty; duplicate labels are idempotent |
| `wallet_label` | string | **annotate, discover_portfolio** | — | Or use `wallet_address` |
| `wallet_address` | string | No | — | Alternative to `wallet_label` |
| `protocol` | string | **annotate** | — | Protocol name for annotation |
| `annotate_action` | string | **annotate** | — | Action being annotated |
| `tool` | string | **annotate** | — | Tool name for annotation |
| `status` | string | **annotate** | — | Status for annotation |
| `chain_id` | int | No | — | Optional per-chain query override (only used by some protocols) |
| `details` | string (JSON) | No | — | Extra metadata for annotation |
| `protocols` | string (JSON) | No | — | Filter `discover_portfolio` to specific protocols |
| `parallel` | bool | No | `false` | **Required if querying >= 3 protocols** without a `protocols` filter |
| `include_zero_positions` | bool | No | `false` | Include empty positions in portfolio |

Supported protocols for `discover_portfolio`: `hyperliquid`, `hyperlend`, `moonwell`, `morpho`, `aave`, `boros`, `pendle`, `polymarket`.

```bash
poetry run wayfinder wallets --action create --label my_new_strategy
poetry run wayfinder wallets --action discover_portfolio --wallet_label main --parallel
poetry run wayfinder wallets --action discover_portfolio --wallet_label main --protocols '["hyperliquid","moonwell"]'
```

**Validations:**
- `create`: `label` must be non-empty. Duplicate labels return the existing wallet (idempotent).
- `annotate`/`discover_portfolio`: must resolve a wallet address from `wallet_label` or `wallet_address`.
- `annotate`: all of `protocol`, `annotate_action`, `tool`, `status` are required.
- `discover_portfolio` with >= 3 protocols requires `parallel=true` or an explicit `protocols` filter (returns `requires_confirmation` otherwise).

---

### `quote_swap` — Get a swap/bridge quote (read-only)

Returns a quote for swapping or bridging tokens. No on-chain effects.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with an address |
| `from_token` | string | **Yes** | — | Token ID from search results (e.g. `usd-coin-base`). **Always search first** — do not guess. |
| `to_token` | string | **Yes** | — | Token ID from search results. **Always search first.** |
| `amount` | string | **Yes** | — | Human-readable amount (e.g. `"500"`). Must be positive, Decimal-parseable, and > 0 after scaling to token decimals |
| `slippage_bps` | int | No | `50` | Slippage tolerance in basis points (50 = 0.5%) |
| `recipient` | string | No | — | Defaults to sender address |
| `include_calldata` | bool | No | `false` | Include raw calldata in response |

**Always resolve token IDs before calling quote_swap.** Run `poetry run wayfinder resource wayfinder://tokens/search/<chain>/<symbol>` for each token first, then use the exact ID from the result. Do not pass raw symbols or guessed `symbol-chain` strings — they may resolve incorrectly or fail.

**Note:** Native gas tokens (e.g., unwrapped ETH) may fail in swaps with `from_token_address: null`. Use the wrapped ERC20 version instead (e.g., WETH). Search for it: `resource wayfinder://tokens/search/<chain>/weth`.

**Bridging to a new chain for the first time:** the wallet needs **native gas on the destination chain** before it can do anything. Bridge the native gas token (e.g. ETH) to the destination chain first, then bridge or swap for the target token. Use the native token IDs from the supported-chains table below (e.g. `ethereum-base` for ETH on Base).
- Use the native token IDs from the supported-chains table below when bridging gas (e.g. `ethereum-base` for ETH on Base, `plasma-plasma` for PLASMA on Plasma).

```bash
poetry run wayfinder quote_swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 500
poetry run wayfinder quote_swap --wallet_label main --from_token "USDC-base" --to_token "ETH-base" --amount 1000 --slippage_bps 100
```

**Errors:** `not_found` (wallet), `invalid_wallet`, `token_error`, `invalid_token` (missing chain_id/address), `invalid_amount`, `quote_error`.

---

### `execute` — Execute on-chain transactions

Execute swaps, token sends, or Hyperliquid deposits. **This broadcasts transactions** and can move real funds.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `kind` | `swap` \| `send` \| `hyperliquid_deposit` | **Yes** | — | Operation type |
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with private key |
| `amount` | string | **Yes** | — | Human-readable amount (e.g. `"500"`) |
| `from_token` | string | **swap** | — | Source token ID. **Always search first.** |
| `to_token` | string | **swap** | — | Destination token ID. **Always search first.** |
| `slippage_bps` | int | No | `50` | Swap only; basis points |
| `deadline_seconds` | int | No | `300` | Swap only |
| `recipient` | string | **send** | — | Recipient address |
| `token` | string | **send** | — | Token ID (or `"native"` with `chain_id`). **Always search first.** |
| `chain_id` | int | No | — | Required for `send` when `token="native"` |

**Hyperliquid deposit validations (critical):**
- Amount **must be >= 5 USDC** (deposits below 5 are lost on the bridge).
- Hard-codes: token = Arbitrum USDC, recipient = `HYPERLIQUID_BRIDGE_ADDRESS`, chain = Arbitrum (42161).

**Additional runtime validations:**
- Wallet must have both `address` and `private_key_hex`.
- Token resolution must succeed (chain_id + token address required).
- Swap quotes must return a `best_quote` with `calldata`.
- For USDT-style tokens, a zero-allowance reset transaction is sent before approval.

```bash
# Swap
poetry run wayfinder execute --kind swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 500

# Send tokens
poetry run wayfinder execute --kind send --wallet_label main --token usd-coin-base --recipient 0x... --amount 100

# Hyperliquid deposit (min 5 USDC)
poetry run wayfinder execute --kind hyperliquid_deposit --wallet_label main --amount 100
```

---

### `hyperliquid` — Wait for Hyperliquid deposits/withdrawals

Wait for deposits or withdrawals to settle on Hyperliquid. For read-only queries (user state, prices, order books), use the `resource` command with Hyperliquid URIs.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `"wait_for_deposit"` \| `"wait_for_withdrawal"` | **Yes** | — | — |
| `wallet_label` | string | No | — | Or use `wallet_address` |
| `wallet_address` | string | No | — | Alternative to `wallet_label` |
| `expected_increase` | string | No | — | Expected USDC increase for deposit |
| `timeout_s` | int | No | `120` | Timeout for `wait_for_deposit` |
| `poll_interval_s` | int | No | `5` | Poll interval for wait actions |
| `lookback_s` | int | No | `5` | For `wait_for_withdrawal` |
| `max_poll_time_s` | int | No | `900` | Max wait for `wait_for_withdrawal` (15 min) |

```bash
poetry run wayfinder hyperliquid --action wait_for_deposit --wallet_label main --expected_increase 100
poetry run wayfinder hyperliquid --action wait_for_withdrawal --wallet_label main
```

**Read-only queries via resources:**

```bash
# Perp positions + PnL
poetry run wayfinder resource wayfinder://hyperliquid/main/state

# Spot balances
poetry run wayfinder resource wayfinder://hyperliquid/main/spot

# All mid prices
poetry run wayfinder resource wayfinder://hyperliquid/prices

# Single coin price
poetry run wayfinder resource wayfinder://hyperliquid/prices/ETH

# Market metadata + funding rates
poetry run wayfinder resource wayfinder://hyperliquid/markets

# Spot asset metadata
poetry run wayfinder resource wayfinder://hyperliquid/spot-assets

# Order book
poetry run wayfinder resource wayfinder://hyperliquid/book/ETH
```

---

### `hyperliquid_execute` — Hyperliquid trading operations

Place/cancel orders, update leverage, and withdraw USDC. **These operations are live** and can place real orders / move real funds.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `place_order` \| `cancel_order` \| `update_leverage` \| `withdraw` \| `spot_to_perp_transfer` \| `perp_to_spot_transfer` | **Yes** | — | — |
| `wallet_label` | string | **Yes** | — | Must resolve to wallet with private key |
| `coin` | string | **place_order, cancel_order, update_leverage** | — | Or use `asset_id`. Strips `-perp`/`_perp` suffixes automatically |
| `asset_id` | int | No | — | Direct asset ID (alternative to `coin`) |
| `is_spot` | bool | No | — | `true` for spot orders, `false` for perp. **Must be explicit for place_order.** |
| `order_type` | `market` \| `limit` | No | `market` | — |
| `is_buy` | bool | **place_order** | — | `true` or `false` |
| `size` | float | No | — | **Mutually exclusive with `usd_amount`**; coin units |
| `usd_amount` | float | **spot_to_perp_transfer, perp_to_spot_transfer** | — | **Mutually exclusive with `size`** for orders; required for transfers |
| `usd_amount_kind` | string | **when `usd_amount` is used** | — | `notional` or `margin` |
| `leverage` | int | **when `usd_amount_kind=margin`; update_leverage** | — | Must be positive |
| `price` | float | **limit orders** | — | Must be positive |
| `slippage` | float | No | `0.01` | Market orders only; 0–0.25 (25% cap) |
| `reduce_only` | flag | No | `false` | `--reduce_only` / `--no-reduce_only` |
| `cloid` | string | No | — | Client order ID |
| `order_id` | int | **cancel_order** | — | Or use `cancel_cloid` |
| `cancel_cloid` | string | No | — | Alternative to `order_id` for cancel |
| `is_cross` | flag | No | `true` | `--is_cross` / `--no-is_cross` |
| `amount_usdc` | float | **withdraw** | — | USDC amount for withdraw |
| `builder_fee_tenths_bp` | int | No | — | Falls back to config default |

**Key validations for `place_order`:**
- Exactly one of `size` or `usd_amount` (not both, not neither).
- If `usd_amount` is used, `usd_amount_kind` is required.
- If `usd_amount_kind=margin`, then `leverage` is required.
- Limit orders require `price` > 0.
- After lot-size rounding, size must still be > 0.
- Builder fee is mandatory (auto-configured; approval is auto-submitted if needed).

```bash
# Market buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5

# Spot buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin HYPE --is_spot true --is_buy true --usd_amount 20

# Limit sell
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_buy false --size 0.1 --price 4000 --order_type limit

# Close position (reduce-only)
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_buy false --size 0.5 --reduce_only

# Update leverage
poetry run wayfinder hyperliquid_execute --action update_leverage --wallet_label main --coin ETH --leverage 5

# Cancel order
poetry run wayfinder hyperliquid_execute --action cancel_order --wallet_label main --coin ETH --order_id 12345

# Withdraw USDC
poetry run wayfinder hyperliquid_execute --action withdraw --wallet_label main --amount_usdc 100

# Transfer USDC between spot and perp wallets
poetry run wayfinder hyperliquid_execute --action spot_to_perp_transfer --wallet_label main --usd_amount 50
poetry run wayfinder hyperliquid_execute --action perp_to_spot_transfer --wallet_label main --usd_amount 50
```

---

### `polymarket` — Polymarket market + account reads

Read-only access to Polymarket markets, prices, order books, and user status.

**Tradability filter:** a market can be "found" but not tradable. Filter for `enableOrderBook`, `acceptingOrders`, `active`, `closed != true`, and non-empty `clobTokenIds`.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `status` \| `search` \| `trending` \| `get_market` \| `get_event` \| `price` \| `order_book` \| `price_history` \| `bridge_status` \| `open_orders` | **Yes** | — | — |
| `wallet_label` | string | No | — | Resolves `account` from config; required for `open_orders` |
| `wallet_address` | string | No | — | Alternative to `wallet_label` for account-based reads |
| `account` | string | No | — | Direct account address (alternative to wallet inputs) |
| `include_orders` | bool | No | `true` | `status` only |
| `include_activity` | bool | No | `false` | `status` only |
| `activity_limit` | int | No | `50` | `status` only |
| `include_trades` | bool | No | `false` | `status` only |
| `trades_limit` | int | No | `50` | `status` only |
| `positions_limit` | int | No | `500` | `status` only |
| `max_positions_pages` | int | No | `10` | `status` only |
| `query` | string | **search** | — | Query string for fuzzy market search |
| `limit` | int | No | `10` | `search`, `trending` |
| `page` | int | No | `1` | `search` |
| `keep_closed_markets` | bool | No | `false` | `search` |
| `rerank` | bool | No | `true` | `search` |
| `offset` | int | No | `0` | `trending` |
| `market_slug` | string | **get_market** | — | Market slug |
| `event_slug` | string | **get_event** | — | Event slug |
| `token_id` | string | **price, order_book, price_history** | — | Polymarket CLOB token id (optional for `open_orders` filter) |
| `side` | `BUY` \| `SELL` | No | `BUY` | `price` only |
| `interval` | string | No | `"1d"` | `price_history` only |
| `start_ts` | int | No | — | `price_history` only (unix seconds) |
| `end_ts` | int | No | — | `price_history` only (unix seconds) |
| `fidelity` | int | No | — | `price_history` only |

**Action-specific requirements:**
- `status`, `bridge_status`: require an `account` (via `--account`, `--wallet_address`, or `--wallet_label`).
- `open_orders`: requires `--wallet_label` and a wallet with `private_key_hex` in `config.json` (Level-2 auth). Optional: `--token_id` to filter.

```bash
# Search markets
poetry run wayfinder polymarket --action search --query "bitcoin above 100k" --limit 5

# User status (positions + balances)
poetry run wayfinder polymarket --action status --wallet_label main

# CLOB order book
poetry run wayfinder polymarket --action order_book --token_id 123456
```

---

### `polymarket_execute` — Polymarket execution (bridge + orders)

Execute Polymarket actions (bridging and trading). **This command is live (no dry-run flag).**

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `bridge_deposit` \| `bridge_withdraw` \| `buy` \| `sell` \| `close_position` \| `place_limit_order` \| `cancel_order` \| `redeem_positions` | **Yes** | — | — |
| `wallet_label` | string | **Yes** | — | Wallet must include `address` and `private_key_hex` in config |
| `from_chain_id` | int | No | `137` | `bridge_deposit` only |
| `from_token_address` | string | No | Polygon USDC | `bridge_deposit` only |
| `amount` | float | **bridge_deposit** | — | Amount of USDC to deposit |
| `recipient_address` | string | No | sender | `bridge_deposit` only |
| `amount_usdce` | float | **bridge_withdraw** | — | Amount of USDC.e to withdraw |
| `to_chain_id` | int | No | `137` | `bridge_withdraw` only |
| `to_token_address` | string | No | Polygon USDC | `bridge_withdraw` only |
| `recipient_addr` | string | No | sender | `bridge_withdraw` only |
| `token_decimals` | int | No | `6` | Bridge token decimals |
| `market_slug` | string | No | — | Used by `buy`, `sell`, `close_position` |
| `outcome` | string \| int | No | `"YES"` | Used with `market_slug` (e.g. `YES`/`NO`) |
| `token_id` | string | No | — | Alternative to `market_slug` for `buy`, `sell`, `place_limit_order` |
| `amount_usdc` | float | **buy** | — | Buy amount in USDC |
| `shares` | float | **sell** | — | Shares to sell |
| `side` | `BUY` \| `SELL` | No | `BUY` | `place_limit_order` only |
| `price` | float | **place_limit_order** | — | Limit price (0–1) |
| `size` | float | **place_limit_order** | — | Order size (shares) |
| `post_only` | bool | No | `false` | `place_limit_order` only |
| `order_id` | string | **cancel_order** | — | — |
| `condition_id` | string | **redeem_positions** | — | Required for `redeem_positions`; also accepted by `close_position` as a fallback |

**Approvals + API creds:** handled automatically before order placement (idempotent).

**Collateral:** Polymarket CLOB trading collateral is **USDC.e on Polygon**, not native Polygon USDC. Use `bridge_deposit` / `bridge_withdraw` to convert. These methods prefer a fast on-chain BRAP swap on Polygon when possible (sender == recipient); otherwise they fall back to the Polymarket Bridge service (`method: "polymarket_bridge"` in the result) and you can monitor via `polymarket --action bridge_status`.

**Trade semantics:**
- `buy` uses `amount_usdc` as **collateral ($) to spend**
- `sell` uses `shares` as **shares to sell**

**Always require explicit user confirmation before running `polymarket_execute`.**

```bash
# Bridge USDC -> USDC.e collateral (Polymarket)
poetry run wayfinder polymarket_execute --action bridge_deposit --wallet_label main --amount 10

# Buy shares by market slug + outcome
poetry run wayfinder polymarket_execute --action buy --wallet_label main --market_slug "some-market-slug" --outcome YES --amount_usdc 2

# Close a position (sells full size; resolves token_id from market slug)
poetry run wayfinder polymarket_execute --action close_position --wallet_label main --market_slug "some-market-slug" --outcome YES
```

---

### `run_strategy` — Strategy lifecycle management

Run strategy actions: check status, analyze, quote, deposit, update, withdraw, or exit.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `strategy` | string | **Yes** | — | Strategy directory name; must have `manifest.yaml` |
| `action` | `status` \| `analyze` \| `snapshot` \| `policy` \| `quote` \| `deposit` \| `update` \| `withdraw` \| `exit` | **Yes** | — | — |
| `amount_usdc` | float | No | `1000.0` | **Read-only analysis:** hypothetical deposit for `analyze`, `snapshot`, `quote` |
| `amount` | string | No | — | Generic amount parameter (strategy-specific) |
| `main_token_amount` | string | **deposit** | — | **Actual deposit:** amount of strategy's deposit token |
| `gas_token_amount` | float | No | `0.0` | **Actual deposit:** optional gas token amount |

**Amount parameter rules:**
- **For read-only analysis** (`analyze`, `snapshot`, `quote`): use `--amount_usdc`
- **For actual deposits** (`deposit`): use `--main_token_amount` (required) + optionally `--gas_token_amount`
- The deposit token varies by strategy (USDC on Base for stablecoin_yield, USDC on Arbitrum for boros_hype, etc.)

```bash
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action status
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action analyze --amount_usdc 100
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action quote --amount_usdc 100
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action deposit --main_token_amount 100 --gas_token_amount 0.01
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action update
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action withdraw
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action exit
```

**Errors:** `invalid_request` (empty strategy), `not_found` (missing manifest), `not_supported` (strategy lacks the method), `strategy_error` (runtime exception).

**Note:** `withdraw` liquidates positions but funds stay in the strategy wallet. `exit` transfers funds from the strategy wallet back to the main wallet. These are separate steps.

---

### `run_script` — Execute sandboxed Python scripts

Run a local Python script in a subprocess. Scripts must live inside the runs directory (`$WAYFINDER_RUNS_DIR` or `.wayfinder_runs/`).

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `script_path` | string | **Yes** | — | Must be `.py`, must exist, **must be inside the runs directory** |
| `args` | string | No | — | Arguments passed to the script (JSON list) |
| `timeout_s` | int | No | `600` | Clamped to min 1 second |
| `env` | string | No | — | Additional env vars for subprocess (JSON object) |
| `wallet_label` | string | No | — | For profile annotation |

**Validations:**
- Script path must resolve to inside the runs directory (sandboxed — no arbitrary file execution).
- Must be a `.py` file.
- Must exist on disk.
- Output is truncated to 20,000 chars.

```bash
# Recommended: implement --dry-run / --force in your script and pass it via --args
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--dry-run"]' --wallet_label main
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--force"]' --wallet_label main

# With timeout
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --wallet_label main --timeout_s 120
```

---

### `compile_contract` — Compile Solidity contracts (read-only)

Compile a Solidity `.sol` file with OpenZeppelin import support.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `source_path` | string | **Yes** | — | Must be a `.sol` file inside the repo (or scratch dir inside the repo) |
| `contract_name` | string | No | — | Optional: validate/select a specific contract from the compilation output |

```bash
poetry run wayfinder compile_contract --source_path .wayfinder_runs/MyToken.sol
poetry run wayfinder compile_contract --source_path .wayfinder_runs/MyToken.sol --contract_name MyToken
```

---

### `deploy_contract` — Deploy a Solidity contract (fund-moving)

Compile, deploy, and optionally verify a Solidity contract. **This broadcasts a transaction**.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with `address` + `private_key_hex` |
| `source_path` | string | **Yes** | — | Solidity `.sol` file inside the repo |
| `contract_name` | string | **Yes** | — | Contract name to deploy from compilation output |
| `chain_id` | int | **Yes** | — | Target chain id |
| `constructor_args` | string (JSON) | No | — | JSON array string (e.g. `'["0xabc...", 1000]'`) |
| `verify` | bool | No | `true` | Verification uses Etherscan V2 (API key required); deploy works without it |

```bash
# Deploy (no constructor args)
poetry run wayfinder deploy_contract --wallet_label main --source_path .wayfinder_runs/Counter.sol --contract_name Counter --chain_id 8453

# Deploy with constructor args + skip verification
poetry run wayfinder deploy_contract --wallet_label main --source_path .wayfinder_runs/MyToken.sol --contract_name MyToken --chain_id 8453 --constructor_args '[1000000]' --verify false
```

**Artifacts:** successful deploys are persisted under `.wayfinder_runs/contracts/...` and can be browsed via `wayfinder://contracts`.

---

### `contract_get_abi` — Fetch contract ABI (read-only)

Fetch ABI for a deployed contract via Etherscan V2 (optionally resolves common proxy patterns first).

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `chain_id` | int | **Yes** | — | Target chain id |
| `contract_address` | string | **Yes** | — | Contract address |
| `resolve_proxy` | bool | No | `true` | Attempt proxy implementation resolution (EIP-1967 / ZeppelinOS / EIP-897) |

```bash
poetry run wayfinder contract_get_abi --chain_id 8453 --contract_address 0xabc123...
```

---

### `contract_call` — Read from a deployed contract (read-only)

Read contract state via `eth_call`.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `chain_id` | int | **Yes** | — | Target chain id |
| `contract_address` | string | **Yes** | — | Contract address |
| `function_name` | string | No | — | Use only for non-overloaded functions |
| `function_signature` | string | No | — | Prefer for overloaded functions (e.g. `balanceOf(address)`) |
| `args` | string (JSON) | No | — | JSON array string |
| `value_wei` | int | No | `0` | For payable calls (rare for `eth_call`) |
| `from_address` | string | No | — | Optional `from` for `eth_call` |
| `wallet_label` | string | No | — | Alternative to `from_address` (uses wallet address only; no signing) |
| `abi` | string (JSON) | No | — | Inline ABI JSON (minimal ABI recommended) |
| `abi_path` | string | No | — | Path to a `.json` ABI file inside this repo |

**ABI resolution:** if you omit `abi` and `abi_path`, the tool checks the local artifact store first (for contracts deployed via `deploy_contract`), then falls back to Etherscan V2 (requires API key + verified contract).

```bash
poetry run wayfinder contract_call --chain_id 8453 --contract_address 0xabc123... --function_signature "balanceOf(address)" --args '["0x..."]'
```

---

### `contract_execute` — Execute a contract write (fund-moving)

Encode calldata and broadcast a state-changing transaction. **This moves funds / changes state.**

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with `address` + `private_key_hex` |
| `chain_id` | int | **Yes** | — | Target chain id |
| `contract_address` | string | **Yes** | — | Contract address |
| `function_name` | string | No | — | Use only for non-overloaded functions |
| `function_signature` | string | No | — | Prefer for overloaded functions |
| `args` | string (JSON) | No | — | JSON array string |
| `value_wei` | int | No | `0` | ETH value to send for payable functions |
| `abi` | string (JSON) | No | — | Inline ABI JSON (minimal ABI recommended) |
| `abi_path` | string | No | — | Path to a `.json` ABI file inside this repo |
| `wait_for_receipt` | bool | No | `true` | If `false`, return after broadcast |

**Safety:** always require explicit user confirmation before running `contract_execute`.

```bash
poetry run wayfinder contract_execute --wallet_label main --chain_id 8453 --contract_address 0xabc123... --function_signature "transfer(address,uint256)" --args '["0x...", 123]'
```

---

## Config Structure

Config is loaded from `$WAYFINDER_CONFIG_PATH` (default: `$WAYFINDER_SDK_PATH/config.json`).

```json
{
  "system": {
    "api_base_url": "https://strategies.wayfinder.ai/api/v1",
    "api_key": "wk_..."
  },
  "strategy": {
    "rpc_urls": {
      "1": ["https://eth.llamarpc.com"],
      "42161": ["https://arb1.arbitrum.io/rpc"],
      "8453": ["https://mainnet.base.org"],
      "999": ["https://rpc.hyperliquid.xyz/evm"]
    }
  },
  "wallets": [
    {
      "label": "main",
      "address": "0x...",
      "private_key_hex": "0x..."
    }
  ],
  "ccxt": {
    "aster": { "apiKey": "", "secret": "" },
    "binance": { "apiKey": "", "secret": "" }
  }
}
```

- `system.api_key` falls back to `$WAYFINDER_API_KEY` env var.
- `strategy.rpc_urls` is optional; if a chain id is not configured, on-chain calls use Wayfinder's RPC proxy at `system.api_base_url` (auth via your API key).
- Most write operations require a wallet entry with `address` + `private_key_hex`.

## Available Strategies

| Strategy | Status | Chain | Token | Risk | Description |
|----------|--------|-------|-------|------|-------------|
| `basis_trading_strategy` | stable | Hyperliquid | USDC | Medium | Delta-neutral funding rate capture with matched spot/perp positions |
| `boros_hype_strategy` | stable | Arbitrum + HyperEVM + Hyperliquid | HYPE/USDC | Medium | Multi-leg HYPE yield with fixed-rate funding lock via Boros |
| `hyperlend_stable_yield_strategy` | stable | HyperEVM | USDT0 | Low | Stablecoin yield optimization on HyperLend with rotation policy |
| `moonwell_wsteth_loop_strategy` | stable | Base | USDC/WETH/wstETH | Medium-High | Leveraged wstETH carry trade via Moonwell looping |
| `stablecoin_yield_strategy` | wip | Base | USDC | Low | Auto-rotates across best stablecoin pools on Base |
| `projectx_thbill_usdc_strategy` | wip | HyperEVM | THBILL/USDC | Medium | Concentrated liquidity market making on ProjectX (V3 fork) |

**Reference**: [references/strategies.md](references/strategies.md)

## Available Adapters

| Adapter | Protocol | Capabilities |
|---------|----------|-------------|
| `aave_v3_adapter` | Aave V3 (multi-chain) | `market.list`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.toggle`, `rewards.claim` |
| `balance_adapter` | EVM wallets | `balance.read`, `transfer.main_to_strategy`, `transfer.strategy_to_main`, `transfer.send` |
| `boros_adapter` | Boros (Arbitrum) | `market.read`, `market.quote`, `position.open`, `position.close`, `collateral.deposit`, `collateral.withdraw` |
| `brap_adapter` | Cross-chain swaps | `swap.quote`, `swap.execute`, `swap.compare_routes`, `bridge.quote`, `gas.estimate` |
| `ccxt_adapter` | CEXes (Aster/Binance) | `exchange.factory` |
| `hyperlend_adapter` | HyperLend (HyperEVM) | `market.stable_markets`, `market.assets_view`, `market.rate_history`, `lending.lend`, `lending.unlend` |
| `hyperliquid_adapter` | Hyperliquid DEX | `market.read`, `market.meta`, `market.funding`, `market.candles`, `market.orderbook`, `order.execute`, `order.cancel`, `position.manage`, `transfer`, `withdraw` |
| `ledger_adapter` | Local bookkeeping | `ledger.read`, `ledger.record`, `ledger.snapshot` |
| `moonwell_adapter` | Moonwell (Base) | `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.set`, `collateral.remove`, `rewards.claim`, `position.read`, `market.apy`, `market.collateral_factor` |
| `morpho_adapter` | Morpho Blue + MetaMorpho | `market.list`, `market.read`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `vault.list`, `vault.deposit`, `vault.withdraw`, `rewards.read`, `rewards.claim` |
| `multicall_adapter` | EVM batch calls | `multicall.aggregate` |
| `pendle_adapter` | Pendle | `pendle.markets.read`, `pendle.market.snapshot`, `pendle.swap.quote`, `pendle.swap.execute`, `pendle.convert.quote`, `pendle.positions.database`, and more |
| `polymarket_adapter` | Polymarket | `market.read`, `market.search`, `market.orderbook`, `market.candles`, `position.read`, `order.execute`, `order.cancel`, `bridge.deposit`, `bridge.withdraw` |
| `pool_adapter` | DeFi Llama | `pool.read`, `pool.discover` |
| `projectx_adapter` | ProjectX (V3 fork) | `projectx.pool.overview`, `projectx.positions.list`, `projectx.liquidity.mint`, `projectx.liquidity.increase`, `projectx.liquidity.decrease`, `projectx.fees.collect`, `projectx.swap.exact_in` |
| `token_adapter` | Token metadata | `token.read`, `token.price`, `token.gas` |
| `uniswap_adapter` | Uniswap V3 | `uniswap.liquidity.add`, `uniswap.liquidity.increase`, `uniswap.liquidity.remove`, `uniswap.fees.collect`, `uniswap.position.get`, `uniswap.positions.list`, `uniswap.fees.uncollected`, `uniswap.pool.get` |

**Reference**: [references/adapters.md](references/adapters.md)

## Token ID Format — ALWAYS SEARCH FIRST

**CRITICAL: NEVER guess or construct token IDs.** Always look up the correct token using the appropriate endpoint before using it in any command.

**Three token endpoints — know which to use:**
- **`tokens/search`** → fuzzy search (hits `/blockchain/tokens/fuzzy/`) — **always use this first for ERC20 tokens**
- **`tokens/resolve`** → exact lookup (hits `/blockchain/tokens/detail/`) — only use with an ID you got from search
- **`tokens/gas`** → native gas tokens (hits `/blockchain/tokens/gas/`) — **use for ETH, HYPE, and other native tokens**

Token IDs use `<coingecko_id>-<chain_code>` format (NOT symbol-chain):
- `usd-coin-base` (USDC on Base) — NOT `usdc-base`
- `ethereum-arbitrum` (ETH on Arbitrum) — NOT `ETH-arbitrum`
- `usdt0-arbitrum` (USDT on Arbitrum) — NOT `USDT-arbitrum`
- `hyperliquid-hyperevm` (HYPE on HyperEVM) — NOT `HYPE-hyperevm`

**You cannot reliably guess coingecko IDs from token symbols.** For example, ETH's coingecko ID is `ethereum`, USDC's is `usd-coin`, HYPE's is `hyperliquid`. These are not derivable from the symbol alone.

**If the user gives a contract address (or you're certain of it)**, use the chain-scoped address format directly — no search needed:
`<chain_code>_<address>` e.g. `base_0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913`

This works anywhere a token ID is accepted and is the most reliable way to reference a specific contract. Prefer this format when you already know the address from a previous lookup, reference docs, or the user.

**Native gas tokens** are best discovered via `tokens/gas/<chain_code>`. Use the table below as a convenient reference, but prefer `tokens/gas` when in doubt.

Valid chain codes (common): `ethereum`, `base`, `arbitrum`, `polygon`, `bsc`, `avalanche`, `plasma`, `hyperevm`. Note: `mainnet` is NOT a valid chain code — use `ethereum` instead.

### Supported Chains

| Chain | ID | Code | Symbol | Native Token ID |
|------|----|------|--------|-----------------|
| Ethereum | 1 | `ethereum` | ETH | `ethereum-ethereum` |
| Base | 8453 | `base` | ETH | `ethereum-base` |
| Arbitrum | 42161 | `arbitrum` | ETH | `ethereum-arbitrum` |
| Polygon | 137 | `polygon` | POL | `polygon-ecosystem-token-polygon` |
| BSC | 56 | `bsc` | BNB | `binancecoin-bsc` |
| Avalanche | 43114 | `avalanche` | AVAX | `avalanche-avalanche` |
| Plasma | 9745 | `plasma` | PLASMA | `plasma-plasma` |
| HyperEVM | 999 | `hyperevm` | HYPE | `hyperliquid-hyperevm` |

CLI commands use human-readable amounts (`--amount 500`); adapter scripts use raw int units (`500_000_000` for 500 USDC).

**Before every swap, send, or token operation:**
```bash
# For native gas tokens (ETH, HYPE):
poetry run wayfinder resource wayfinder://tokens/gas/<chain_code>

# For ERC20 tokens — REQUIRED: fuzzy search first
poetry run wayfinder resource wayfinder://tokens/search/<chain_code>/<symbol>
# Then use the exact token ID from the search result
```

## Sizing for Perp Orders

When a user says "$X at Yx leverage", clarify:
- `--usd_amount_kind margin` = $X is collateral (notional = X * leverage)
- `--usd_amount_kind notional` = $X is position size

`--usd_amount` and `--size` are mutually exclusive. When using `--usd_amount` with `--usd_amount_kind margin`, `--leverage` is required.

## Safety

- **NEVER output private keys or seed phrases into the conversation.** These are secrets that must stay on the machine. Only offer to display a seed phrase if the user explicitly confirms they cannot access the machine to retrieve it themselves.
- **Execution commands are live.** Require explicit user confirmation before running `execute`, `hyperliquid_execute`, `polymarket_execute`, or any script that broadcasts transactions.
- **NEVER guess or fabricate token IDs.** Before any token operation (swap, send, quote, balance check):
  - For **native gas tokens** (ETH, HYPE): use `poetry run wayfinder resource wayfinder://tokens/gas/<chain_code>`
  - For **ERC20 tokens**: use `poetry run wayfinder resource wayfinder://tokens/search/<chain_code>/<query>` (fuzzy search) and use the exact token ID from the result
  - Do not construct IDs by combining symbols with chain names — the coingecko ID is unpredictable. Do not call `tokens/resolve` with a guessed ID — it hits a different API than search.
- **Bridging to a new chain (first time):** bridge native gas to the destination chain first (use the supported-chains table or `tokens/gas/<chain_code>`), then bridge/swap for the target asset.
- Start with small test amounts.
- Withdraw and exit are separate steps: `withdraw` liquidates positions, `exit` transfers funds home.
- **Hyperliquid deposits must be >= 5 USDC** — amounts below 5 are lost on the bridge.
- Market order slippage is capped at 25% (`--slippage 0.25`).
- Scripts are sandboxed to the runs directory — no arbitrary file execution.

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

## Custom Scripts via the Coding Interface

**For any operation that goes beyond a single CLI command, you SHOULD write a custom Python script.** The `wayfinder-paths-sdk` provides a full coding interface — use it whenever you need multi-step flows, conditional logic, batched operations, or protocol combinations.

### When to Write a Script

- **Multi-step atomic flows** — operations that must succeed together
- **Custom logic** — conditional execution based on market state
- **Batched operations** — multiple protocol interactions in sequence
- **Protocol combinations** — bridging multiple adapters in one flow
- **Complex calculations** — position sizing, rebalancing, PnL analysis
- **Anything the user asks that isn't a single CLI call**

### Script Location

All generated scripts **must** be saved to `.wayfinder_runs/` inside the SDK directory:

```
$WAYFINDER_SDK_PATH/.wayfinder_runs/my_script.py
```

This directory is sandboxed — `run_script` only executes scripts inside it. Create it if it doesn't exist:

```bash
mkdir -p "$WAYFINDER_SDK_PATH/.wayfinder_runs"
```

### Referencing the SDK Source

Before writing any script, **pull the detailed reference docs** for the adapter or strategy you're working with. The SDK ships comprehensive skill docs covering method signatures, gotchas, unit conventions, and execution patterns.

**Use the reference script:**

```bash
# List available topics
./scripts/pull-sdk-ref.sh --list

# Pull docs for specific adapters (supports multiple topics)
./scripts/pull-sdk-ref.sh moonwell
./scripts/pull-sdk-ref.sh boros hyperliquid
./scripts/pull-sdk-ref.sh strategies

# Pull everything
./scripts/pull-sdk-ref.sh --all

# Check the pinned SDK version
./scripts/pull-sdk-ref.sh --version

# Override with a specific commit
./scripts/pull-sdk-ref.sh --commit abc123 moonwell
```

**Available topics:** `strategies`, `setup`, `data`, `brap`, `aave`, `morpho`, `moonwell`, `hyperlend`, `pendle`, `boros`, `hyperliquid`, `polymarket`, `uniswap`, `projectx`, `simulation`, `promote`

The SDK ref is tracked in `.sdk-version` (default: `main`). The pull script checks out that ref when reading docs, then restores the SDK to its previous state.

**Always run this before writing a script** — the docs cover critical details like:
- Exact method signatures and required parameters
- Unit conventions (raw base units vs human-readable, wei vs native)
- Gotchas (e.g., `unlend()` takes mToken amounts not underlying, withdrawal cooldowns, funding sign conventions)
- Execution patterns and safety rails
- Token/contract addresses

You can also read the adapter source code directly:

```
$WAYFINDER_SDK_PATH/wayfinder_paths/adapters/          # All adapter implementations
$WAYFINDER_SDK_PATH/wayfinder_paths/mcp/scripting.py   # get_adapter() helper
$WAYFINDER_SDK_PATH/wayfinder_paths/strategies/        # Strategy implementations
```

### Quick Start

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

### Testing Workflow

**Always test before live execution.** Follow this workflow:

1. **Write** the script to `.wayfinder_runs/`
2. **Safe run** — run the script in a non-fund-moving mode first (recommended: implement `--dry-run` / `--force` in your script and pass it via `--args`):
   ```bash
   cd "$WAYFINDER_SDK_PATH"
   poetry run wayfinder run_script --script_path .wayfinder_runs/my_script.py --args '["--dry-run"]' --wallet_label main
   ```
3. **Review** the output. Verify the operations, amounts, and addresses are correct.
4. **Live execution** — only after confirming the safe run looks right, run with `--force`:
   ```bash
   poetry run wayfinder run_script --script_path .wayfinder_runs/my_script.py --args '["--force"]' --wallet_label main
   ```

**Never skip the safe-run step for scripts that move funds.**

**Reference**: [references/coding-interface.md](references/coding-interface.md) — Full adapter API reference, examples, and patterns

## Protocol References

- [references/commands.md](references/commands.md) — Full command reference with parameter tables and config structure
- [references/errors.md](references/errors.md) — Error taxonomy, details object, and troubleshooting
- [references/setup.md](references/setup.md) — First-time setup, configuration, and wallet management
- [references/strategies.md](references/strategies.md) — Strategy details, parameters, and workflows
- [references/adapters.md](references/adapters.md) — Adapter capabilities and method signatures
- [references/coding-interface.md](references/coding-interface.md) — Custom Python scripting with adapters
- [references/tokens-and-pools.md](references/tokens-and-pools.md) — Token IDs, supported chains, pool discovery, balance reads
- [references/simulation-dry-run.md](references/simulation-dry-run.md) — Fork-mode simulation (Gorlami) and dry-run patterns
- [references/hyperliquid.md](references/hyperliquid.md) — Hyperliquid trading, deposits, funding
- [references/polymarket.md](references/polymarket.md) — Polymarket markets, bridging, and trading
- [references/ccxt.md](references/ccxt.md) — Centralized exchanges (Aster/Binance/etc.) via CCXT (use carefully)
- [references/moonwell.md](references/moonwell.md) — Moonwell lending, mToken addresses, gotchas
- [references/aave-v3.md](references/aave-v3.md) — Aave V3 lending/borrowing (markets + positions + execution)
- [references/morpho.md](references/morpho.md) — Morpho Blue + MetaMorpho (markets/vaults + rewards + execution)
- [references/pendle.md](references/pendle.md) — Pendle PT/YT markets, swap execution
- [references/boros.md](references/boros.md) — Boros fixed-rate markets, rate locking
- [references/uniswap.md](references/uniswap.md) — Uniswap V3 LP positions and fee collection
- [references/projectx.md](references/projectx.md) — ProjectX (V3 fork) LP positions, swaps, and strategy notes
- [references/hyperlend.md](references/hyperlend.md) — HyperLend lending, supply/withdraw flows

## Error Handling

All errors return structured JSON: `{"ok": false, "error": {"code": "...", "message": "...", "details": ...}}`.

### Error Categories

#### Validation Errors — bad input, fixable by the caller

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `invalid_request` | Missing or invalid required parameters | Omitted `action`, empty `strategy`, missing `token_id` for balance query | Tell the user which parameter is missing and show the correct command format |
| `invalid_wallet` | Wallet missing `address` or `private_key_hex` | Wallet label exists but entry is incomplete; read-only wallet used for execution | Ask the user to check their config.json wallet entry has both fields |
| `invalid_token` | Token resolution failed — missing `chain_id` or contract `address` after lookup | Typo in token ID, token not indexed, ambiguous symbol without chain qualifier | Suggest running `resource wayfinder://tokens/search/<chain>/<query>` and show the closest matches |
| `invalid_amount` | Amount not parseable, not positive, or zero after decimal scaling | Non-numeric string, negative value, amount like `0.000000001` that rounds to 0 for a low-decimal token | Show the parsed value and the token's decimals so the user understands the rounding |

#### Resource Errors — something doesn't exist

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `not_found` | Directory, manifest, wallet, or resource not found | Strategy name typo, adapter not installed, wallet label doesn't match config | List available resources (`resource wayfinder://strategies`) so the user can pick the right name |
| `not_supported` | Strategy does not implement the requested action | Calling `withdraw` on a strategy that only supports `status`/`deposit` | Show which actions the strategy does support (from its manifest) |
| `requires_confirmation` | Operation needs explicit user confirmation before proceeding | `discover_portfolio` across >= 3 protocols without `--parallel` flag | Explain the operation scope and ask the user to confirm or pass `--parallel` |

#### API & Integration Errors — upstream service failures

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `token_error` | Token adapter API call failed | Wayfinder API down, network timeout, invalid API key | Check API key validity; retry after a moment; show the raw error message from details |
| `quote_error` | Swap/bridge quote generation failed | No liquidity for pair, amount too small for routing, bridge route unavailable | Suggest trying a different amount, checking if the pair is supported, or using a different route |
| `balance_error` | Balance query failed | RPC node down, rate-limited, invalid chain_id | Retry; if persistent, check RPC URL configuration |
| `activity_error` | Activity/transaction history query failed | Indexer lag, unsupported chain for activity | Inform user the history service may be temporarily unavailable |
| `price_error` | Price lookup failed | Token not priced by CoinGecko, API rate limit | Note that the token may be too new or illiquid for price data; balances are still valid without prices |

#### Execution Errors — on-chain failures

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `executor_error` | On-chain transaction failed | Insufficient gas, contract revert, nonce conflict, allowance issue | Show the revert reason if available; check gas balance; for USDT-style tokens, mention the zero-allowance reset |
| `strategy_error` | Strategy runtime exception | Unhandled edge case in strategy code, external dependency failure mid-execution | Show the exception message; suggest checking `status` before retrying |

### Error Details Object

The `details` field varies by error code and may contain:

| Field | Present On | Description |
|-------|-----------|-------------|
| `parameter` | `invalid_request` | The specific parameter that failed validation |
| `wallet_label` | `invalid_wallet`, `not_found` | The wallet label that was looked up |
| `query` | `invalid_token` | The token query that failed resolution |
| `candidates` | `invalid_token` | Fuzzy match candidates when available |
| `raw_amount` | `invalid_amount` | The original amount string provided |
| `scaled_amount` | `invalid_amount` | The amount after decimal scaling (shows why it became zero) |
| `decimals` | `invalid_amount` | Token decimals used for scaling |
| `tx_hash` | `executor_error` | Transaction hash if the tx was submitted before failing |
| `revert_reason` | `executor_error` | Decoded revert reason from the contract |
| `strategy` | `strategy_error`, `not_supported` | Strategy name |
| `supported_actions` | `not_supported` | List of actions the strategy does implement |
| `protocols` | `requires_confirmation` | The protocols that would be queried |
| `upstream_error` | `token_error`, `quote_error`, `balance_error`, `activity_error`, `price_error` | Raw error message from the upstream service |

### Presenting Errors to Users

When an error is returned, follow this pattern:

1. **Translate the code** — don't show raw error codes. Map to plain language (e.g., `invalid_token` -> "I couldn't find that token").
2. **Include the actionable fix** — every error above has a recovery path. Always tell the user what to do next.
3. **Show relevant details** — if `details.candidates` exists, list the closest token matches. If `details.revert_reason` exists, explain what the contract rejected.
4. **Offer to retry** — for transient errors (`token_error`, `balance_error`, `quote_error`, `activity_error`, `price_error`), offer to retry. For validation errors, show the corrected command.

### Common User-Facing Issues

| Symptom | Error Code | Resolution |
|---------|-----------|------------|
| "Missing config" | `not_found` | Run setup or create `config.json` manually |
| "strategy_wallet not configured" | `invalid_wallet` | Add wallet with matching label to config.json |
| "Minimum deposit" | `invalid_amount` | Check strategy minimum requirements (e.g., Hyperliquid >= 5 USDC) |
| "Insufficient gas" | `executor_error` | Fund wallet with native gas token for the target chain |
| "Token not found" | `invalid_token` | Use `resource wayfinder://tokens/search/<chain>/<query>` to find the correct coingecko ID |
| "No quote available" | `quote_error` | Try a different amount, check pair liquidity, or use an alternative route |
| "Nonce too low" | `executor_error` | A previous transaction is pending; wait or speed it up |
| "Allowance reset needed" | `executor_error` | For USDT-style tokens, the CLI auto-resets allowance — retry if it was a transient RPC issue |
| "Rate limited" | `token_error` / `balance_error` | Wait a few seconds and retry the request |

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
