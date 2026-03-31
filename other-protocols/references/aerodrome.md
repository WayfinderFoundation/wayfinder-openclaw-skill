# Aerodrome + Slipstream

## Overview

Aerodrome is the primary DEX on Base. In this SDK there are two related adapters:

- **AerodromeAdapter**: classic Aerodrome pools, LP tokens, gauges, veAERO voting, and reward flows
- **AerodromeSlipstreamAdapter**: concentrated-liquidity pools and NFT positions, plus the same gauge / veAERO reward ecosystem

Use Aerodrome classic when the workflow is fungible LP tokens and standard pools. Use Slipstream when the workflow is tick ranges, NFT positions, and concentrated-liquidity management.

- **Aerodrome module**: `wayfinder_paths.adapters.aerodrome_adapter.adapter.AerodromeAdapter`
- **Slipstream module**: `wayfinder_paths.adapters.aerodrome_slipstream_adapter.adapter.AerodromeSlipstreamAdapter`
- **Chain**: Base only

## High-value reads

### Aerodrome classic

| Method | Purpose |
|--------|---------|
| `get_all_markets(start=0, limit=50, include_gauge_state=True)` | Normalized list of gauge-enabled Aerodrome pools |
| `list_pools(...)` / `sugar_all(...)` | Pool scans via Sugar |
| `pools_by_lp()` | LP token → pool lookup |
| `quote_best_route(...)` / `get_amounts_out(...)` | Route and amount-out quoting |
| `sugar_epochs_latest(...)` / `rank_pools_by_usdc_per_ve(...)` | Incentive analytics |
| `get_pool(...)` / `get_gauge(...)` | Single pool or gauge inspection |
| `get_full_user_state(account=...)` | LP, staked LP, pending emissions, and veAERO state |
| `get_user_ve_nfts(owner=...)` | veNFT inventory |

### Slipstream

| Method | Purpose |
|--------|---------|
| `get_all_markets(start=0, limit=50, deployments=None, include_gauge_state=True)` | Normalized Slipstream market list across deployments |
| `find_pools(...)` | Pool discovery |
| `get_pool(...)` / `get_gauge(...)` | Single pool or gauge inspection |
| `get_pos(token_id=..., ...)` | One position NFT |
| `get_full_user_state(account=..., deployments=None)` | Wallet positions across Slipstream deployments |
| `get_user_ve_nfts(owner=...)` | veNFT inventory |

## Execution surfaces

### Aerodrome classic

| Method | Purpose |
|--------|---------|
| `quote_add_liquidity(...)` / `add_liquidity(...)` | Add classic LP liquidity |
| `quote_remove_liquidity(...)` / `remove_liquidity(...)` | Remove classic LP liquidity |
| `claim_pool_fees_unstaked(...)` | Claim fees from unstaked LP |
| `stake_lp(...)` / `unstake_lp(...)` | Gauge staking for fungible LP tokens |
| `claim_gauge_rewards(...)` | Claim gauge emissions |

### Slipstream

| Method | Purpose |
|--------|---------|
| `mint_position(...)` | Create a new concentrated-liquidity NFT |
| `increase_liquidity(...)` | Add liquidity to an existing position |
| `decrease_liquidity(...)` | Remove liquidity from a position |
| `collect_fees(...)` | Collect trading fees |
| `burn_position(...)` | Burn a cleared NFT position |
| `stake_position(...)` / `unstake_position(...)` | Gauge staking for position NFTs |
| `claim_position_rewards(...)` | Claim gauge emissions for staked positions |

### Shared veAERO / reward flows

Both adapters inherit the veAERO and reward mixin:

| Method | Purpose |
|--------|---------|
| `create_lock(...)` / `create_lock_for(...)` | Create a veAERO lock |
| `increase_lock_amount(...)` | Add more AERO to a lock |
| `withdraw_lock(...)` | Withdraw after lock expiry |
| `vote(...)` / `reset_vote(...)` | Vote or clear votes |
| `claim_fees(...)` | Claim fee rewards tied to the veNFT |
| `claim_bribes(...)` | Claim bribes tied to the veNFT |
| `claim_rebases(...)` / `claim_rebases_many(...)` | Claim rebases |

## Mental model

- **Classic Aerodrome**: fungible LP tokens, gauges, standard liquidity adds/removes
- **Slipstream**: NFT positions with tick ranges and out-of-range behavior
- **veAERO**: voting escrow NFT used for vote direction, fee claims, bribes, and rebases
- **Gauge emissions**: rewards for staked LP tokens or staked position NFTs

If the user is asking for something closer to Uniswap V3 tick math, Slipstream is the closer fit. If they want standard pool LPing and fungible LP gauges, use classic Aerodrome.

## Gotchas

- Base only.
- `get_all_markets()` on both adapters returns a dict with pagination metadata, not a plain list.
- Classic Aerodrome and Slipstream use different position models: fungible LP tokens vs NFT token ids.
- Slipstream deployment variants matter for market scans and position-manager resolution.
- veAERO voting is time-gated during epoch windows.
- Use route / liquidity quote helpers before moving funds.
