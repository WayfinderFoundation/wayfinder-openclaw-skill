---
name: wayfinder-hyperliquid
description: Trade perpetual futures and spot on Hyperliquid — long, short, leverage, margin, limit orders, market orders, stop-loss, take-profit, trigger orders, cancel orders, deposit USDC, withdraw, check open positions, PnL, funding rates, order book, transfer between spot and perp wallets. Use for perps, futures trading, leveraged positions, derivatives, Hyperliquid.
---

# Hyperliquid Trading

Trade perpetuals and spot on Hyperliquid via two CLI commands: `hyperliquid` (wait for deposits/withdrawals, plus read-only resource URIs) and `hyperliquid_execute` (live trading operations). All commands run from the SDK directory.

---

## `hyperliquid` — Wait for Hyperliquid deposits/withdrawals

Wait for deposits or withdrawals to settle on Hyperliquid. For read-only queries (user state, prices, order books), use the `resource` command with Hyperliquid URIs.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `"wait_for_deposit"` \| `"wait_for_withdrawal"` | **Yes** | — | — |
| `wallet_label` | string | No | — | Or use `wallet_address` |
| `wallet_address` | string | No | — | Alternative to `wallet_label` |
| `expected_increase` | TEXT | No | — | Expected USDC increase for deposit (float value) |
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

Place/cancel orders, update leverage, withdraw USDC, and transfer USDC between spot/perp balances. **These operations are live** and can place real orders / move real funds.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `place_order` \| `place_trigger_order` \| `cancel_order` \| `update_leverage` \| `withdraw` \| `spot_to_perp_transfer` \| `perp_to_spot_transfer` | **Yes** | — | — |
| `wallet_label` | string | **Yes** | — | Must resolve to wallet with private key |
| `coin` | string | **place_order, place_trigger_order, cancel_order, update_leverage** | — | Or use `asset_id`. Strips `-perp`/`_perp` suffixes automatically |
| `asset_id` | TEXT | No | — | Direct asset ID (numeric, coerced to int; alternative to `coin`) |
| `is_spot` | `TEXT` | No | — | `true` for spot orders, `false` for perp. **Must be explicit for place_order.** |
| `order_type` | `market` \| `limit` | No | `market` | — |
| `is_buy` | `TEXT` | **place_order, place_trigger_order** | — | `true` or `false` |
| `size` | TEXT | No | — | Float value; **mutually exclusive with `usd_amount`**; coin units |
| `usd_amount` | `TEXT` | **spot_to_perp_transfer, perp_to_spot_transfer** | — | **Orders:** mutually exclusive with `size`. **Transfers:** required. |
| `usd_amount_kind` | string | **perp `usd_amount` orders** | — | Perp only: `notional` or `margin`. Spot treats `usd_amount` as notional. |
| `leverage` | TEXT | **when `usd_amount_kind=margin`; update_leverage** | — | Numeric, coerced to int; must be a positive integer |
| `price` | TEXT | **limit orders** | — | Float value; must be positive (also used for limit trigger orders when `is_market_trigger=false`) |
| `trigger_price` | TEXT | **place_trigger_order** | — | Float value; trigger price (must be positive) |
| `tpsl` | string | **place_trigger_order** | — | `"tp"` (take-profit) or `"sl"` (stop-loss) |
| `is_market_trigger` | flag | No | `true` | Trigger orders only; `--is_market_trigger` / `--no-is_market_trigger` |
| `slippage` | float | No | `0.01` | Market orders only; 0–0.25 (25% cap) |
| `reduce_only` | flag | No | `false` | `--reduce_only` / `--no-reduce_only` |
| `cloid` | string | No | — | Client order ID |
| `order_id` | TEXT | **cancel_order** | — | Numeric order ID (coerced to int); or use `cancel_cloid` |
| `cancel_cloid` | string | No | — | Alternative to `order_id` for cancel |
| `is_cross` | flag | No | `true` | `--is_cross` / `--no-is_cross` |
| `amount_usdc` | TEXT | **withdraw** | — | Float value; USDC amount for withdraw (transfers use `usd_amount`) |
| `builder_fee_tenths_bp` | TEXT | No | — | Numeric, coerced to int; falls back to config default (positive integer, tenths of a bp) |

**Key validations for `place_order`:**
- Exactly one of `size` or `usd_amount` (not both, not neither).
- For perp orders: if `usd_amount` is used, `usd_amount_kind` is required (`notional` or `margin`). Spot treats `usd_amount` as notional.
- If `usd_amount_kind=margin`, then `leverage` is required.
- Limit orders require `price` > 0.
- After lot-size rounding, size must still be > 0.
- Builder fee is mandatory (auto-configured; approval is auto-submitted if needed).

**Boolean parameter syntax:**
- `is_spot` and `is_buy` are passed as **values** (e.g. `--is_spot true`, `--is_buy false`) — they are not `--flag/--no-flag`.
- Only options documented as `--foo / --no-foo` behave like boolean flags (e.g. `--reduce_only`, `--is_cross`).

```bash
# Market buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5

# Spot buy
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin HYPE --is_spot true --is_buy true --usd_amount 20

# Limit sell
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy false --size 0.1 --price 4000 --order_type limit

# Close position (reduce-only)
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy false --size 0.5 --reduce_only

# Stop-loss / take-profit (trigger order)
poetry run wayfinder hyperliquid_execute --action place_trigger_order --wallet_label main --coin ETH --tpsl sl --is_buy false --trigger_price 2800 --size 0.5

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

## Sizing for Perp Orders

When a user says "$X at Yx leverage", clarify:
- `--usd_amount_kind margin` = $X is collateral (notional = X * leverage)
- `--usd_amount_kind notional` = $X is position size

`--usd_amount` and `--size` are mutually exclusive. When using `--usd_amount` with `--usd_amount_kind margin`, `--leverage` is required.

---

## Common Workflows

### Opening a Long Position

1. Check current price and account state:
```bash
poetry run wayfinder resource wayfinder://hyperliquid/prices/ETH
poetry run wayfinder resource wayfinder://hyperliquid/main/state
```

2. Place a market buy (e.g. $200 margin at 5x leverage = $1000 notional):
```bash
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy true --usd_amount 200 --usd_amount_kind margin --leverage 5
```

### Setting a Stop-Loss on an Open Position

Place a trigger order to sell if ETH drops to 2800:
```bash
poetry run wayfinder hyperliquid_execute --action place_trigger_order --wallet_label main --coin ETH --tpsl sl --is_buy false --trigger_price 2800 --size 0.5
```

### Closing a Position

Use `--reduce_only` to close without risk of opening in the opposite direction:
```bash
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy false --size 0.5 --reduce_only
```

### Deposit, Wait, Then Trade

```bash
# Deposit USDC from Arbitrum
poetry run wayfinder execute --kind hyperliquid_deposit --wallet_label main --amount 100

# Wait for deposit to arrive
poetry run wayfinder hyperliquid --action wait_for_deposit --wallet_label main --expected_increase 100 --timeout_s 300

# Now trade
poetry run wayfinder hyperliquid_execute --action place_order --wallet_label main --coin ETH --is_spot false --is_buy true --usd_amount 100 --usd_amount_kind notional
```

---

## References

- [Hyperliquid Reference](references/hyperliquid.md) — adapter methods, deposit/withdrawal mechanics, Bridge2 details, spot order quirks, gotchas
- [Commands Reference](../wayfinder/references/commands.md) — full CLI command reference for all Wayfinder commands
- [Error Reference](references/errors.md)
