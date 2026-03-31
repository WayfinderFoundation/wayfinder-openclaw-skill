---
name: wayfinder-polymarket
description: Trade prediction markets on Polymarket — search events, browse trending markets, buy and sell outcome shares (YES/NO), place limit orders, check positions and P&L, bridge USDC collateral, view order books and price history. Use for betting, predictions, elections, sports, event outcomes, will X happen, probability markets, Polymarket.
---

# Polymarket

Polymarket is a prediction market platform on Polygon. Use the `polymarket` command for read-only queries (market search, prices, order books, account status) and `polymarket_execute` for live execution (bridging collateral, buying/selling shares, limit orders, cancellations, and redemptions).

**Always require explicit user confirmation before running `polymarket_execute`.**

---

## `polymarket` -- Polymarket market + account reads

Read-only access to Polymarket markets, prices, order books, and user status.

**Tradability filter:** a market can be "found" but not tradable. Filter for `enableOrderBook`, `acceptingOrders`, `active`, `closed != true`, and non-empty `clobTokenIds`.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `status` \| `search` \| `trending` \| `get_market` \| `get_event` \| `price` \| `order_book` \| `price_history` \| `bridge_status` \| `open_orders` | **Yes** | — | — |
| `wallet_label` | string | No | — | Resolves `account` from config; required for `open_orders` |
| `wallet_address` | string | No | — | Alternative to `wallet_label` for account-based reads |
| `account` | string | No | — | Direct account address (alternative to wallet inputs) |
| `include_orders` | flag | No | `true` | `--include_orders` / `--no-include_orders`; `status` only |
| `include_activity` | flag | No | `false` | `--include_activity` / `--no-include_activity`; `status` only |
| `activity_limit` | int | No | `50` | `status` only |
| `include_trades` | flag | No | `false` | `--include_trades` / `--no-include_trades`; `status` only |
| `trades_limit` | int | No | `50` | `status` only |
| `positions_limit` | int | No | `500` | `status` only |
| `max_positions_pages` | int | No | `10` | `status` only |
| `query` | string | **search** | — | Query string for fuzzy market search |
| `limit` | int | No | `10` | `search`, `trending` |
| `page` | int | No | `1` | `search` |
| `keep_closed_markets` | flag | No | `false` | `--keep_closed_markets` / `--no-keep_closed_markets`; `search` |
| `rerank` | flag | No | `true` | `--rerank` / `--no-rerank`; `search` |
| `offset` | int | No | `0` | `trending` |
| `events_status` | string | No | `"active"` | `search` only. One of `active`, `closed`, `archived` |
| `end_date_min` | string | No | `YYYY-MM-DD` | `search` only. Min event end date (UTC) |
| `market_slug` | string | **get_market** | — | Market slug |
| `event_slug` | string | **get_event** | — | Event slug |
| `token_id` | string | **price, order_book, price_history** | — | Polymarket CLOB token id (optional for `open_orders` filter) |
| `side` | `BUY` \| `SELL` | No | `BUY` | `price` only |
| `interval` | string | No | `"1d"` | `price_history` only |
| `start_ts` | `TEXT` | No | — | `price_history` only (unix seconds) |
| `end_ts` | `TEXT` | No | — | `price_history` only (unix seconds) |
| `fidelity` | `TEXT` | No | — | `price_history` only |

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

## `polymarket_execute` -- Polymarket execution (bridge + orders)

Execute Polymarket actions (bridging and trading). **This command is live (no dry-run flag).**

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `action` | `bridge_deposit` \| `bridge_withdraw` \| `buy` \| `sell` \| `close_position` \| `place_limit_order` \| `cancel_order` \| `redeem_positions` | **Yes** | — | — |
| `wallet_label` | string | **Yes** | — | Wallet must include `address` and `private_key_hex` in config |
| `from_chain_id` | int | No | `137` | `bridge_deposit` only |
| `from_token_address` | string | No | Polygon USDC | `bridge_deposit` only |
| `amount` | `TEXT` | **bridge_deposit** | — | Amount of USDC to deposit |
| `recipient_address` | string | No | sender | `bridge_deposit` only |
| `amount_usdce` | `TEXT` | **bridge_withdraw** | — | Amount of USDC.e to withdraw |
| `to_chain_id` | int | No | `137` | `bridge_withdraw` only |
| `to_token_address` | string | No | Polygon USDC | `bridge_withdraw` only |
| `recipient_addr` | string | No | sender | `bridge_withdraw` only |
| `token_decimals` | int | No | `6` | Bridge token decimals |
| `market_slug` | string | No | — | Used by `buy`, `sell`, `close_position` |
| `outcome` | TEXT | No | `"YES"` | String or numeric index; used with `market_slug` (e.g. `YES`/`NO`) |
| `token_id` | string | No | — | Alternative to `market_slug` for `buy`, `sell`, `place_limit_order` |
| `amount_usdc` | `TEXT` | **buy** | — | Buy amount in USDC |
| `shares` | `TEXT` | **sell** | — | Shares to sell |
| `side` | `BUY` \| `SELL` | No | `BUY` | `place_limit_order` only |
| `price` | `TEXT` | **place_limit_order** | — | Limit price (0–1) |
| `size` | `TEXT` | **place_limit_order** | — | Order size (shares) |
| `post_only` | flag | No | `false` | `--post_only` / `--no-post_only`; `place_limit_order` only |
| `order_id` | string | **cancel_order** | — | — |
| `condition_id` | string | **redeem_positions** | — | Required for `redeem_positions`; also accepted by `close_position` as a fallback |

**Approvals + API creds:** handled automatically before order placement (idempotent).

**Trade semantics:**
- `buy` uses `amount_usdc` as **collateral ($) to spend**
- `sell` uses `shares` as **shares to sell**

```bash
# Bridge USDC -> USDC.e collateral (Polymarket)
poetry run wayfinder polymarket_execute --action bridge_deposit --wallet_label main --amount 10

# Buy shares by market slug + outcome
poetry run wayfinder polymarket_execute --action buy --wallet_label main --market_slug "some-market-slug" --outcome YES --amount_usdc 2

# Close a position (sells full size; resolves token_id from market slug)
poetry run wayfinder polymarket_execute --action close_position --wallet_label main --market_slug "some-market-slug" --outcome YES
```

---

## Collateral notes

Polymarket CLOB trading collateral is **USDC.e on Polygon** (`0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174`, 6 decimals), not native Polygon USDC (`0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359`). Use `bridge_deposit` / `bridge_withdraw` to convert between USDC and USDC.e.

These bridge methods prefer a fast on-chain BRAP swap on Polygon when possible (sender == recipient); otherwise they fall back to the Polymarket Bridge service (`method: "polymarket_bridge"` in the result) and you can monitor via `polymarket --action bridge_status`.

Always verify balances via `polymarket --action status` after bridge operations.

---

## Common workflows

### Search strategy — getting good results from Gamma

Gamma's search is literal and token-based, not semantic. Follow these rules to maximize recall:

**1. Use short, lowercase, token-based queries — never natural language.**

| Bad | Good |
|-----|------|
| `Will Bitcoin go up in the next 15 minutes` | `bitcoin 15m up` |
| `Bitcoin Up 15 Minutes` | `bitcoin 15 min up` |

**2. Expand synonyms with multiple queries — Gamma won't do this for you.**

Market titles are inconsistent (`15 min`, `15 minutes`, `15m`, `short term`). Always run several variant queries and merge results:

```
bitcoin 15m up
bitcoin 15 minute up
btc 15m up
btc short term up
```

**3. Try partial / less-specific queries for better recall.**

Sometimes casting a wider net works better — search for the core subject and filter locally:

```
bitcoin 15
bitcoin short term
bitcoin minute
```

**4. Multi-pass search procedure (use this for every search):**

1. Generate 3–5 short query variants covering synonyms, abbreviations, and partial terms.
2. Run `polymarket --action search` for each variant.
3. Deduplicate results by `event.id` (or `conditionId` / `market_slug`).
4. Rank by relevance to the user's intent (prefer higher volume/liquidity and active markets).
5. Present the merged, deduplicated results.

### Finding a market

1. **Search by keyword (multi-pass):** generate query variants per the strategy above, then run `polymarket --action search --query "<variant>" --limit 5` for each.
2. Browse trending markets: `polymarket --action trending --limit 10`
3. Get market details: `polymarket --action get_market --market_slug "the-slug"`
4. Check the order book: `polymarket --action order_book --token_id <token_id>`

### Placing a bet

1. Search for the market and confirm it is tradable (`enableOrderBook`, `acceptingOrders`, `active`, not closed, non-empty `clobTokenIds`).
2. Check your collateral balance: `polymarket --action status --wallet_label main`
3. If needed, bridge USDC to USDC.e: `polymarket_execute --action bridge_deposit --wallet_label main --amount 10`
4. Buy shares: `polymarket_execute --action buy --wallet_label main --market_slug "the-slug" --outcome YES --amount_usdc 5`
5. Verify position: `polymarket --action status --wallet_label main`

### Closing positions

1. Check current positions: `polymarket --action status --wallet_label main`
2. Close a position: `polymarket_execute --action close_position --wallet_label main --market_slug "the-slug" --outcome YES`
3. For resolved markets, redeem: `polymarket_execute --action redeem_positions --wallet_label main --condition_id "0x..."`
4. Optionally withdraw collateral back to USDC: `polymarket_execute --action bridge_withdraw --wallet_label main --amount_usdce 10`

---

## References

- [Polymarket Reference](references/polymarket.md) -- adapter methods, return structures, gotchas, and detailed examples.
- [Commands Reference](../wayfinder/references/commands.md) -- full CLI parameter tables for all commands.
- [Error Reference](references/errors.md)
