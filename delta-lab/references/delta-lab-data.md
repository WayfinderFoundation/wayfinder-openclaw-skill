# Delta Lab Data Reference

Detailed response structures and field definitions for Delta Lab queries.

## Opportunity Object

Each yield opportunity returned by `apy-sources` or `top-apy` has this structure:

| Field | Type | Description |
|-------|------|-------------|
| `instrument_id` | int | Unique instrument identifier |
| `instrument_type` | string | `PERP`, `LENDING_SUPPLY`, `LENDING_BORROW`, `BOROS_MARKET`, `PENDLE_PT`, `YIELD_TOKEN` |
| `side` | string | `LONG` or `SHORT` — the position direction |
| `venue` | string | Protocol name (e.g. `hyperliquid`, `moonwell`, `aave`, `morpho`) |
| `market_id` | int | Market identifier within the venue |
| `market_external_id` | string | Venue's external market identifier |
| `chain_id` | int | Chain ID where the instrument lives |
| `maturity_ts` | string/null | ISO 8601 maturity timestamp (for Pendle PTs and Boros markets), or `null` |
| `deposit_asset` | object | `{asset_id, symbol}` — the token you deposit |
| `receipt_asset` | object | `{asset_id, symbol}` — the token you receive |
| `exposure_asset` | object | `{asset_id, symbol}` — the underlying price exposure |
| `apy` | object | APY details (see below) |
| `risk` | object | Risk metrics (see below) |
| `quality_ok` | int | `1` if data quality is acceptable, `0` otherwise |
| `market_label` | string | Human-readable market label |

### APY Object

| Field | Type | Description |
|-------|------|-------------|
| `value` | float/null | **Decimal float** (0.12 = 12%). Can be `null` if insufficient data |
| `components` | object | Breakdown of APY sources (protocol-specific) |
| `as_of` | string | ISO 8601 timestamp of the calculation |
| `lookback_days` | int | Lookback window used for averaging |

### Risk Object

| Field | Type | Description |
|-------|------|-------------|
| `vol_annualized` | float | Annualized volatility of the rate |
| `erisk_proxy` | float | Combined risk metric (lower = less risky) |
| `tvl_usd` | float | Total value locked in USD |
| `size_usd` | float | Position size in USD |
| `liquidity_usd` | float | Available liquidity in USD |

## Delta-Neutral Candidate Object

Each candidate from `delta-neutral` has this structure:

| Field | Type | Description |
|-------|------|-------------|
| `basis_root_symbol` | string | The basis symbol (e.g. `BTC`, `ETH`) |
| `exposure_asset` | object | `{asset_id, symbol}` — the underlying exposure |
| `carry_leg` | Opportunity | Full opportunity object for the yield-earning side (LONG) |
| `hedge_leg` | Opportunity | Full opportunity object for the hedging side (SHORT) |
| `net_apy` | float | **Decimal float** — combined APY after hedging costs. This is a plain float, NOT a nested object |
| `erisk_proxy` | float | Combined risk metric for the pair |

## Basis Info Object

Returned by `{symbol}/basis`:

| Field | Type | Description |
|-------|------|-------------|
| `asset_id` | int | Delta Lab asset ID |
| `symbol` | string | Asset symbol |
| `basis` | object/null | Basis group info, or `null` if not in a group |
| `basis.basis_group_id` | int | Group identifier |
| `basis.root_asset_id` | int | ID of the root asset in the group |
| `basis.root_symbol` | string | Root symbol (e.g. `ETH` for wstETH) |
| `basis.role` | string | `ROOT`, `WRAPPED`, `YIELD_BEARING`, or `COLLATERAL` |

## Asset Object

Returned by `assets/{asset_id}`:

| Field | Type | Description |
|-------|------|-------------|
| `asset_id` | int | Delta Lab internal ID |
| `symbol` | string | Token symbol |
| `name` | string | Full token name |
| `decimals` | int | Token decimal places |
| `chain_id` | int | Chain ID |
| `address` | string | Contract address |
| `coingecko_id` | string | CoinGecko identifier |

## Screen Response Format

All screen endpoints return `{"data": [...], "count": N}`.

### Price Screen Row

| Field | Type | Description |
|-------|------|-------------|
| `asof_ts` | string | Snapshot timestamp |
| `asset_id` | int | Asset ID |
| `symbol` | string | Asset symbol |
| `price_usd` | float | Current price in USD |
| `ret_1d`, `ret_7d`, `ret_30d`, `ret_90d` | float | Returns over period (decimal) |
| `vol_7d`, `vol_30d`, `vol_90d` | float | Annualized volatility (decimal) |
| `mdd_30d`, `mdd_90d` | float | Max drawdown over period (decimal) |

### Lending Screen Row

| Field | Type | Description |
|-------|------|-------------|
| `asof_ts` | string | Snapshot timestamp |
| `market_id` | int | Market identifier |
| `market_type` | string | Market type |
| `chain_id` | int | Chain ID |
| `venue_name` | string | Protocol name |
| `asset_id` | int | Asset ID |
| `symbol` | string | Asset symbol |
| `net_supply_apr_now` | float | Current net supply APR (decimal) |
| `net_supply_mean_7d`, `net_supply_mean_30d` | float | Mean supply APR over period |
| `combined_net_supply_apr_now` | float | Supply APR including reward tokens |
| `net_borrow_apr_now` | float | Current net borrow APR |
| `util_now` | float | Current utilization rate |
| `supply_tvl_usd` | float | Total supply TVL |
| `borrow_tvl_usd` | float | Total borrow TVL |
| `liquidity_usd` | float | Available liquidity |
| `ltv_max` | float | Maximum loan-to-value ratio |
| `liq_threshold` | float | Liquidation threshold |
| `liquidation_penalty` | float | Liquidation penalty |
| `borrow_spike_score` | float | Borrow rate spike indicator |

### Perp Screen Row

| Field | Type | Description |
|-------|------|-------------|
| `asof_ts` | string | Snapshot timestamp |
| `instrument_id` | int | Instrument identifier |
| `venue_name` | string | Exchange name |
| `base_symbol` | string | Base asset symbol |
| `mark_price` | float | Current mark price |
| `basis_now` | float | Current basis (decimal) |
| `funding_now` | float | Current funding rate (decimal, annualized) |
| `funding_mean_7d`, `funding_mean_30d` | float | Mean funding rate over period |
| `funding_std_7d`, `funding_std_30d` | float | Funding rate standard deviation |
| `oi_now` | float | Current open interest in USD |
| `volume_24h` | float | 24-hour trading volume |

### Borrow Route Screen Row

| Field | Type | Description |
|-------|------|-------------|
| `route_id` | int | Route identifier |
| `market_id` | int | Market identifier |
| `chain_id` | int | Chain ID |
| `venue_name` | string | Protocol name |
| `collateral_symbol` | string | Collateral asset symbol |
| `borrow_symbol` | string | Borrow asset symbol |
| `ltv_max` | float | Maximum LTV |
| `liq_threshold` | float | Liquidation threshold |
| `liquidation_penalty` | float | Penalty on liquidation |
| `debt_ceiling_usd` | float | Debt ceiling in USD |
| `topology` | string | `POOLED` or `ISOLATED_PAIR` |
| `mode_type` | string | `BASE`, `EMODE`, or `ISOLATION` |

## Timeseries Response

Returns a dict keyed by series name. Each value is a list of rows with a `ts` timestamp.

### Price Series Columns
`ts`, `price_usd`

### Funding Series Columns
`ts`, `instrument_id`, `venue`, `market_external_id`, `funding_rate`, `mark_price_usd`, `oi_usd`, `volume_usd`

### Lending Series Columns
`ts`, `market_id`, `asset_symbol`, `chain_id`, `venue`, `supply_apr`, `borrow_apr`, `supply_reward_apr`, `borrow_reward_apr`, `net_supply_apy`, `net_borrow_apy`, `utilization`, `supply_tvl_usd`, `borrow_tvl_usd`

### Yield Series Columns
`ts`, `yield_token_asset_id`, `yield_token_symbol`, `apy_base`, `apy_base_7d`, `exchange_rate`, `tvl_usd`

### Pendle Series Columns
`ts`, `market_id`, `venue`, `pt_symbol`, `maturity_ts`, `implied_apy`, `underlying_apy`, `reward_apr`, `pt_price`, `tvl_usd`

### Boros Series Columns
`ts`, `market_id`, `venue`, `market_external_id`, `fixed_rate_mark`, `floating_rate_oracle`, `pv`
