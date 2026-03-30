---
name: wayfinder-lido
description: Stake ETH with Lido for liquid staking rewards — stake ETH to receive stETH, wrap stETH to wstETH, unwrap back, request and claim withdrawals, check conversion rates and positions. Use for stake Ethereum, staking rewards, stETH, wstETH, liquid staking, ETH yield, unstake, Lido withdrawal.
---

# Lido Liquid Staking

Lido is the largest ETH liquid staking protocol. Users deposit ETH and receive stETH, a liquid token that accrues staking rewards automatically. Lido handles validator operations and reward distribution, letting holders use their staked ETH across DeFi while earning yield.

## Overview

Lido exposes three core primitives:

- **stETH** — A rebasing ERC-20 that represents staked ETH. Balances increase daily as staking rewards accrue.
- **wstETH** — A non-rebasing wrapper around stETH. The token count stays fixed; its value relative to stETH grows over time. Preferred for DeFi integrations (vaults, lending, LPs) because it does not trigger unexpected balance changes.
- **Async Withdrawals** — Users request a withdrawal (stETH or wstETH to ETH) which enters a queue. Once finalized (can take several days), the ETH can be claimed. Large requests are automatically chunked by the adapter.

## SDK Usage

Access Lido through the `LidoAdapter` via the scripting helpers:

```python
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.lido_adapter import LidoAdapter

adapter = get_adapter(LidoAdapter)
```

### Methods

#### Staking and Wrapping

| Method | Description |
|--------|-------------|
| `stake_eth(amount_wei, chain_id=1)` | Stake ETH and receive stETH. Pass `receive="wstETH"` to stake and wrap in one flow (2 tx). Optional `referral` and `check_limits` params. |
| `wrap_steth(amount_steth_wei, chain_id=1)` | Wrap stETH into wstETH. Requires prior stETH approval. |
| `unwrap_wsteth(amount_wsteth_wei, chain_id=1)` | Unwrap wstETH back to stETH. |

#### Withdrawals

| Method | Description |
|--------|-------------|
| `request_withdrawal(asset, amount_wei, chain_id=1)` | Queue an async withdrawal. `asset` is `"stETH"` or `"wstETH"`. Mints an unstETH NFT. Large amounts are split automatically. Optional `owner` param. |
| `claim_withdrawals(request_ids, chain_id=1)` | Claim finalized withdrawal requests and receive ETH. The adapter resolves checkpoint hints. Optional `recipient` param. |

#### Read-Only Queries

| Method | Description |
|--------|-------------|
| `get_withdrawal_requests(account, chain_id=1)` | List all withdrawal requests for a user address. |
| `get_withdrawal_status(request_ids, chain_id=1)` | Check the finalization status of specific request IDs. |
| `get_rates(chain_id=1)` | Get current stETH/wstETH conversion rate data. |
| `get_full_user_state(account, chain_id=1)` | Complete user position: balances plus withdrawal queue snapshot. Optional `include_withdrawals`, `include_claimable`, `include_usd` flags. |

## Example: Stake ETH and Wrap to wstETH

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.lido_adapter import LidoAdapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_ETHEREUM

AMOUNT_WEI = 1_000_000_000_000_000_000  # 1 ETH

async def main() -> None:
    adapter = get_adapter(LidoAdapter)

    # Step 1 — Stake ETH to receive stETH
    ok, result = await adapter.stake_eth(
        amount_wei=AMOUNT_WEI,
        chain_id=CHAIN_ID_ETHEREUM,
    )
    if not ok:
        raise RuntimeError(result)
    print("Staked ETH for stETH:", result)

    # Step 2 — Wrap stETH into wstETH
    ok, result = await adapter.wrap_steth(
        amount_steth_wei=AMOUNT_WEI,
        chain_id=CHAIN_ID_ETHEREUM,
    )
    if not ok:
        raise RuntimeError(result)
    print("Wrapped stETH to wstETH:", result)

if __name__ == "__main__":
    asyncio.run(main())
```

## Important Notes

- **Withdrawals are async.** After requesting a withdrawal, finalization can take several days. Monitor status with `get_withdrawal_status` before attempting to claim.
- **Amounts are in wei.** All value parameters (`amount_wei`, `amount_steth_wei`, `amount_wsteth_wei`) expect raw integer wei values.
- **Ethereum mainnet only.** Use `chain_id=1` (or `CHAIN_ID_ETHEREUM`). Lido staking and withdrawals operate exclusively on Ethereum L1.
- **Specify the asset for withdrawals.** The `request_withdrawal` method requires an explicit `asset` parameter (`"stETH"` or `"wstETH"`).

## References

- [Lido Reference](references/lido.md)
- [Coding Interface](../coding-interface/SKILL.md)
- [Adapters Reference](../coding-interface/references/adapters.md)
- [Error Reference](references/errors.md)
