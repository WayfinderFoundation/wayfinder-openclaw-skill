# Aave V3

## Overview

Aave V3 is a multi-chain lending/borrowing protocol. The Aave V3 adapter supports:
- Market discovery (rates, caps/LTV, optional rewards)
- User position snapshots (per-chain and cross-chain)
- Execution: supply/withdraw/borrow/repay, collateral toggles, rewards claims

- **Type**: `AAVE_V3`
- **Module**: `wayfinder_paths.adapters.aave_v3_adapter.adapter.AaveV3Adapter`
- **Capabilities**: `market.list`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.toggle`, `rewards.claim`

## High-value reads

Primary adapter: `wayfinder_paths/adapters/aave_v3_adapter/adapter.py`

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_all_markets(chain_id, include_rewards=False)` | Market list + point-in-time rates/rewards | No |
| `get_full_user_state_per_chain(chain_id, account, include_rewards=False, include_zero_positions=False)` | Positions snapshot for one chain | No (if you pass `account`) |
| `get_full_user_state(account, include_rewards=False, include_zero_positions=False)` | Positions snapshot across supported chains | No (if you pass `account`) |

### Script example: list markets

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.aave_v3_adapter import AaveV3Adapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_ARBITRUM

async def main() -> None:
    adapter = get_adapter(AaveV3Adapter)  # read-only
    ok, markets = await adapter.get_all_markets(chain_id=CHAIN_ID_ARBITRUM, include_rewards=True)
    if not ok:
        raise RuntimeError(markets)
    for m in markets[:10]:
        print(m.get("symbol"), "ltv_bps=", m.get("ltv_bps"), "supply_apy=", m.get("supply_apy"))

if __name__ == "__main__":
    asyncio.run(main())
```

### Script example: user snapshot (per-chain)

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.aave_v3_adapter import AaveV3Adapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_ARBITRUM

USER = "0x0000000000000000000000000000000000000000"

async def main() -> None:
    adapter = get_adapter(AaveV3Adapter)
    ok, state = await adapter.get_full_user_state_per_chain(chain_id=CHAIN_ID_ARBITRUM, account=USER, include_rewards=True)
    if not ok:
        raise RuntimeError(state)
    for p in state.get("positions", []):
        if int(p.get("supply_raw") or 0) or int(p.get("variable_borrow_raw") or 0):
            print(p.get("symbol"), "supply_usd=", p.get("supply_usd"), "borrow_usd=", p.get("variable_borrow_usd"))

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

All execution methods require a signing wallet (`get_adapter(AaveV3Adapter, "<wallet_label>")`).

| Method | Purpose | Notes |
|--------|---------|-------|
| `lend(chain_id, underlying_token, qty, native=False)` | Supply underlying | `qty` is raw int |
| `unlend(chain_id, underlying_token, qty, native=False, withdraw_full=False)` | Withdraw underlying | `withdraw_full=True` uses MAX_UINT256 |
| `borrow(chain_id, underlying_token, qty, native=False)` | Borrow underlying | Variable rate mode |
| `repay(chain_id, underlying_token, qty, native=False, repay_full=False)` | Repay borrow | `repay_full=True` uses MAX_UINT256 semantics |
| `set_collateral(chain_id, underlying_token, use_as_collateral=True)` | Toggle collateral | Underlying address (not aToken) |
| `remove_collateral(chain_id, underlying_token)` | Disable collateral | Convenience wrapper |
| `claim_all_rewards(chain_id, assets=None, to_address=None)` | Claim rewards | If `assets` omitted, adapter derives incentivized token list |

## Gotchas

- **Chain matters:** always pass the correct `chain_id` (Aave deployments are per-chain).
- **Variable rate mode:** borrowing/repaying uses variable rate mode (`interestRateMode=2`).
- **Collateral toggle:** supplying an asset doesn’t always mean it’s enabled as collateral; call `set_collateral(...)`.
- **Rewards inputs:** incentives are on **aTokens and debt tokens**, not the underlying. `claim_all_rewards(...)` can auto-derive the asset list.
- **Native handling:** `native=True` wraps/unwraps the chain’s wrapped native token and may return multiple tx hashes for one call.

