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

EigenCloud adapter is **Ethereum mainnet only** (it does not take a `chain_id` parameter).

## High-value reads

Primary adapter: `wayfinder_paths/adapters/eigencloud_adapter/adapter.py`

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_all_markets(include_total_shares=True, include_share_to_underlying=True)` | Strategy list + underlying metadata | No |
| `get_delegation_state(account=None)` | Current delegation + operator | No |
| `get_pos(account=None, include_usd=False)` | Deposited/withdrawable shares by strategy | No |
| `get_rewards_metadata(account=None)` | Current distribution root + claimer | No |
| `get_full_user_state(account, include_usd=False, include_queued_withdrawals=True, withdrawal_roots=None, include_rewards_metadata=True)` | Aggregated snapshot (you supply withdrawal roots) | No |

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
| `delegate(operator, approver_signature=b"", approver_expiry=0, approver_salt=None)` | Delegate to an operator | Some operators require approver signatures |
| `undelegate(staker=None, include_withdrawal_roots=True)` | Undelegate | Can return `withdrawal_roots` extracted from tx logs |
| `redelegate(new_operator, approver_signature=b"", approver_expiry=0, approver_salt=None, include_withdrawal_roots=True)` | Change delegation | Can return `withdrawal_roots` extracted from tx logs |
| `queue_withdrawals(strategies, deposit_shares, include_withdrawal_roots=True)` | Queue withdrawals | Withdrawals are delayed (queue + completion) |
| `complete_withdrawal(withdrawal_root, receive_as_tokens=True, tokens_override=None)` | Complete a queued withdrawal | Adapter can resolve the token list; `tokens_override` rarely needed |
| `claim_rewards(claim, recipient)` | Claim rewards | Claim structs are offchain-prepared |
| `claim_rewards_batch(claims, recipient)` | Claim rewards (batch) | Claim structs are offchain-prepared |
| `claim_rewards_calldata(calldata, value=0)` | Claim rewards (raw calldata fallback) | Use calldata from EigenLayer app/CLI/indexer |

## Gotchas

- **Share accounting**: positions are in strategy shares; converting to underlying depends on strategy.
- **Withdrawals are delayed**: queue first, then complete after the delay window.
- **Rewards require offchain data**: you can’t “guess” a claim; use the adapter’s metadata helpers or your own indexer.
