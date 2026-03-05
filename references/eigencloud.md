# EigenCloud (EigenLayer Restaking)

## Overview

EigenCloud (EigenLayer) is a restaking system on **Ethereum mainnet** with:
- Strategy-based share accounting (not ERC-4626)
- Optional delegation
- Delayed withdrawals via an on-chain withdrawal queue
- Rewards claimed via offchain-prepared claim structs / merkle proofs

The EigenCloud adapter supports:
- Strategy list / market metadata
- Position snapshots (restaked shares, delegation, queued withdrawals)
- Execution: deposit, delegate/undelegate/redelegate, queue withdrawals, complete withdrawals, claim rewards

- **Type**: `EIGENCLOUD`
- **Module**: `wayfinder_paths.adapters.eigencloud_adapter.adapter.EigenCloudAdapter`
- **Capabilities**: `market.list`, `position.read`, `restaking.deposit`, `restaking.withdraw.queue`, `restaking.withdraw.complete`, `delegation.delegate`, `delegation.undelegate`, `delegation.redelegate`, `rewards.read`, `rewards.claim`

## Supported chains

EigenCloud execution is **Ethereum mainnet only** (`chain_id = 1`).

## High-value reads

Primary adapter: `wayfinder_paths/adapters/eigencloud_adapter/adapter.py`

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_all_markets(include_total_shares=True, include_share_to_underlying=True)` | Strategy list + underlying metadata | No |
| `get_delegation_state(account)` | Current delegation + operator | No |
| `get_full_user_state(account, include_rewards=True, include_usd=True, include_zero_positions=False)` | Aggregated snapshot: deposits, delegation, withdrawals, optional rewards | No |

### Script example: list strategies

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.eigencloud_adapter import EigenCloudAdapter

async def main() -> None:
    adapter = get_adapter(EigenCloudAdapter)  # read-only
    ok, markets = await adapter.get_all_markets()
    if not ok:
        raise RuntimeError(markets)
    for m in markets:
        print(m.get("strategy_name"), m.get("underlying_symbol"))

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

Execution requires:
- `sign_callback`, and
- `wallet_address` (the signer address).

Key execution methods:

| Method | Purpose | Notes |
|--------|---------|-------|
| `deposit(strategy, amount, token=None, check_whitelist=True)` | Deposit/restake into a strategy | Approves `StrategyManager` first if needed |
| `delegate(operator)` | Delegate to an operator | Optional; can be changed |
| `undelegate()` | Undelegate | Starts exit path depending on position |
| `redelegate(new_operator)` | Change delegation | Convenience wrapper |
| `queue_withdrawals(strategies, shares, withdrawer=None)` | Queue withdrawals | Withdrawals are delayed (queue + completion) |
| `complete_withdrawal(withdrawal, tokens, middleware_times_index=0, receive_as_tokens=True)` | Complete a queued withdrawal | Requires the queued withdrawal struct + token list |
| `claim_rewards(claim, require_metadata=True)` | Claim rewards | Claim structs are offchain-prepared |

## Gotchas

- **Share accounting**: positions are in strategy shares; converting to underlying depends on strategy.
- **Withdrawals are delayed**: queue first, then complete after the delay window.
- **Rewards require offchain data**: you can’t “guess” a claim; use the adapter’s metadata helpers or your own indexer.
