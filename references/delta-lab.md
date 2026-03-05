# Delta Lab (Screens + Asset Lookup)

Delta Lab is Wayfinder's cross-venue market screening dataset: prices/returns, perp funding, lending supply/borrow rates, and borrow routes (collateral → borrow).

Everything here is **read-only** via `poetry run wayfinder resource ...` URIs.

## Concepts

- **`basis`**: A root symbol group (e.g. `ETH`, `BTC`, `USD`) used to filter screens broadly.
- **`asset_id`**: Delta Lab's internal identifier for a specific asset on a specific chain/address. Use this when you need **precise filtering** (e.g. “sUSDai on Arbitrum”).
- **`all` / `_`**: Most Delta Lab filters accept `all` (or `_`) to mean “no filter”.

## Asset lookup (find `asset_id`)

```bash
# Search assets by symbol/name/address/coingecko_id (optionally chain-filtered)
poetry run wayfinder resource wayfinder://delta-lab/assets/search/all/susdai/25
poetry run wayfinder resource wayfinder://delta-lab/assets/search/arbitrum/susdai/25
poetry run wayfinder resource wayfinder://delta-lab/assets/search/42161/susdai/25

# Look up assets by contract address (chain filter recommended)
poetry run wayfinder resource wayfinder://delta-lab/assets/by-address/0x.../base

# Fetch a single asset by asset_id
poetry run wayfinder resource wayfinder://delta-lab/assets/12345
```

Notes:
- The `{chain}`/`{chain_id}` path segment accepts a **chain code** (`base`, `arbitrum`, …) or a numeric chain id (`8453`, `42161`, …).

## Screens

### Top opportunities

```bash
# Basis symbols available in Delta Lab
poetry run wayfinder resource wayfinder://delta-lab/symbols

# Top LONG opportunities across everything (perps, lending, Pendle, etc.)
poetry run wayfinder resource wayfinder://delta-lab/top-apy/7/50

# Per-basis breakdowns
poetry run wayfinder resource wayfinder://delta-lab/ETH/apy-sources/7/25
poetry run wayfinder resource wayfinder://delta-lab/ETH/delta-neutral/7/10
```

### Price screen

Sort keys (common): `price_usd`, `ret_1d`, `ret_7d`, `ret_30d`, `vol_7d`, `vol_30d`, `mdd_30d`.

```bash
# Broad (by basis)
poetry run wayfinder resource wayfinder://delta-lab/screen/price/ret_7d/50/ETH

# Precise (by asset_ids: comma-separated)
poetry run wayfinder resource wayfinder://delta-lab/screen/price/by-asset-ids/ret_7d/50/12345,67890
```

### Lending screen

Sort keys (common): `net_supply_apr_now`, `net_supply_mean_7d`, `combined_net_supply_apr_now`, `net_borrow_apr_now`, `supply_tvl_usd`, `liquidity_usd`, `util_now`.

```bash
# Broad (by basis)
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/net_supply_apr_now/50/USD

# Precise (by asset_ids)
poetry run wayfinder resource wayfinder://delta-lab/screen/lending/by-asset-ids/net_supply_apr_now/50/12345
```

### Perp screen

Sort keys (common): `funding_now`, `funding_mean_7d`, `basis_now`, `oi_now`, `volume_24h`.

```bash
# Broad (by basis)
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/funding_now/50/ETH

# Precise (by asset_ids)
poetry run wayfinder resource wayfinder://delta-lab/screen/perp/by-asset-ids/funding_now/50/12345
```

### Borrow routes (collateral → borrow)

Borrow routes support both:
- **basis filters** (broad), and
- **asset_id filters** (precise),
and optionally a **chain filter** (`{chain_id}` accepts chain code or chain id, or `all`).

Sort keys (common): `ltv_max`, `liq_threshold`, `liquidation_penalty`, `debt_ceiling_usd`, `venue_name`, `market_label`, `created_at`.

```bash
# Broad: collateral basis ETH, borrow basis USD, any chain
poetry run wayfinder resource wayfinder://delta-lab/screen/borrow-routes/ltv_max/25/ETH/USD/all

# Restrict to a chain (Base)
poetry run wayfinder resource wayfinder://delta-lab/screen/borrow-routes/ltv_max/25/ETH/USD/base

# Precise: collateral asset_ids + borrow asset_ids (comma-separated), any chain
poetry run wayfinder resource wayfinder://delta-lab/screen/borrow-routes/by-asset-ids/ltv_max/25/12345/67890/all
```

## Tips

- Prefer `by-asset-ids` screens when the user names a specific token (e.g. “sUSDai”) to avoid missing markets that don’t appear in the top N for a broad basis screen.
- If you don’t know an `asset_id`, search first (`assets/search/...`) and then plug the IDs into `by-asset-ids` screens.
