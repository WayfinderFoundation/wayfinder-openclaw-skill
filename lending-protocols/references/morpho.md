# Morpho (Blue + MetaMorpho)

## Overview

Morpho Blue is an isolated lending market primitive, and MetaMorpho vaults are ERC-4626 wrappers over Blue allocations. The Morpho adapter supports:
- Market discovery and per-market state reads
- User position snapshots (per-chain and cross-chain)
- Execution: collateral ops, lend/unlend, borrow/repay
- Rewards reads/claims (Merkl + URD)
- MetaMorpho vault operations (deposit/withdraw/mint/redeem)

- **Type**: `MORPHO`
- **Module**: `wayfinder_paths.adapters.morpho_adapter.adapter.MorphoAdapter`
- **Capabilities**: `market.list`, `market.read`, `market.state`, `market.history`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.deposit`, `collateral.withdraw`, `vault.list`, `vault.read`, `vault.deposit`, `vault.withdraw`, `vault.mint`, `vault.redeem`, `rewards.read`, `rewards.claim`, `operator.authorize`, `allocator.reallocate`

## Supported chains

Execution calls (lend/borrow/collateral/vault/rewards/operator/allocator) are supported on any `chain_id` present in `MORPHO_BY_CHAIN` (`wayfinder_paths/core/constants/morpho_contracts.py` in the SDK). As of the pinned SDK ref in `sdk-version.md`, Morpho is configured for:

| Network | `chain_id` |
|--------|------------|
| Ethereum | `1` |
| Optimism | `10` |
| Unichain | `130` |
| Polygon | `137` |
| Monad | `143` |
| Stable | `988` |
| Hyperliquid | `999` |
| Base | `8453` |
| Arbitrum | `42161` |
| Plume | `98866` |
| Katana | `747474` |

## High-value reads

Primary adapter: `wayfinder_paths/adapters/morpho_adapter/adapter.py`

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_all_markets(chain_id, listed=True, include_idle=False)` | Market list + point-in-time APYs/rewards/warnings | No |
| `get_market_state(chain_id, market_unique_key)` | Single market state + allocator liquidity/vault links | No |
| `get_market_historical_apy(chain_id, market_unique_key, interval, start_timestamp=None, end_timestamp=None)` | APY time series | No |
| `get_full_user_state_per_chain(chain_id, account, include_zero_positions=False)` | Positions snapshot | No (if you pass `account`) |
| `get_full_user_state(account, include_zero_positions=False)` | Cross-chain snapshot | No (if you pass `account`) |
| `get_claimable_rewards(chain_id, account=None)` | Claimable Merkl + URD rewards | No (if you pass `account`) |
| `get_all_vaults(chain_id, listed=True, include_v2=True)` | Vault list + APY/rewards | No |

### Script example: list markets

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.morpho_adapter import MorphoAdapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_BASE

async def main() -> None:
    adapter = get_adapter(MorphoAdapter)  # read-only
    ok, markets = await adapter.get_all_markets(chain_id=CHAIN_ID_BASE)
    if not ok:
        raise RuntimeError(markets)
    for m in markets[:10]:
        print(m.get("uniqueKey"), m.get("loanAsset", {}).get("symbol"), "supply_apy=", m.get("supply_apy"))

if __name__ == "__main__":
    asyncio.run(main())
```

### Script example: user snapshot (per-chain)

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.morpho_adapter import MorphoAdapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_BASE

USER = "0x0000000000000000000000000000000000000000"

async def main() -> None:
    adapter = get_adapter(MorphoAdapter)
    ok, state = await adapter.get_full_user_state_per_chain(chain_id=CHAIN_ID_BASE, account=USER)
    if not ok:
        raise RuntimeError(state)
    for p in state.get("positions", []):
        print(p.get("marketUniqueKey"), "health=", p.get("healthFactor"))

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

All market actions are market-specific: you must choose a `market_unique_key`.

| Method | Purpose | Notes |
|--------|---------|-------|
| `supply_collateral(chain_id, market_unique_key, qty)` | Deposit collateral | Required before borrowing |
| `withdraw_collateral(chain_id, market_unique_key, qty, withdraw_full=False)` | Withdraw collateral | Check health factor first |
| `lend(chain_id, market_unique_key, qty)` | Supply loan asset | `qty` raw int |
| `unlend(chain_id, market_unique_key, qty, withdraw_full=False)` | Withdraw supply | `withdraw_full=True` uses shares-based close |
| `borrow(chain_id, market_unique_key, qty)` | Borrow loan asset | `qty` raw int |
| `repay(chain_id, market_unique_key, qty, repay_full=False)` | Repay borrow | `repay_full=True` uses shares-based close |
| `claim_rewards(chain_id, claim_merkl=True, claim_urd=True)` | Claim rewards | Returns tx(s) |
| `vault_deposit(chain_id, vault_address, assets)` | ERC-4626 deposit | MetaMorpho vaults |
| `vault_withdraw(chain_id, vault_address, assets)` | ERC-4626 withdraw | — |
| `vault_mint(chain_id, vault_address, shares)` | ERC-4626 mint | — |
| `vault_redeem(chain_id, vault_address, shares)` | ERC-4626 redeem | — |
| `borrow_with_jit_liquidity(chain_id, market_unique_key, qty, atomic=True)` | Borrow with allocator JIT liquidity | Requires bundler config for atomic mode |

## Gotchas

- **Markets are isolated:** every action targets a specific `market_unique_key` (loan/collateral/oracle/IRM/LLTV are immutable per market).
- **Collateral is separate from supply:** borrowing requires `supply_collateral(...)` (not just `lend(...)`).
- **Full close uses shares:** `repay_full=True` / `withdraw_full=True` uses shares to avoid dust from interest accrual.
- **Bundler is optional:** atomic allocator+borrow requires a bundler address (`bundler_address` config or method argument).
- **Rewards are multi-source:** Merkl claims use the Merkl distributor; URD claims use Morpho distributions. Use `get_claimable_rewards(...)` first.
