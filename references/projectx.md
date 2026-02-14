# ProjectX (HyperEVM)

## Overview

ProjectX is a Uniswap V3-style concentrated-liquidity DEX on HyperEVM. The ProjectX adapter supports:
- Pool overview reads (tick/price/liquidity + token metadata)
- Listing positions for a specific pool
- Minting/increasing liquidity using wallet balances (with optional balancing swaps)
- Fee collection / burning positions
- Exact-in swaps via the ProjectX router

- **Type**: `PROJECTX`
- **Module**: `wayfinder_paths.adapters.projectx_adapter.adapter.ProjectXLiquidityAdapter`
- **Capabilities**: `projectx.pool.overview`, `projectx.positions.list`, `projectx.liquidity.mint`, `projectx.liquidity.increase`, `projectx.liquidity.decrease`, `projectx.fees.collect`, `projectx.position.burn`, `projectx.swap.exact_in`

## Configuration

- **RPC resolution (chain id 999 / HyperEVM)**: Do not hardcode RPC URLs in scripts. Use `web3_from_chain_id(999)` (internally used by the adapter). If `strategy.rpc_urls["999"]` is not set, the SDK falls back to Wayfinder’s RPC proxy at `system.api_base_url` (auth via `system.api_key` / `WAYFINDER_API_KEY`).
- **`pool_address` is optional**, but many pool-specific methods require it.
- The adapter accepts `pool_address` via config in multiple keys (including nested `strategy` config): `pool_address`, `pool`, `projectx_pool_address`, `projectx_pool`.

## Usage (via custom scripts)

ProjectX operations are executed via one-off scripts under `.wayfinder_runs/`:

```bash
poetry run wayfinder run_script --script_path .wayfinder_runs/projectx_lp.py --wallet_label main
```

### Pool-agnostic mode (no `pool_address`)

Use this for cross-pool reads and operations that don’t need a specific pool:
- `get_full_user_state()` (positions + points; skips pool overview/balances without a configured pool)
- `_list_all_positions()` (all active positions across all pools)
- `fetch_prjx_points()` (points lookup)
- `burn_position(token_id)` (close any position by NFT token id)
- `swap_exact_in(...)` (routes automatically; no fee hint from a configured pool)

```python
import asyncio

from wayfinder_paths.adapters.projectx_adapter.adapter import ProjectXLiquidityAdapter
from wayfinder_paths.mcp.scripting import get_adapter


async def main():
    adapter = get_adapter(ProjectXLiquidityAdapter, "main")
    ok, state = await adapter.get_full_user_state()
    print("ok:", ok)
    if ok:
        print("positions:", state.get("positions"))
        print("points:", state.get("points"))


asyncio.run(main())
```

### Pool-scoped mode (with `pool_address`)

Required for pool-specific reads and helpers:
- `pool_overview()` / `current_balances()` / `list_positions()`
- `fetch_swaps()` (subgraph swap history for a specific pool)
- `live_fee_snapshot()`
- `mint_from_balances()` / `increase_liquidity_balanced()`

```python
import asyncio

from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.projectx_adapter import ProjectXLiquidityAdapter

POOL = "0x..."  # ProjectX pool address


async def main():
    adapter = get_adapter(ProjectXLiquidityAdapter, "main", config_overrides={"pool_address": POOL})
    ok, overview = await adapter.pool_overview()
    ok, positions = await adapter.list_positions()
    print("overview ok:", ok)
    print("positions ok:", ok, "n=", len(positions) if ok else None)


asyncio.run(main())
```

## High-value methods

| Method | Purpose | Notes |
|--------|---------|-------|
| `get_full_user_state(...)` | One-shot state (positions/balances/overview/points) | Pool-agnostic (overview/balances require pool) |
| `pool_overview()` | Pool tick/spacing/fee + token metadata | Requires `pool_address` |
| `current_balances(owner=...)` | Raw balances for pool token0/token1 | Requires `pool_address` |
| `list_positions(owner=...)` | Active NPM positions for this pool | Requires `pool_address` |
| `fetch_swaps(...)` | Swap history | Subgraph (HTTP), requires `pool_address` |
| `fetch_prjx_points(wallet_address)` | Points | HTTP API |
| `mint_from_balances(tick_lower, tick_upper, slippage_bps=...)` | Mint new position using balances | Uses pool tick spacing |
| `increase_liquidity_balanced(...)` | Increase liquidity after balancing | Uses pool tick spacing |
| `burn_position(token_id)` | Remove liquidity + collect + burn | Does not require `pool_address` |
| `swap_exact_in(from_token, to_token, amount_in, slippage_bps=...)` | Swap exact-in | Routes automatically |
| `live_fee_snapshot(token_id)` | Claimable fees for position with USD value | Requires `pool_address` |
| `find_pool_for_pair(token_a, token_b, *, prefer_fees=None)` | Resolve pool address for token pair | Read-only |
| `price_band_for_ticks(tick_lower, tick_upper)` | Price range for tick band with decimals | Requires `pool_address` |
| `classify_range_state(ticks, tick_lower, tick_upper, fallback_tick=None)` | Classify position: `in_range`, `out_of_range`, `entering_out_of_range` | Static utility |
| `recent_swaps(limit=10)` | Recent swaps (convenience wrapper) | Requires `pool_address` |

## Strategy Note

The `projectx_thbill_usdc_strategy` strategy uses this adapter for concentrated-liquidity market making on the THBILL/USDC stable pair.

## Gotchas

- **`pool_address` is optional (two modes):** Pool-scoped methods raise `ValueError("pool_address is required …")` when called without a configured pool.
- **ProjectX pools can have non-standard tick spacing:** Prefer `mint_from_balances()` / `increase_liquidity_balanced()` (they use the pool’s `tick_spacing`). If you call low-level Uniswap-style methods directly, pass `tick_spacing=...` explicitly.
- **`fetch_swaps()` is subgraph-based:** Swap history reads can fail due to subgraph downtime or missing config. Always check `(ok, swaps)` and fall back to on-chain reads when needed.
- **Units are raw ints:** amounts are raw base units (respect token decimals).
- **ERC20-only swaps:** `swap_exact_in(...)` uses ERC20 addresses; for “native HYPE” behavior, use the wrapped ERC20 address.
