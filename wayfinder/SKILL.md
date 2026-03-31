---
name: wayfinder
description: DeFi trading, yield strategies, and portfolio management via the Wayfinder Paths CLI. Swap tokens, bridge assets cross-chain, send crypto, check wallet balances, look up token prices, manage wallets, and discover portfolio positions. Covers resource URIs, quote_swap, execute, and wallets commands. Use for exchange tokens, convert between chains, transfer funds, check how much I have, find token addresses, get swap quotes, on-chain execution, create wallet, portfolio discovery, DeFi, crypto trading.
---

# Wayfinder

The primary Wayfinder skill — covers the foundational CLI commands: reading on-chain and off-chain data via `resource` URIs, managing wallets, quoting token swaps/bridges, and executing on-chain transactions. All commands should be run from `$WAYFINDER_SDK_PATH` and require `WAYFINDER_CONFIG_PATH` (default: `$WAYFINDER_SDK_PATH/config.json`). All responses return `{"ok": true, "result": {...}}` on success or `{"ok": false, "error": {"code": "...", "message": "..."}}` on failure.

---

## `resource` — Read MCP resources by URI

Read-only access to adapters, strategies, wallets, balances, tokens, Hyperliquid market data, and local contract deployment artifacts via URI-based resources. Use `--list` to see all available resources and templates.

**Asset/data sourcing rule:** When the user asks you to look up token/pool/market/protocol data, first use Wayfinder's adapter/strategy discovery resources (`poetry run wayfinder resource wayfinder://adapters`, `wayfinder://adapters/{name}`, `wayfinder://strategies`, `wayfinder://tokens/*`). Only fall back to other methods if Wayfinder doesn't expose the required data or the user explicitly asks.

```bash
# List all available resources and templates
poetry run wayfinder resource --list
```

### Static Resources

| URI | Description |
|-----|-------------|
| `wayfinder://adapters` | List all adapters with capabilities |
| `wayfinder://strategies` | List all strategies with adapter dependencies |
| `wayfinder://wallets` | List all configured wallets |
| `wayfinder://hyperliquid/prices` | All Hyperliquid mid prices |
| `wayfinder://hyperliquid/markets` | Perp market metadata, funding rates, and asset contexts |
| `wayfinder://hyperliquid/spot-assets` | Spot asset metadata |
| `wayfinder://contracts` | List locally-deployed contracts (artifact store) |
| `wayfinder://delta-lab/symbols` | Delta Lab basis symbols (for market screens) |

```bash
poetry run wayfinder resource wayfinder://adapters
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder resource wayfinder://wallets
poetry run wayfinder resource wayfinder://hyperliquid/prices
poetry run wayfinder resource wayfinder://hyperliquid/markets
poetry run wayfinder resource wayfinder://hyperliquid/spot-assets
poetry run wayfinder resource wayfinder://contracts
poetry run wayfinder resource wayfinder://delta-lab/symbols
```

### Resource Templates

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
| `wayfinder://delta-lab/{symbol}/basis` | Delta Lab: map an asset symbol to its basis group/root symbol (see `wayfinder-delta-lab` skill) |
| `wayfinder://delta-lab/{symbol}/timeseries/{series}/{lookback_days}/{limit}` | Delta Lab: timeseries snapshot for one symbol + series (see `wayfinder-delta-lab` skill) |

**Delta Lab market screens & historical data:** see the `wayfinder-delta-lab` skill for full documentation on asset lookup, screens, timeseries, APY sources, and delta-neutral pairs.

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

## `wallets` — Manage wallets and discover positions

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
| `chain_id` | TEXT | No | — | Optional per-chain query override (numeric chain id, coerced to int) |
| `details` | string (JSON) | No | — | Extra metadata for annotation |
| `protocols` | string (JSON) | No | — | Filter `discover_portfolio` to specific protocols |
| `parallel` | flag | No | `false` | `--parallel` / `--no-parallel`. **Required if querying >= 3 protocols** without a `protocols` filter |
| `include_zero_positions` | flag | No | `false` | `--include_zero_positions` / `--no-include_zero_positions` |
| `remote` | flag | No | `false` | `--remote` / `--no-remote` |
| `policies` | string (JSON) | No | `[]` | Policy list for wallet creation (JSON array of objects) |

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

## `quote_swap` — Get a swap/bridge quote (read-only)

Returns a quote for swapping or bridging tokens. No on-chain effects.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with an address |
| `from_token` | string | **Yes** | — | Token ID from search results (e.g. `usd-coin-base`). **Always search first** — do not guess. |
| `to_token` | string | **Yes** | — | Token ID from search results. **Always search first.** |
| `amount` | string | **Yes** | — | Human-readable amount (e.g. `"500"`). Must be positive, Decimal-parseable, and > 0 after scaling to token decimals |
| `slippage_bps` | int | No | `50` | Slippage tolerance in basis points (50 = 0.5%) |
| `recipient` | string | No | — | Defaults to sender address |
| `include_calldata` | flag | No | `false` | `--include_calldata` / `--no-include_calldata` |

**Always resolve token IDs before calling quote_swap.** Run `poetry run wayfinder resource wayfinder://tokens/search/<chain>/<symbol>` for each token first, then use the exact ID from the result. Do not pass raw symbols or guessed `symbol-chain` strings — they may resolve incorrectly or fail.

**Note:** Native gas tokens (e.g., unwrapped ETH) may fail in swaps with `from_token_address: null`. Use the wrapped ERC20 version instead (e.g., WETH). Search for it: `resource wayfinder://tokens/search/<chain>/weth`.

- **Before any on-chain operation**, check the wallet has native gas on that chain using `wayfinder://balances/{label}`.
- If bridging to a new chain for the first time: bridge gas first. If you need the native token ID, look it up via `wayfinder://tokens/search/{chain_code}/{query}` (or `wayfinder://tokens/gas/{chain_code}` for native gas metadata).

```bash
poetry run wayfinder quote_swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 500
```

**Errors:** `not_found` (wallet), `invalid_wallet`, `token_error`, `invalid_token` (missing chain_id/address), `invalid_amount`, `quote_error`.

---

## `execute` — Execute on-chain transactions

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
| `chain_id` | TEXT | No | — | Required for `send` when `token="native"` (numeric chain id, coerced to int) |

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

## Common Workflows

### Check Before Trading

```bash
poetry run wayfinder resource wayfinder://balances/main
# ALWAYS look up tokens first — never guess IDs
poetry run wayfinder resource wayfinder://tokens/search/base/usdc   # Search for USDC -> get token ID from result
poetry run wayfinder resource wayfinder://tokens/gas/base            # Get native ETH on Base
# Use the exact token IDs from the lookup results
poetry run wayfinder resource wayfinder://hyperliquid/prices/ETH
poetry run wayfinder quote_swap --wallet_label main --from_token usd-coin-base --to_token ethereum-base --amount 1000
```

### Open a Hyperliquid Position (Prerequisites)

Before placing a Hyperliquid perp order, ensure the wallet has funds deposited:

```bash
poetry run wayfinder resource wayfinder://hyperliquid/main/state
poetry run wayfinder hyperliquid_execute --action update_leverage --wallet_label main --coin ETH --leverage 5
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5
```

### Wind Down

```bash
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action withdraw
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action exit
```

---

## References

- [Commands Reference](references/commands.md)
- [Token & Pool Discovery](references/tokens-and-pools.md)
- [Delta Lab Market Data](../delta-lab/SKILL.md)
- [Error Reference](references/errors.md)
- [Setup Guide](references/setup.md)
- [Simulation & Dry-Run](references/simulation-dry-run.md)
