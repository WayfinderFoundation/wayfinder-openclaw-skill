# Command Reference

All commands should be run from `$WAYFINDER_SDK_PATH` and require `WAYFINDER_CONFIG_PATH` (default: `$WAYFINDER_SDK_PATH/config.json`). All responses return `{"ok": true, "result": {...}}` on success or `{"ok": false, "error": {"code": "...", "message": "..."}}` on failure.

---

## `resource` — Read MCP resources by URI

Read-only access to adapters, strategies, wallets, balances, tokens, and Hyperliquid market data via URI-based resources. Use `--list` to see all available resources and templates.

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

```bash
poetry run wayfinder resource wayfinder://adapters
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder resource wayfinder://wallets
poetry run wayfinder resource wayfinder://hyperliquid/prices
poetry run wayfinder resource wayfinder://hyperliquid/markets
poetry run wayfinder resource wayfinder://hyperliquid/spot-assets
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
| `chain_id` | string | No | — | — |
| `details` | string (JSON) | No | — | Extra metadata for annotation |
| `protocols` | string (JSON) | No | — | Filter `discover_portfolio` to specific protocols |
| `parallel` | bool | No | `false` | **Required if querying >= 3 protocols** without a `protocols` filter |
| `include_zero_positions` | bool | No | `false` | Include empty positions in portfolio |

Supported protocols for `discover_portfolio`: `hyperliquid`, `hyperlend`, `moonwell`, `boros`, `pendle`.

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
| `chain_id` | string | No | — | Required for `send` when `token="native"` |
| `force` | flag | No | `false` | Do not rely on this as a "dry-run vs live" gate. Treat `execute` as live and require explicit user confirmation before calling it. |

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

## `hyperliquid` — Wait for Hyperliquid deposits/withdrawals

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

## `hyperliquid_execute` — Hyperliquid trading operations

Place/cancel orders, update leverage, and withdraw USDC. **These operations are live** and can place real orders / move real funds.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `place_order` \| `cancel_order` \| `update_leverage` \| `withdraw` \| `spot_to_perp_transfer` \| `perp_to_spot_transfer` | **Yes** | — | — |
| `wallet_label` | string | **Yes** | — | Must resolve to wallet with private key |
| `coin` | string | **place_order, cancel_order, update_leverage** | — | Or use `asset_id`. Strips `-perp`/`_perp` suffixes automatically |
| `asset_id` | string | No | — | Direct asset ID (alternative to `coin`) |
| `is_spot` | string | No | — | `true` for spot orders, `false` for perp. **Must be explicit for place_order.** |
| `order_type` | `market` \| `limit` | No | `market` | — |
| `is_buy` | string | **place_order** | — | `true` or `false` |
| `size` | string | No | — | **Mutually exclusive with `usd_amount`**; coin units |
| `usd_amount` | string | No | — | **Mutually exclusive with `size`**; USD amount |
| `usd_amount_kind` | string | **when `usd_amount` is used** | — | `notional` or `margin` |
| `leverage` | string | **when `usd_amount_kind=margin`; update_leverage** | — | Must be positive |
| `price` | string | **limit orders** | — | Must be positive |
| `slippage` | float | No | `0.01` | Market orders only; 0–0.25 (25% cap) |
| `reduce_only` | flag | No | `false` | `--reduce_only` / `--no-reduce_only` |
| `cloid` | string | No | — | Client order ID |
| `order_id` | string | **cancel_order** | — | Or use `cancel_cloid` |
| `cancel_cloid` | string | No | — | Alternative to `order_id` for cancel |
| `is_cross` | flag | No | `true` | `--is_cross` / `--no-is_cross` |
| `amount_usdc` | string | **withdraw, transfers** | — | USDC amount for withdraw or transfers |
| `builder_fee_tenths_bp` | string | No | — | Falls back to config default |
| `force` | flag | No | `false` | Do not rely on this as a "dry-run vs live" gate. Treat `hyperliquid_execute` as live and require explicit user confirmation before calling it. |

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
poetry run wayfinder hyperliquid_execute --action spot_to_perp_transfer --wallet_label main --amount_usdc 50
poetry run wayfinder hyperliquid_execute --action perp_to_spot_transfer --wallet_label main --amount_usdc 50
```

---

## `polymarket` — Polymarket market + account reads

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

## `polymarket_execute` — Polymarket execution (bridge + orders)

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

## `run_strategy` — Strategy lifecycle management

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

## `run_script` — Execute sandboxed Python scripts

Run a local Python script in a subprocess. Scripts must live inside the runs directory (`$WAYFINDER_RUNS_DIR` or `.wayfinder_runs/`).

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `script_path` | string | **Yes** | — | Must be `.py`, must exist, **must be inside the runs directory** |
| `args` | string | No | — | Arguments passed to the script (JSON list) |
| `timeout_s` | int | No | `600` | Clamped to min 1 second |
| `env` | string | No | — | Additional env vars for subprocess (JSON object) |
| `wallet_label` | string | No | — | For profile annotation |
| `force` | flag | No | `false` | Do not rely on this as a "dry-run vs live" gate. Prefer implementing `--dry-run` / `--force` inside your script and passing it via `--args`. |

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

## Config Structure

Config is loaded from `$WAYFINDER_CONFIG_PATH` (default: `$WAYFINDER_SDK_PATH/config.json`).

```json
{
  "system": {
    "api_base_url": "https://strategies.wayfinder.ai/api/v1",
    "api_key": "wk_..."
  },
  "strategy": {
    "rpc_urls": {}
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
