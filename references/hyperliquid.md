# Hyperliquid

## Overview

Hyperliquid is a decentralized perpetuals exchange with spot trading. The Hyperliquid adapter provides comprehensive trading capabilities.

- **Type**: `HYPERLIQUID`
- **Module**: `wayfinder_paths.adapters.hyperliquid_adapter.adapter.HyperliquidAdapter`
- **Capabilities**: `market.read`, `market.meta`, `market.funding`, `market.candles`, `market.orderbook`, `order.execute`, `order.cancel`, `order.trigger`, `position.manage`, `position.isolated_margin`, `transfer`, `transfer.spot`, `transfer.hypercore_to_hyperevm`, `withdraw`

## Market Data (via Resources)

```bash
# For any of the commands make sure you are in the SDK dir
cd "${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"

# Perp positions + PnL
poetry run wayfinder resource wayfinder://hyperliquid/main/state

# Spot balances on Hyperliquid
poetry run wayfinder resource wayfinder://hyperliquid/main/spot

# All mid prices
poetry run wayfinder resource wayfinder://hyperliquid/prices

# Single coin price
poetry run wayfinder resource wayfinder://hyperliquid/prices/ETH

# Funding rates + metadata for all assets
poetry run wayfinder resource wayfinder://hyperliquid/markets

# Spot asset metadata
poetry run wayfinder resource wayfinder://hyperliquid/spot-assets

# Order book
poetry run wayfinder resource wayfinder://hyperliquid/book/ETH
```

### High-Value Read Methods

| Method | Purpose |
|--------|---------|
| `get_meta_and_asset_ctxs()` | Perp market metadata + contexts (enumerate markets, map asset_id↔coin) |
| `get_spot_meta()` | Spot metadata (tokens + universe pairs) |
| `get_spot_assets()` | Spot asset mapping (e.g. `{"HYPE/USDC": 10107}`) |
| `get_spot_asset_id(base_coin, quote_coin="USDC")` | Look up spot asset ID from pair name |
| `get_all_mid_prices()` | All mid prices as `dict[str, float]` |
| `get_l2_book(coin, n_levels=20)` | Perp/spot order book by coin string |
| `get_spot_l2_book(spot_asset_id)` | Spot order book by asset ID |
| `get_user_state(address)` | Perp account state (aggregated across dexes) |
| `get_spot_user_state(address)` | Spot balances |
| `get_full_user_state(*, account, include_spot=True, include_open_orders=True)` | Aggregated state: perp + spot + open orders in one call |
| `get_margin_table(margin_table_id)` | Margin table data (cached 24h) |
| `get_open_orders(address)` | Open orders (delegates to `get_frontend_open_orders`) |
| `get_frontend_open_orders(address)` | Open + trigger orders (aggregated across dexes) |
| `get_user_fills(address)` | Recent fills |
| `check_recent_liquidations(address, since_ms)` | Filter fills for liquidation events where user was liquidated |
| `get_order_status(address, order_id)` | Single order status |
| `get_user_deposits(address, from_timestamp_ms)` | Deposit ledger entries since timestamp |
| `get_user_withdrawals(address, from_timestamp_ms)` | Withdrawal ledger entries since timestamp |
| `hypercore_get_token_metadata(token_address)` | Resolve spot token metadata by EVM address (0-address → HYPE) |
| `get_perp_margin_amount(user_state)` | Extract account value from user state dict |
| `get_valid_order_size(asset_id, size)` | Quantize size to valid step for the asset |
| `max_transferable_amount(total, hold, *, sz_decimals, leave_one_tick=True)` | Compute max transferable (static utility) |

### Funding History

There is **no** `HyperliquidAdapter.get_funding_history()` method. Use one of:
- **Wayfinder API** (preferred): `HyperliquidDataClient.get_funding_history(coin, start_ms, end_ms)`
- **SDK direct**: `adapter.info.funding_history(name, startTime, endTime)` (milliseconds, not async)

### Hyperliquid deposits + withdrawals (Bridge2)

This repo uses Hyperliquid’s **Bridge2** deposit/withdraw flow and assumes **Arbitrum (chain_id = 42161)** as the EVM side.

**TL;DR:** To deposit to Hyperliquid, you send **native USDC on Arbitrum** to the Hyperliquid Bridge2 address. Do **not** send USDC from other chains or other assets.

Primary reference:
- Hyperliquid docs: https://hyperliquid.gitbook.io/hyperliquid-docs/for-developers/api/bridge2
- Funding cadence (hourly): https://hyperliquid.gitbook.io/hyperliquid-docs/trading/funding

## What you can deposit/withdraw

- **Deposit asset:** native **USDC on Arbitrum**
  - This repo’s constant: `ARBITRUM_USDC_ADDRESS = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831`
- **Deposit target:** Bridge2 address on Arbitrum
  - This repo’s constant: `HYPERLIQUID_BRIDGE_ADDRESS = 0x2Df1c51E09aECF9cacB7bc98cB1742757f163dF7`

## Minimums, fees + timing (operational expectations)

From Hyperliquid's Bridge2 docs:
- **Minimum deposit is 5 USDC**; deposits below that are **lost**.
- Deposits are typically credited **in < 1 minute**.
- Withdrawals typically arrive **in several minutes** (often longer than deposits).
- **Withdrawal fee is $1 USDC** — deducted from the withdrawn amount (e.g., withdraw $6.93 → receive $5.93).

Treat these as *best-effort expectations*, not guarantees. In orchestration code, always:
- poll for confirmation
- time out safely
- avoid taking downstream risk (hedges/allocations) until funds are confirmed

## Who gets credited (common pitfall)

Baseline Bridge2 deposit behavior:
- **The Hyperliquid account credited is the sender** of the Arbitrum USDC transfer to the bridge address.

Bridge2 also supports “deposit on behalf” via a permit flow (`batchedDepositWithPermit`) per the docs, but this repo’s strategy patterns assume the simple “send USDC to bridge” path.

## How to monitor deposits/withdrawals

Adapter: `wayfinder_paths/adapters/hyperliquid_adapter/adapter.py`

### Deposit initiation

Bash shortcut:
```bash
poetry run wayfinder execute --kind hyperliquid_deposit --wallet_label main --amount 8
```

This hard-codes:
- token: native Arbitrum USDC (`usd-coin-arbitrum`)
- recipient: `HYPERLIQUID_BRIDGE_ADDRESS`
- chain: Arbitrum (42161)

### Withdrawal initiation

- Call: `HyperliquidAdapter.withdraw(amount, address)` (USDC withdraw to Arbitrum via executor)

Bash shortcut:
```bash
poetry run wayfinder hyperliquid_execute --action withdraw --wallet_label main --amount_usdc 100
```

### Deposit monitoring (recommended)

- Call: `HyperliquidAdapter.wait_for_deposit(address, expected_increase, timeout_s=..., poll_interval_s=...)`
- Mechanism: polls `get_user_state(address)` and checks perp margin increase.

Bash shortcut:
```bash
poetry run wayfinder hyperliquid --action wait_for_deposit --wallet_label main --expected_increase 100 --timeout_s 300
```

### Withdrawal monitoring (best-effort)

- Call: `HyperliquidAdapter.wait_for_withdrawal(address, max_poll_time_s=..., poll_interval_s=...)`
- Mechanism: polls Hyperliquid ledger updates for a `withdraw` record.

Bash shortcut:
```bash
poetry run wayfinder hyperliquid --action wait_for_withdrawal --wallet_label main
```

If you need strict "arrived on Arbitrum" confirmation, add an Arbitrum-side receipt check (RPC/Explorer) for the resulting tx hash.

## Orchestration tips

- **Hyperliquid funding is paid hourly**; if you're rate-locking funding with Boros, align your observations to this cadence.
- Prefer explicit "funding stages" in strategies:
  1) deposit to Hyperliquid
  2) wait for credit
  3) open/adjust hedge
  4) only then deploy spot/yield legs


## Trading

### Market Orders

```bash
# Market buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin ETH --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5

# Market sell / short
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin ETH --is_buy false --usd_amount 200 --usd_amount_kind margin --leverage 5
```

### Limit Orders

```bash
# Limit buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin ETH --is_buy true --size 0.1 --price 3000 --order_type limit

# Limit sell
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin ETH --is_buy false --size 0.1 --price 4000 --order_type limit
```

### Close Position

```bash
# Close with reduce-only
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin ETH --is_buy false --size 0.5 --reduce_only
```

### Leverage

```bash
# Update leverage (cross margin)
poetry run wayfinder hyperliquid_execute --action update_leverage --wallet_label main \
  --coin ETH --leverage 5 --is_cross

# Update leverage (isolated margin)
poetry run wayfinder hyperliquid_execute --action update_leverage --wallet_label main \
  --coin ETH --leverage 5 --no-is_cross
```

### Trigger Orders (Take-Profit / Stop-Loss)

Via scripts, use `place_trigger_order()` for both take-profit and stop-loss:

```python
adapter = get_adapter(HyperliquidAdapter, "main")

# Stop loss (market execution when trigger price hit)
ok, result = await adapter.place_trigger_order(
    asset_id=3,  # ETH
    is_buy=True,  # buy back to close a short
    trigger_price=3500.0,
    size=0.1,
    address="0x...",
    tpsl="sl",
    is_market=True,
)

# Take profit with limit price
ok, result = await adapter.place_trigger_order(
    asset_id=3,
    is_buy=False,
    trigger_price=4000.0,
    size=0.1,
    address="0x...",
    tpsl="tp",
    is_market=False,
    limit_price=3990.0,
)
```

Trigger orders are always `reduce_only=True`. The convenience wrapper `place_stop_loss()` calls `place_trigger_order` with `tpsl="sl"` and `is_market=True`.

### Isolated Margin Management

Add or remove USDC margin on an existing isolated position:

```python
# Add $50 margin to an isolated ETH position
ok, result = await adapter.update_isolated_margin(asset_id=3, delta_usdc=50.0, address="0x...")

# Remove $20 margin
ok, result = await adapter.update_isolated_margin(asset_id=3, delta_usdc=-20.0, address="0x...")
```

Positive `delta_usdc` = add margin, negative = remove.

### Cancel Orders

```bash
# Cancel by order ID
poetry run wayfinder hyperliquid_execute --action cancel_order --wallet_label main \
  --coin ETH --order_id 12345

# Cancel by client order ID
poetry run wayfinder hyperliquid_execute --action cancel_order --wallet_label main \
  --coin ETH --cancel_cloid my-order-1
```

## Transfers

### Internal Transfers

USDC transfers between spot and perp wallets are available via `hyperliquid_execute`:

```bash
# Move USDC from spot wallet to perp wallet
poetry run wayfinder hyperliquid_execute --action spot_to_perp_transfer --wallet_label main --amount_usdc 50

# Move USDC from perp wallet to spot wallet
poetry run wayfinder hyperliquid_execute --action perp_to_spot_transfer --wallet_label main --amount_usdc 50
```

### HyperCore → HyperEVM Transfers (via scripts)

Transfer spot tokens from HyperCore to HyperEVM using the built-in `hypercore_to_hyperevm()` method:

```python
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.hyperliquid_adapter import HyperliquidAdapter

adapter = get_adapter(HyperliquidAdapter, "main")

# Transfer HYPE (token_address=None or 0x0 means HYPE)
ok, result = await adapter.hypercore_to_hyperevm(amount=1.0, address="0x...", token_address=None)

# Transfer any spot token by EVM address
ok, result = await adapter.hypercore_to_hyperevm(amount=100.0, address="0x...", token_address="0xTokenAddr")
```

### Arbitrary Spot Transfers (via scripts)

Transfer any spot token to another address:

```python
ok, result = await adapter.spot_transfer(amount=1.0, destination="0xRecipient", token="HYPE:150", address="0x...")
```

The `token` parameter uses `"NAME:tokenId"` format. Use `hypercore_get_token_metadata(token_address)` to resolve the correct token string.


### Deposit USDC to Hyperliquid

```bash
# Deposit
poetry run wayfinder execute --kind hyperliquid_deposit --wallet_label main --amount 100

# Wait for deposit to arrive (polls perp margin increase)
poetry run wayfinder hyperliquid --action wait_for_deposit --wallet_label main \
  --expected_increase 100 --timeout_s 300
```

### Withdraw USDC from Hyperliquid

```bash
# Withdraw
poetry run wayfinder hyperliquid_execute --action withdraw --wallet_label main \
  --amount_usdc 100

# Wait for withdrawal to settle (polls ledger for withdraw record)
poetry run wayfinder hyperliquid --action wait_for_withdrawal --wallet_label main
```

### Orchestration Tips

- Always poll for confirmation and time out safely before taking downstream risk.
- Hyperliquid funding is paid hourly — if rate-locking with Boros, align observations to this cadence.
- Prefer explicit funding stages: deposit → wait for credit → open hedge → then deploy other legs.

## Sizing

When a user says "$X at Yx leverage", clarify intent:

| `--usd_amount_kind` | Meaning | Example ($200 at 5x) |
|---------------------|---------|----------------------|
| `margin` | $X is collateral | Notional = $1,000 |
| `notional` | $X is position size | Margin = $40 |

## Execution Architecture

- **Read methods** work with the `Info` client only — no executor needed.
- **Write methods** require a `HyperliquidExecutor` with signing configured. Without it, execution methods raise `NotImplementedError`.

### Execution Methods

| Method | Purpose |
|--------|---------|
| `place_market_order(asset_id, is_buy, slippage, size, address, *, reduce_only=False, cloid=None, builder=None)` | Market order (IOC) |
| `place_limit_order(asset_id, is_buy, price, size, address, *, reduce_only=False, builder=None, cloid=None)` | Limit order (GTC) |
| `place_trigger_order(asset_id, is_buy, trigger_price, size, address, tpsl, is_market=True, limit_price=None, builder=None)` | Trigger order — take-profit (`tpsl="tp"`) or stop-loss (`tpsl="sl"`). Always `reduce_only=True`. |
| `place_stop_loss(asset_id, is_buy, trigger_price, size, address)` | Stop loss (convenience wrapper around `place_trigger_order` with `tpsl="sl"`) |
| `cancel_order(asset_id, order_id, address)` | Cancel by order ID |
| `cancel_order_by_cloid(asset_id, cloid, address)` | Cancel by client order ID (looks up oid from open orders first) |
| `update_leverage(asset_id, leverage, is_cross, address)` | Set leverage + margin mode |
| `update_isolated_margin(asset_id, delta_usdc, address)` | Add/remove USDC margin on an isolated position. Positive = add, negative = remove. |
| `withdraw(*, amount, address)` | USDC withdraw to Arbitrum (keyword-only) |
| `spot_transfer(*, amount, destination, token, address)` | Transfer spot tokens to another address |
| `hypercore_to_hyperevm(*, amount, address, token_address=None)` | Transfer spot token from HyperCore to HyperEVM. `token_address=None` or `0x0` = HYPE. |
| `transfer_spot_to_perp(amount, address)` | Move USDC from spot wallet to perp wallet |
| `transfer_perp_to_spot(amount, address)` | Move USDC from perp wallet to spot wallet |
| `approve_builder_fee(builder, max_fee_rate, address)` | Approve builder fee |
| `set_dex_abstraction(address, enabled)` | Enable/disable dex abstraction (required for order placement) |

### Builder Fee

Builder attribution uses a fixed wallet `0xaA1D89f333857eD78F8434CC4f896A9293EFE65c`. Fee value `f` is in **tenths of a basis point** (e.g. `30` = 0.030%). Set in `config.json` under `strategy.builder_fee`. The CLI auto-approves if needed.

## Spot Orders

For spot trading, you **must** set `is_spot` explicitly when using `hyperliquid_execute`:

```bash
# Spot buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin HYPE --is_spot true --is_buy true --usd_amount 20

# Perp buy (default)
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main \
  --coin HYPE --is_spot false --is_buy true --usd_amount 20 --usd_amount_kind notional
```

**Available spot pairs are limited.** Common assets like BTC and ETH are NOT directly available. Use wrapped versions:
- `UBTC/USDC` for wrapped BTC
- `UETH/USDC` for wrapped ETH
- `HYPE/USDC` is native and available

Spot orders don't use leverage — `usd_amount` is always treated as notional. `leverage` and `reduce_only` are ignored for spot.

**Spot balance location:** Spot tokens live in your spot wallet, separate from perp margin. Use scripts with `transfer_spot_to_perp()` / `transfer_perp_to_spot()` to move USDC between them.

## Gotchas

- **Minimum amounts**: Deposits require **>= $5 USDC** (below $5 is lost). All orders (perp and spot) require a minimum of **$10 USD notional**.
- **Asset IDs**: Perp assets: `asset_id < 10000`. Spot assets: `asset_id >= 10000` (spot_index = asset_id - 10000).
- **Spot naming quirks**: Spot index 0 uses `"PURR/USDC"`, otherwise `"@{spot_index}"`. Use `get_spot_assets()` for the mapping.
- **`is_spot` must be explicit**: When placing orders, `is_spot=True` for spot, `is_spot=False` for perp. Omitting returns an error.
- **Funding**: Funding is paid/received every hour. Use `resource wayfinder://hyperliquid/markets` for current funding rates.
- **Slippage**: Default slippage is applied to market orders. Override with `--slippage` (as a decimal, e.g., 0.01 = 1%).
- **No guessing**: Do not invent funding rates or prices. Always fetch via adapter and label timestamps.
- **USD sizing ambiguity**: When a user says "$X at Yx leverage", always clarify if $X is notional (position size) or margin (collateral). See the Sizing table above.
- **Builder fee approvals**: Builder fees are opt-in per user/builder pair. Fee value `f` is in **tenths of a basis point** (e.g. `30` = 0.030%). The CLI auto-approves if needed.
- **Funding history**: There is no `HyperliquidAdapter.get_funding_history()` — use `HyperliquidDataClient` or the SDK's `Info.funding_history()` directly.
- **Dex abstraction**: Order placement auto-enables dex abstraction via `ensure_dex_abstraction()`. If you see "dex abstraction not enabled" errors, call `set_dex_abstraction(address, True)` manually.
- **Liquidation detection**: Use `check_recent_liquidations(address, since_ms)` to filter fills where the user was the liquidated party. Returns only fills with `liquidation.liquidatedUser == address`.
- **`get_full_user_state()` is keyword-only**: Call as `get_full_user_state(account="0x...", include_spot=True, include_open_orders=True)`. Returns aggregated perp + spot + open orders in one call.
- **HyperCore→HyperEVM token resolution**: `hypercore_to_hyperevm()` resolves tokens by EVM address via spot metadata. Pass `token_address=None` or `"0x0000..."` for HYPE (index 150).
