---
name: wayfinder-delta-lab
description: Cross-venue DeFi market data, historical rates, and yield discovery via Delta Lab. Search assets, screen lending/perp/price/borrow-route markets, pull timeseries snapshots, find top APY opportunities, and discover delta-neutral pairs. All data is read-only — no execution, just discovery and research. Use for market screening, rate comparison, historical data, lookback analysis, funding rates, lending rates, yield opportunities, basis trading research, asset lookup, timeseries, price history, APY discovery, delta-neutral pairs.
---

# Delta Lab — Historical Market Data & Yield Discovery

Delta Lab is Wayfinder's **cross-venue market screening and historical data layer**. It aggregates prices, perp funding rates, lending supply/borrow rates, yield token APYs, Pendle fixed rates, and Boros markets across dozens of DeFi protocols into a single queryable dataset.

**Delta Lab is read-only.** It discovers and compares opportunities — it does not execute trades. Use it to research, screen, and analyze before acting through other Wayfinder skills.

---

## Why Delta Lab Matters

DeFi yield is fragmented across hundreds of venues and chains. Manually checking Aave, Moonwell, Hyperliquid, Morpho, Pendle, Boros, and others is impractical. Delta Lab solves this by:

- **Unified screening** — Compare lending rates, funding rates, and yield across all tracked venues in a single query.
- **Historical context via lookback** — See averaged rates over configurable windows (1–90 days) instead of relying on volatile point-in-time snapshots.
- **Delta-neutral discovery** — Automatically pair carry legs (lending, yield tokens) with hedge legs (short perps) to find market-neutral strategies.
- **Basis grouping** — Treats fungible assets (ETH, WETH, wstETH, cbETH) as one "basis group" so you see all opportunities for an exposure, not just one token.

---

## Understanding Lookback

The `lookback_days` parameter controls the **historical averaging window** for rate calculations. It determines how many days of data are used to compute mean APYs, funding rates, and other metrics.

| Lookback | Best For | Trade-off |
|----------|----------|-----------|
| **1–3 days** | Current market conditions, short-term trades | Volatile — a single spike can dominate the average |
| **7 days** (default) | General-purpose screening, weekly rebalancing | Good balance of recency and stability |
| **14–30 days** | Strategy evaluation, medium-term planning | Smoothed — filters out daily noise, shows sustained trends |
| **30–90 days** | Long-term strategy research, regime analysis | Very stable — may miss recent shifts in market conditions |

**Sample uses:**
- *"Is this 20% funding rate sustainable?"* — Compare `lookback_days=1` (current spike) vs `lookback_days=30` (sustained average). If the 30-day average is 5%, the spike is likely temporary.
- *"Which lending protocol consistently offers the best rate?"* — Use `lookback_days=30` to see which venues maintain high rates, not just which one is highest right now.
- *"Should I enter this delta-neutral trade?"* — Use `lookback_days=7` for the APY sources, then validate with `lookback_days=30` to check if the spread has been persistent.

---

## Concepts

- **`basis`** — A root symbol group (e.g. `ETH`, `BTC`, `USD`) that includes all fungible variants. ETH basis includes WETH, wstETH, cbETH, etc. Used for broad screening.
- **`asset_id`** — Delta Lab's internal identifier for a specific asset on a specific chain/address. Use for precise filtering (e.g. "sUSDai on Arbitrum").
- **`all` / `_`** — Most filters accept `all` (or `_`) to mean "no filter".
- **`lookback_days`** — Historical averaging window in days. Controls the smoothing period for all rate calculations.

---

## APY Value Format (Critical)

**All APY/rate values are decimal floats, NOT percentages:**

| Value | Meaning |
|-------|---------|
| `0.05` | **5% APY** |
| `0.98` | **98% APY** |
| `2.40` | **240% APY** |

To display as percentage: multiply by 100 (e.g. `0.12` = 12%).

This applies to all `apy`, `funding_rate`, `*_apr`, `*_apy`, volatility, and return fields.

---

## `resource` — All Delta Lab Queries

All Delta Lab data is accessed via `poetry run wayfinder resource ...` URIs. No execution commands — everything is read-only.

### Asset Discovery

Find asset IDs, symbols, and basis group mappings.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/symbols` | List all tracked basis symbols |
| `wayfinder://delta-lab/assets/search/{chain}/{query}/{limit}` | Fuzzy search assets by symbol/name/address |
| `wayfinder://delta-lab/assets/by-address/{address}/{chain_id}` | Look up assets by contract address |
| `wayfinder://delta-lab/assets/{asset_id}` | Fetch a single asset by ID |
| `wayfinder://delta-lab/{symbol}/basis` | Map a symbol to its basis group/root symbol |

```bash
# List all basis symbols Delta Lab tracks
poetry run wayfinder resource wayfinder://delta-lab/symbols

# Search for an asset (chain can be "all", a chain code like "arbitrum", or numeric like "42161")
poetry run wayfinder resource wayfinder://delta-lab/assets/search/all/susdai/25
poetry run wayfinder resource wayfinder://delta-lab/assets/search/base/usdc/10

# Look up by contract address
poetry run wayfinder resource wayfinder://delta-lab/assets/by-address/0x.../base

# Fetch a single asset by its Delta Lab ID
poetry run wayfinder resource wayfinder://delta-lab/assets/12345

# Check basis group membership
poetry run wayfinder resource wayfinder://delta-lab/ETH/basis
```

### Top Opportunities & APY Sources

Discover yield opportunities and delta-neutral pairs. These endpoints use `lookback_days` to average rates over a configurable window.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/top-apy/{lookback_days}/{limit}` | Top LONG opportunities across all symbols |
| `wayfinder://delta-lab/{basis_symbol}/apy-sources/{lookback_days}/{limit}` | All yield opportunities for a basis symbol |
| `wayfinder://delta-lab/{basis_symbol}/delta-neutral/{lookback_days}/{limit}` | Best carry + hedge pairs for delta-neutral strategies |

```bash
# Top 50 yield opportunities across everything (7-day average)
poetry run wayfinder resource wayfinder://delta-lab/top-apy/7/50

# All ETH yield opportunities (7-day lookback, top 25)
poetry run wayfinder resource wayfinder://delta-lab/ETH/apy-sources/7/25

# Same query with 30-day lookback for more stable averages
poetry run wayfinder resource wayfinder://delta-lab/ETH/apy-sources/30/25

# Best delta-neutral pairs for BTC (7-day lookback)
poetry run wayfinder resource wayfinder://delta-lab/BTC/delta-neutral/7/10

# Wider search with longer lookback
poetry run wayfinder resource wayfinder://delta-lab/ETH/delta-neutral/14/20
```

**APY sources response includes:**
- `directions.LONG` — Opportunities where you earn yield (supply, lend, hold yield tokens, receive fixed rate)
- `directions.SHORT` — Opportunities where you pay (borrow, short perps, pay fixed rate)
- `opportunities` — All opportunities combined
- `summary.instrument_type_counts` — Count by type (PERP, LENDING_SUPPLY, PENDLE_PT, etc.)
- `warnings` — Always check this field for data quality issues

**Delta-neutral response includes:**
- `candidates` — All pairs sorted by `net_apy` descending (highest yield first)
- `pareto_frontier` — Subset on the risk/return Pareto frontier (optimal trade-offs)
- Each candidate has `carry_leg` (earns yield), `hedge_leg` (hedges exposure), `net_apy` (combined), `erisk_proxy` (risk metric)

### Timeseries (Historical Snapshots)

Pull historical price and rate data. Useful for charts, trend analysis, and validating whether current rates are sustainable.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/{symbol}/timeseries/{series}/{lookback_days}/{limit}` | Historical timeseries for a symbol |

**Series options:** `price`, `funding`, `lending`, `yield`, `pendle`, `boros`, `rates` (all rate series). Comma-separated lists are supported.

```bash
# ETH price history (7 days, 200 points)
poetry run wayfinder resource wayfinder://delta-lab/ETH/timeseries/price/7/200

# BTC funding rate history (30 days)
poetry run wayfinder resource wayfinder://delta-lab/BTC/timeseries/funding/30/500

# USDC lending rates over 14 days
poetry run wayfinder resource wayfinder://delta-lab/USDC/timeseries/lending/14/300

# Multiple series at once
poetry run wayfinder resource wayfinder://delta-lab/ETH/timeseries/price,funding/30/200
```

Returns a dict keyed by series name, where each value is a list of rows with a `ts` timestamp and series-specific columns.

### Market Screens

Cross-venue snapshots sorted by any metric. Use `basis` for broad filtering or `by-asset-ids` for precise filtering.

#### Price Screen

Sort keys: `price_usd`, `ret_1d`, `ret_7d`, `ret_30d`, `ret_90d`, `vol_7d`, `vol_30d`, `vol_90d`, `mdd_30d`, `mdd_90d`.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/screen/price/{sort}/{limit}/{basis}` | Price screen by basis |
| `wayfinder://delta-lab/screen/price/by-asset-ids/{sort}/{limit}/{asset_ids}` | Price screen by asset IDs |

```bash
# Top movers today
poetry run wayfinder resource wayfinder://delta-lab/screen/price/ret_1d/20/all

# ETH-basis assets by 7-day return
poetry run wayfinder resource wayfinder://delta-lab/screen/price/ret_7d/50/ETH

# Precise: specific assets by comma-separated IDs
poetry run wayfinder resource wayfinder://delta-lab/screen/price/by-asset-ids/ret_7d/50/12345,67890
```

#### Lending Screen

Sort keys: `net_supply_apr_now`, `net_supply_mean_7d`, `net_supply_mean_30d`, `combined_net_supply_apr_now`, `net_borrow_apr_now`, `supply_tvl_usd`, `liquidity_usd`, `util_now`.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/screen/lending/{sort}/{limit}/{basis}` | Lending screen by basis |
| `wayfinder://delta-lab/screen/lending/by-asset-ids/{sort}/{limit}/{asset_ids}` | Lending screen by asset IDs |

```bash
# Best USD lending rates right now
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/net_supply_apr_now/50/USD

# ETH lending by 7-day mean rate (more stable than "now")
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/net_supply_mean_7d/20/ETH

# Specific assets
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/by-asset-ids/net_supply_apr_now/50/12345
```

#### Perp Screen

Sort keys: `funding_now`, `funding_mean_7d`, `funding_mean_30d`, `funding_std_7d`, `funding_std_30d`, `basis_now`, `oi_now`, `volume_24h`.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/screen/perp/{sort}/{limit}/{basis}` | Perp screen by basis |
| `wayfinder://delta-lab/screen/perp/by-asset-ids/{sort}/{limit}/{asset_ids}` | Perp screen by asset IDs |

```bash
# Highest funding rates right now
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/funding_now/50/all

# BTC perps by 30-day mean funding (sustained carry)
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/funding_mean_30d/20/BTC

# Specific assets
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/by-asset-ids/funding_now/50/12345
```

#### Borrow Routes Screen (Collateral -> Borrow)

Sort keys: `ltv_max`, `liq_threshold`, `liquidation_penalty`, `debt_ceiling_usd`, `venue_name`, `market_label`, `created_at`.

| URI Template | Description |
|--------------|-------------|
| `wayfinder://delta-lab/screen/borrow-routes/{sort}/{limit}/{basis}/{borrow_basis}/{chain_id}` | Borrow routes by basis |
| `wayfinder://delta-lab/screen/borrow-routes/by-asset-ids/{sort}/{limit}/{asset_ids}/{borrow_asset_ids}/{chain_id}` | Borrow routes by asset IDs |

```bash
# ETH collateral -> USD borrow, any chain
poetry run wayfinder resource wayfinder://delta-lab/screen/borrow-routes/ltv_max/25/ETH/USD/all

# Same but restricted to Base
poetry run wayfinder resource wayfinder://delta-lab/screen/borrow-routes/ltv_max/25/ETH/USD/base

# Precise: specific collateral + borrow asset IDs
poetry run wayfinder resource wayfinder://delta-lab/screen/borrow-routes/by-asset-ids/ltv_max/25/12345/67890/all
```

---

## Common Workflows

### Research Before Entering a Position

```bash
# 1. What are the top opportunities right now?
poetry run wayfinder resource wayfinder://delta-lab/top-apy/7/20

# 2. Drill into ETH specifically
poetry run wayfinder resource wayfinder://delta-lab/ETH/apy-sources/7/25

# 3. Is the top rate sustainable? Check with longer lookback
poetry run wayfinder resource wayfinder://delta-lab/ETH/apy-sources/30/25

# 4. Look at the historical trend
poetry run wayfinder resource wayfinder://delta-lab/ETH/timeseries/lending/30/500
```

### Find Delta-Neutral Opportunities

```bash
# 1. Find best carry + hedge pairs
poetry run wayfinder resource wayfinder://delta-lab/BTC/delta-neutral/7/10

# 2. Validate funding rate stability
poetry run wayfinder resource wayfinder://delta-lab/BTC/timeseries/funding/30/500

# 3. Check lending rate stability for the carry leg
poetry run wayfinder resource wayfinder://delta-lab/BTC/timeseries/lending/30/500
```

### Compare Rates Across Venues

```bash
# Lending rates for USD stablecoins across all venues
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/net_supply_apr_now/50/USD

# Funding rates for ETH perps across all venues
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/funding_now/20/ETH

# Validate with historical averages
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/funding_mean_30d/20/ETH
```

### Asset Discovery for Precise Screening

```bash
# 1. Don't know the asset_id? Search first
poetry run wayfinder resource wayfinder://delta-lab/assets/search/all/susdai/10

# 2. Use the asset_id(s) for precise screening
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/by-asset-ids/net_supply_apr_now/50/12345
```

---

## Tips

- Use `by-asset-ids` screens when the user names a specific token (e.g. "sUSDai") — broad basis screens may miss niche markets outside the top N.
- If you don't know an `asset_id`, search first (`assets/search/...`) then plug the IDs into `by-asset-ids` screens.
- Use uppercase symbols: `ETH`, `BTC`, `USD` — not `eth`, `bitcoin`, or coingecko IDs.
- APY can be `null` for instruments with insufficient data — always handle this.
- Funding rate sign: **positive = longs pay shorts** (good for short positions). **Negative = shorts pay longs** (bad for short positions). This is critical for delta-neutral analysis.
- For delta-neutral pairs: use `candidates[0]` for highest APY, use `pareto_frontier` for risk-adjusted optimal pairs.
- Always check the `warnings` field in APY source and delta-neutral responses — data quality issues can affect decisions.
- Compare short lookback (1–7d) with long lookback (14–30d) to distinguish temporary spikes from sustained opportunities.

---

## References

- [Delta Lab Data Reference](references/delta-lab-data.md) — Response structures, field definitions, and data types
- [Error Reference](references/errors.md)
