---
name: wayfinder-other-protocols
description: Additional DeFi protocols — Boros fixed-rate interest markets, Pendle yield tokenization (PT/YT), Uniswap V3 concentrated liquidity LP, ProjectX LP on HyperEVM, Aerodrome and Slipstream DEX on Base, Avantis avUSDC vault, EigenCloud EigenLayer restaking, ether.fi liquid restaking (eETH/weETH), CCXT centralized exchange trading (Binance/Aster). Use for provide liquidity, LP positions, AMM, DEX, fixed rate, yield tokens, restaking, CEX trading, Uniswap, Aerodrome, Pendle, liquidity pools, impermanent loss, fee collection.
---

# Other Protocol Adapters

This document covers additional DeFi protocol adapters available in the Wayfinder SDK that are not covered by dedicated subskills (e.g., Hyperliquid, Aave).

All adapters follow the standard pattern:

```python
from wayfinder_paths.mcp.scripting import get_adapter
adapter = get_adapter(AdapterClass, "main")
ok, result = await adapter.some_method()
```

---

## Boros

- **Chain**: Arbitrum
- **Description**: Fixed-rate interest rate markets. Lock in a fixed funding rate for delta-neutral strategies, removing variable rate risk.
- **Adapter**: `wayfinder_paths.adapters.boros_adapter.adapter.BorosAdapter`
- **Type**: `BOROS`

### Key Methods

| Method | Purpose |
|--------|---------|
| `get_all_markets(...)` | Normalized Boros market list with nested rates, vault summary, and optional history |
| `get_vaults_summary(...)` | Normalized Boros vault summary, optionally including account LP/deposit state |
| `list_markets_all()` | List all available Boros markets |
| `best_yield_vault(...)` | Find the highest-APY depositable vault that fits policy filters |
| `get_scaling_factor(...)` | Get the scaling factor for a market |
| `sweep_isolated_to_cross(...)` | Move collateral from isolated to cross margin |
| `tick_from_rate(rate)` | Convert an interest rate to a tick value |
| `rate_from_tick(tick)` | Convert a tick value back to an interest rate |

### Notes

- Returns `tuple[bool, result]` for all methods -- always unpack.
- Yield Units (YU) are the core trading unit. 1 YU is approximately $1 for USDT collateral.
- Supports cross and isolated margin types.
- Boros also exposes vault-level reads (`vault.list`, `vault.read`) for LP capacity and account-specific vault state.
- Rate/tick conversion is essential for placing orders at specific rates.
- Collateral types: WBTC (1), WETH (2), USDT (3), BNB (4), HYPE (5).

---

## Pendle

- **Chain**: Multi-chain (Ethereum, BSC, Arbitrum, Base, Plasma, HyperEVM)
- **Description**: Splits yield-bearing assets into Principal Tokens (PTs) and Yield Tokens (YTs). PTs offer fixed yield at a discount; YTs offer leveraged exposure to variable yield.
- **Adapter**: `wayfinder_paths.adapters.pendle_adapter.adapter.PendleAdapter`
- **Type**: `PENDLE`

### Key Methods

| Method | Purpose |
|--------|---------|
| `list_active_pt_yt_markets(chain)` | Flattened market list with fixedApy, underlyingApy, liquidityUsd, daysToExpiry |
| `fetch_markets(chain_id)` | Raw API data (nested under `details`) |
| `fetch_market_snapshot(chain_id, market)` | Single market point-in-time state |
| `fetch_market_history(chain_id, market)` | Time series for historical analysis |
| `fetch_ohlcv_prices(...)` | OHLCV price data |
| `fetch_swapping_prices(...)` | Swap pricing data |
| `execute_swap(...)` | Full execution: quote, approvals, broadcast |
| `build_best_pt_swap_tx(...)` | Auto-select best PT by effectiveApy and quote |

### Notes

- Chain IDs: `ethereum` = 1, `bsc` = 56, `arbitrum` = 42161, `base` = 8453, `plasma` = 9745, `hyperevm` = 999.
- PT = fixed yield leg (`impliedApy`). YT = floating yield leg (`underlyingApy - impliedApy`).
- Use `list_active_pt_yt_markets` for discovery (recommended over `fetch_markets`).

---

## Uniswap V3

- **Chain**: Ethereum, Base, Arbitrum (also Polygon, BSC, Avalanche)
- **Description**: Concentrated-liquidity AMM. Provides LP position reads and liquidity/fee management.
- **Adapter**: `wayfinder_paths.adapters.uniswap_adapter.adapter.UniswapAdapter`
- **Type**: `UNISWAP`

### Key Methods

| Method | Purpose | Notes |
|--------|---------|-------|
| `get_positions(owner?)` | List all V3 positions for an owner | |
| `get_position(token_id)` | Read a single position by NFT token id | |
| `get_pool(token_a, token_b, fee)` | Resolve pool address for a pair + fee tier | |
| `get_uncollected_fees(token_id)` | Estimate uncollected fees for a position | |
| `add_liquidity(token0, token1, fee, tick_lower, tick_upper, amount0_desired, amount1_desired, slippage_bps)` | Mint a new LP position | Amounts are raw units |
| `increase_liquidity(token_id, amount0_desired, amount1_desired, slippage_bps)` | Add liquidity to existing position | Amounts are raw units |
| `remove_liquidity(token_id, liquidity?, collect, burn)` | Decrease liquidity, optionally collect/burn | |
| `collect_fees(token_id)` | Collect accrued fees | |

### Notes

- Extends `UniswapV3BaseAdapter`.
- Default chain is Base (8453). Override via `config_overrides={"chain_id": ...}`.
- All token amounts are in raw integer units (respect decimals).
- Write methods require a wallet with `private_key_hex` and sufficient gas.

---

## ProjectX

- **Chain**: HyperEVM (chain id 999)
- **Description**: Uniswap V3-style concentrated-liquidity DEX on HyperEVM. Supports pool reads, position management, minting, fee collection, and exact-in swaps.
- **Adapter**: `wayfinder_paths.adapters.projectx_adapter.adapter.ProjectXLiquidityAdapter`
- **Type**: `PROJECTX`

### Key Methods

| Method | Purpose |
|--------|---------|
| `pool_overview()` | Tick/price/liquidity + token metadata for a pool |
| `list_positions(pool_address?)` | List positions for a specific pool |
| `get_full_user_state()` | Positions + points across all pools |
| `mint_from_balances(...)` | Mint a new LP position from wallet balances |
| `increase_liquidity_balanced(...)` | Add liquidity with optional balancing swaps |
| `burn_position(token_id)` | Close a position by NFT token id |
| `swap_exact_in(...)` | Exact-in swap via the ProjectX router |

### Notes

- `strategy_wallet.address` is required even for read-only operations.
- Supports pool-agnostic mode (no `pool_address`) for cross-pool reads and pool-scoped mode for targeted operations.
- Do not hardcode RPC URLs; use `web3_from_chain_id(999)`.

---

## Aerodrome + Slipstream

- **Chain**: Base
- **Description**: Aerodrome is the primary DEX on Base. Slipstream is its concentrated liquidity variant (similar to Uniswap V3 tick-range positions).
- **Aerodrome Adapter**: `AerodromeAdapter`
- **Slipstream Adapter**: `AerodromeSlipstreamAdapter`

### Aerodrome Key Methods

| Method | Purpose |
|--------|---------|
| `list_pools(...)` | List available Aerodrome pools |
| `pools_by_lp(...)` | Find pools by LP token |
| `sugar_all(...)` | Aggregated pool data via Sugar lens |
| `quote_best_route(...)` | Quote the best swap route |
| `get_amounts_out(...)` | Get output amounts for a given input |

### Slipstream Key Methods

| Method | Purpose |
|--------|---------|
| `find_pools(...)` | Discover concentrated liquidity pools |
| `get_pool(...)` | Get pool details |
| `get_gauge(...)` | Get gauge (rewards) info for a pool |
| `mint_position(...)` | Mint a new concentrated LP position |
| `increase_liquidity(...)` | Add liquidity to an existing position |

### Notes

- Use the combined Aerodrome reference for deeper method guidance and caveats.
- Aerodrome is a ve(3,3)-style DEX; Slipstream adds concentrated liquidity on top.

---

## Avantis

- **Chain**: Base
- **Description**: ERC-4626 vault where users deposit USDC and receive vault shares (avUSDC).
- **Adapter**: `wayfinder_paths.adapters.avantis_adapter.adapter.AvantisAdapter`
- **Type**: `AVANTIS`

### Key Methods

| Method | Purpose | Notes |
|--------|---------|-------|
| `get_all_markets()` | Single "market" describing the configured vault (TVL, supply, share price) | Read-only |
| `fetch_trailing_apy(...)` | Trailing APY for the vault | Read-only |
| `get_pos(account, include_usd)` | Position snapshot (shares, assets, maxRedeem/maxWithdraw) | Read-only if `account` passed |
| `get_full_user_state(account, include_usd)` | Standardized user state wrapper | Read-only if `account` passed |
| `deposit(amount)` | Deposit USDC into vault | Amount in raw USDC units (6 decimals) |
| `withdraw(amount)` | Redeem vault shares back to USDC | Amount in raw share units |

### Notes

- Read-only operations do not require a signing wallet if you pass `account` explicitly.
- Deposit amounts use raw USDC units (6 decimals on Base).

---

## EigenCloud

- **Chain**: Ethereum mainnet only
- **Description**: EigenLayer restaking system with strategy-based share accounting, optional delegation, delayed withdrawals via on-chain queue, and rewards via merkle proofs.
- **Adapter**: `wayfinder_paths.adapters.eigencloud_adapter.adapter.EigenCloudAdapter`
- **Type**: `EIGENCLOUD`

### Key Methods

| Method | Purpose |
|--------|---------|
| `get_all_markets(include_total_shares, include_share_to_underlying)` | Strategy list + underlying metadata |
| `get_pos(account, include_usd)` | Deposited/withdrawable shares by strategy |
| `get_full_user_state(account, ...)` | Aggregated snapshot (positions, delegation, queued withdrawals, rewards) |
| `deposit(...)` | Deposit into a restaking strategy |
| `delegate(...)` | Delegate restaked assets to an operator |
| `undelegate(...)` | Undelegate from an operator |
| `redelegate(...)` | Switch delegation to a different operator |
| `queue_withdrawals(...)` | Queue a withdrawal (enters delay period) |
| `complete_withdrawal(...)` | Complete a queued withdrawal after delay |
| `claim_rewards(...)` | Claim rewards via merkle proof |

### Notes

- Ethereum mainnet only (does not accept a `chain_id` parameter).
- Withdrawals are delayed; you must first `queue_withdrawals`, then `complete_withdrawal` after the delay period.
- Rewards require offchain-prepared claim structs / merkle proofs.

---

## ether.fi

- **Chain**: Ethereum
- **Description**: Liquid restaking protocol. Stake ETH to receive eETH, wrap to weETH for DeFi composability, and request delayed withdrawals.
- **Adapter**: `EtherfiAdapter`

### Key Methods

| Method | Purpose |
|--------|---------|
| `stake_eth(...)` | Stake ETH to receive eETH |
| `wrap_eeth(...)` | Wrap eETH into weETH |
| `unwrap_weeth(...)` | Unwrap weETH back to eETH |
| `request_withdraw(...)` | Request a withdrawal (enters queue) |
| `claim_withdraw(...)` | Claim a completed withdrawal |
| `get_pos(...)` | Get current position/balance snapshot |

### Notes

- Similar flow to Lido but for restaking rather than staking.
- weETH is the wrapped, DeFi-composable version of eETH.
- Reference documentation is pending.

---

## CCXT

- **Chain**: N/A (centralized exchanges)
- **Description**: Multi-exchange factory for centralized exchanges via the CCXT library. Each configured exchange becomes a property on the adapter (e.g., `adapter.binance`, `adapter.aster`).
- **Adapter**: `wayfinder_paths.adapters.ccxt_adapter.adapter.CCXTAdapter`
- **Type**: `CCXT`

### Key Methods

Uses the standard CCXT unified API on each exchange property:

| Method | Purpose |
|--------|---------|
| `adapter.<exchange>.fetch_ticker(symbol)` | Get current ticker |
| `adapter.<exchange>.fetch_balance()` | Get account balances |
| `adapter.<exchange>.create_order(symbol, type, side, amount, price)` | Place an order |
| `adapter.<exchange>.fetch_open_orders(symbol)` | List open orders |
| `adapter.<exchange>.cancel_order(id, symbol)` | Cancel an order |

### Notes

- Requires API keys configured in `config.json` under the `ccxt` section with exchange-specific credentials.
- Supported exchanges include Aster, Binance, Bybit, Hyperliquid, dYdX, and others.
- Do not use CCXT for Hyperliquid by default; prefer the native Wayfinder Hyperliquid surfaces unless explicitly requested.
- Always call `await adapter.close()` in a `finally` block to avoid leaking HTTP sessions.
- Exchange IDs must match CCXT's exchange ids (e.g., `binance`, `bybit`, `aster`).

---

## References

- [Boros Reference](references/boros.md)
- [Pendle Reference](references/pendle.md)
- [Uniswap Reference](references/uniswap.md)
- [ProjectX Reference](references/projectx.md)
- [Aerodrome + Slipstream Reference](references/aerodrome.md)
- [Avantis Reference](references/avantis.md)
- [EigenCloud Reference](references/eigencloud.md)
- [CCXT Reference](references/ccxt.md)
- [Coding Interface](../coding-interface/SKILL.md)
- Note: ether.fi reference docs are pending
- [Error Reference](references/errors.md)
