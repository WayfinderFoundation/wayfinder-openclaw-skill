# Ethena (USDe → sUSDe Vault)

## Overview

Ethena’s canonical sUSDe staking vault is an ERC-4626 vault on **Ethereum mainnet**. The Ethena vault adapter supports:
- Spot APY estimation (derived from Ethena’s vesting model)
- Cooldown status (two-step withdrawals)
- User position snapshots (mainnet + OFT balances on other EVM chains)
- Execution: stake (deposit USDe) and withdraw via cooldown → claim

- **Type**: `ETHENA`
- **Module**: `wayfinder_paths.adapters.ethena_vault_adapter.adapter.EthenaVaultAdapter`
- **Capabilities**: `vault.read`, `vault.deposit`, `vault.withdraw`, `position.read`, `market.apy`, `lending.lend`, `lending.unlend`

## Key addresses (Ethereum mainnet)

| Contract | Address |
|----------|---------|
| USDe | `0x4c9EDD5852cd905f086C759E8383e09bff1E68B3` |
| sUSDe Vault | `0x9D39A5DE30e57443BfF2A8307A4256c8797A3497` |
| ENA | `0x57e114B691Db790C35207b2e685D4A43181e6061` |

On non-mainnet EVM chains, USDe/sUSDe/ENA are LayerZero OFTs. See `wayfinder_paths/core/constants/ethena_contracts.py` in the SDK for per-chain addresses.

## High-value reads

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_apy()` | Spot APY estimate | No |
| `get_cooldown(account)` | Cooldown end timestamp + underlying amount | No |
| `get_full_user_state(account, chain_id=1, include_apy=True, include_zero_positions=False)` | Balances + USDe equivalent + cooldown + optional APY | No |

### Script example: spot APY

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.ethena_vault_adapter import EthenaVaultAdapter

async def main() -> None:
    adapter = get_adapter(EthenaVaultAdapter)  # read-only
    ok, apy = await adapter.get_apy()
    if not ok:
        raise RuntimeError(apy)
    print("apy=", apy)

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

All execution methods return `(ok, data)` and require a signing wallet.

| Method | Purpose | Notes |
|--------|---------|-------|
| `deposit_usde(amount_assets, receiver=None)` | Stake USDe → receive sUSDe shares | May send ERC20 approval first |
| `request_withdraw_by_shares(shares)` | Start cooldown by sUSDe share amount | Mainnet-only |
| `request_withdraw_by_assets(assets)` | Start cooldown by USDe asset amount | Mainnet-only |
| `claim_withdraw(receiver=None, require_matured=True)` | Claim (unstake) after cooldown | Returns “no pending cooldown” when nothing is queued |

## Gotchas

- The vault is **mainnet-only**; for `chain_id != 1`, the adapter reads balances on the target chain but uses mainnet for cooldown and conversions.
- Withdraws are **two-step**: cooldown request, then claim after the cooldown matures.
- Amounts are raw ints (wei for USDe/sUSDe).
