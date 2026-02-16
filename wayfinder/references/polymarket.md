# Polymarket

## Overview

Polymarket is a prediction market platform. The Polymarket adapter supports:
- Market discovery (search/trending)
- Market/event details
- Prices, order books, and price history
- User status (balances, positions, orders)
- Collateral bridging and trade execution (requires signing wallet)

- **Type**: `POLYMARKET`
- **Module**: `wayfinder_paths.adapters.polymarket_adapter.adapter.PolymarketAdapter`
- **Capabilities**: `market.read`, `market.search`, `market.orderbook`, `market.candles`, `position.read`, `order.execute`, `order.cancel`, `bridge.deposit`, `bridge.withdraw`

## Read-Only Actions (CLI)

Polymarket reads use the `polymarket` tool (not `resource` URIs):

```bash
# Search markets
poetry run wayfinder polymarket --action search --query "bitcoin above" --limit 5

# Trending markets (by 24h volume)
poetry run wayfinder polymarket --action trending --limit 10

# Market details
poetry run wayfinder polymarket --action get_market --market_slug "some-market-slug"

# Account status (positions + balances; provide wallet_label or account)
poetry run wayfinder polymarket --action status --wallet_label main

# CLOB order book + price for a specific token_id
poetry run wayfinder polymarket --action order_book --token_id 123456
poetry run wayfinder polymarket --action price --token_id 123456 --side BUY
```

### Read Methods (Adapter)

| Method | Purpose |
|--------|---------|
| `search_markets_fuzzy(*, query, limit=10, page=1, keep_closed_markets=False, events_status=None, end_date_min=None, rerank=True)` | Enhanced fuzzy search with re-ranking by relevance |
| `public_search(*, q, limit_per_type=10, page=1, keep_closed_markets=False)` | Raw Gamma public search endpoint |
| `list_markets(*, closed=None, limit=50, offset=0, order=None, ascending=None, **filters)` | List markets with filters |
| `list_events(*, closed=None, limit=50, offset=0, order=None, ascending=None, **filters)` | List events with filters |
| `get_market_by_slug(slug)` | Single market by slug |
| `get_event_by_slug(slug)` | Event by slug (includes nested markets) |
| `get_market_by_condition_id(*, condition_id)` | Market by condition ID (for redemption) |
| `resolve_clob_token_id(*, market, outcome)` | Resolve outcome name/index to CLOB token ID |
| `get_price(*, token_id, side="BUY")` | CLOB price for a token |
| `get_order_book(*, token_id)` | Single order book |
| `get_order_books(*, token_ids)` | Batch order books |
| `get_prices_history(*, token_id, interval="1d", start_ts=None, end_ts=None, fidelity=None)` | Price time series by token ID |
| `get_market_prices_history(*, market_slug, outcome="YES", interval="1d", ...)` | Price history by slug + outcome (convenience) |
| `get_positions(*, user, limit=500, offset=0, **filters)` | User positions (paginated) |
| `get_activity(*, user, limit=500, offset=0, **filters)` | User activity feed |
| `get_trades(*, limit=500, offset=0, user=None, **filters)` | Trade history |
| `list_open_orders(*, token_id=None)` | Open orders (requires signing wallet / Level-2 auth) |
| `get_full_user_state(*, account, include_orders=True, include_activity=False, include_trades=False, ...)` | Comprehensive state: positions + PnL + balances + orders |
| `bridge_supported_assets()` | Bridge supported asset list |
| `bridge_status(*, address)` | Bridge operation status |
| `preflight_redeem(*, condition_id, holder, candidate_collaterals=None)` | Check redeemability before redeeming |

### `get_full_user_state()` return structure

Returns `(ok, dict)` with:
- `positions` — all positions (auto-paginates up to `max_positions_pages * positions_limit`)
- `positionsSummary` — `{count, redeemableCount, mergeableCount, negativeRiskCount}`
- `pnl` — `{totalInitialValue, totalCurrentValue, totalCashPnl, totalRealizedPnl, totalUnrealizedPnl, totalPercentPnl}`
- `balances` — `{usdc_e: {address, decimals, amount_base_units, amount}, usdc: {...}}`
- `usdc_e_balance`, `usdc_balance` — top-level shortcuts
- `openOrders` / `orders` — open CLOB orders (if `include_orders=True`)
- `recentActivity` — activity feed (if `include_activity=True`)
- `recentTrades` — trade history (if `include_trades=True`)
- `errors` — per-section error messages

## Execution (CLI) — Live

Polymarket execution uses `polymarket_execute` and is **always live** (no dry-run flag).

**Wallet requirement:** `wallet_label` must resolve to a wallet in `config.json` that includes **both** `address` and `private_key_hex` (local dev only).

```bash
# Bridge USDC -> USDC.e collateral (Polymarket)
poetry run wayfinder polymarket_execute --action bridge_deposit --wallet_label main --amount 10

# Buy shares by market slug + outcome
poetry run wayfinder polymarket_execute --action buy --wallet_label main --market_slug "some-market-slug" --outcome YES --amount_usdc 2

# Close position (convenience: sells full size for the resolved token_id)
poetry run wayfinder polymarket_execute --action close_position --wallet_label main --market_slug "some-market-slug" --outcome YES
```

### Execution Methods (Adapter)

| Method | Purpose |
|--------|---------|
| `place_market_order(*, token_id, side, amount, price=None)` | Market order. BUY `amount` = USDC to spend, SELL `amount` = shares to sell. |
| `place_limit_order(*, token_id, side, price, size, post_only=False)` | Limit order (GTC). `post_only=True` for maker-only. |
| `place_prediction(*, market_slug, outcome="YES", amount_usdc=1.0)` | Buy by slug + outcome (convenience — resolves token_id internally) |
| `cash_out_prediction(*, market_slug, outcome="YES", shares=1.0)` | Sell by slug + outcome (convenience) |
| `cancel_order(*, order_id)` | Cancel an open order |
| `bridge_deposit(*, from_chain_id, from_token_address, amount, recipient_address, token_decimals=6)` | Convert token → USDC.e. BRAP fast path on Polygon, bridge service fallback. |
| `bridge_withdraw(*, amount_usdce, to_chain_id, to_token_address, recipient_addr, token_decimals=6)` | Convert USDC.e → destination token. BRAP fast path, bridge service fallback. |
| `redeem_positions(*, condition_id, holder)` | Redeem resolved market positions. Auto-unwraps adapter collateral to USDC.e. |
| `ensure_onchain_approvals()` | Ensure all ERC20 + ERC1155 approvals for trading (idempotent) |

## Position Redemption

Resolved markets must be redeemed via ConditionalTokens to get USDC.e back:

```python
adapter = get_adapter(PolymarketAdapter, "main")

# Check if positions are redeemable
ok, path = await adapter.preflight_redeem(condition_id="0x...", holder="0x...")
# path: {collateral, parentCollectionId, conditionId, indexSets}

# Redeem (sends redeemPositions tx + unwraps adapter collateral)
ok, result = await adapter.redeem_positions(condition_id="0x...", holder="0x...")
# result: {tx_hash, path}
```

`preflight_redeem` tries `parentCollectionId = 0x0` first (most markets), then falls back to scanning on-chain logs for non-zero parent collection IDs. Candidate collaterals checked: adapter collateral, USDC, USDC.e.

## Gotchas

- **USDC vs USDC.e (collateral mismatch):** Polymarket trading collateral is **USDC.e** on Polygon (`0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`, 6 decimals), not native Polygon USDC (`0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`). Use `bridge_deposit` / `bridge_withdraw` to convert.
- **Bridge utilities (BRAP vs bridge service):** `bridge_deposit` (USDC → USDC.e) and `bridge_withdraw` (USDC.e → USDC/destination token) prefer a fast on-chain BRAP swap on Polygon when possible (sender == recipient). Otherwise they fall back to the Polymarket Bridge service; the result includes `method: "polymarket_bridge"` and you may need to poll `polymarket --action bridge_status` until it clears.
- **`market_slug` vs `token_id`:** You can trade using `market_slug`+`outcome` or directly via the CLOB `token_id`. Prefer `market_slug` when possible.
- **Market found but not tradable:** Filter for `enableOrderBook`, `acceptingOrders`, `active`, `closed != true`, and non-empty `clobTokenIds`. Fallback to `trending` when fuzzy search returns stale/closed items.
- **Outcomes are not always YES/NO:** Some markets are multi-outcome. If `YES` doesn’t exist, retry with `outcome=0` (first outcome) or pick the exact outcome string from the market’s outcomes list.
- **Approvals:** Trading requires on-chain approvals on Polygon. These are handled automatically before order placement (idempotent).
- **Bridging:** Collateral flows may involve USDC/USDC.e conversions. Always verify balances via `polymarket --action status` after bridge operations.
- **Open orders:** `polymarket --action open_orders` requires a signing wallet (private key) due to Level-2 auth. Optional: pass `--token_id` to filter.
- **Buy then immediately sell can fail:** CLOB settlement/match can lag; you may not have shares available to sell instantly. If chaining BUY → SELL, wait for the buy confirmation first.
- **Rate limiting:** Avoid large concurrent scans of `price_history`. Use a semaphore (e.g. 4–8 concurrent calls) and retry/backoff on 429s.
- **Token IDs aren’t ERC20 addresses:** `clobTokenIds` are CLOB identifiers. Outcome shares are ERC1155 positions under ConditionalTokens.
- **Redemption requires `conditionId`:** Resolved markets redeem via ConditionalTokens `redeemPositions()` using the market’s `conditionId`.
