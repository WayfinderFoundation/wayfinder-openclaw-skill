# Lido (stETH / wstETH + Withdrawal Queue)

## Overview

Lido is Ethereum liquid staking:
- Stake ETH → receive stETH
- Wrap/unwrap stETH ↔ wstETH
- Async withdrawals via the WithdrawalQueue (request → claim later)

- **Type**: `LIDO`
- **Module**: `wayfinder_paths.adapters.lido_adapter.adapter.LidoAdapter`
- **Capabilities**: `staking.stake`, `staking.wrap`, `staking.unwrap`, `withdrawal.request`, `withdrawal.claim`, `position.read`

## Supported chains

Lido staking/withdrawals are **Ethereum mainnet** (`chain_id = 1`).

## High-value reads

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_rates(chain_id=1)` | stETH↔wstETH rate data | No |
| `get_withdrawal_requests(chain_id=1, account)` | User withdrawal requests | No |
| `get_withdrawal_status(chain_id=1, request_ids)` | Status of request IDs | No |
| `get_full_user_state(chain_id=1, account, include_zero_positions=False)` | Balances + withdrawal queue snapshot | No |

### Script example: user snapshot

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.lido_adapter import LidoAdapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_ETHEREUM

USER = "0x0000000000000000000000000000000000000000"

async def main() -> None:
    adapter = get_adapter(LidoAdapter)
    ok, state = await adapter.get_full_user_state(chain_id=CHAIN_ID_ETHEREUM, account=USER)
    if not ok:
        raise RuntimeError(state)
    print(state)

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

| Method | Purpose | Notes |
|--------|---------|-------|
| `stake_eth(amount_wei, receiver=None, wrap_to_wsteth=False)` | Stake ETH → stETH (or wstETH) | Sends ETH value |
| `wrap_steth(amount_steth_wei, receiver=None)` | stETH → wstETH | Requires stETH approval |
| `unwrap_wsteth(amount_wsteth_wei, receiver=None)` | wstETH → stETH | — |
| `request_withdrawal(amount, is_wsteth=False, receiver=None)` | Request async withdrawal | Produces request IDs |
| `claim_withdrawals(request_ids, receiver=None)` | Claim finalized withdrawals | Adapter finds required hints |

## Gotchas

- Withdrawals are **async**: a request can take time to finalize before it is claimable.
- Requests/claims are sensitive to exact token (stETH vs wstETH); be explicit about `is_wsteth`.
- Amounts are raw ints (wei).
