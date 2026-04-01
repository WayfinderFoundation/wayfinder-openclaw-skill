---
name: wayfinder-aave
description: Lend and borrow on Aave V3 — supply collateral, borrow assets, repay loans, manage collateral flags, claim rewards, check health factor, view market rates and user positions. Multi-chain (Ethereum, Base, Arbitrum, Optimism, Polygon). Use for Aave, supply, borrow, collateral, health factor, liquidation risk, interest rates, lending protocol, deposit, repay.
---

# Aave V3 Lending and Borrowing

Aave V3 is a decentralized, multi-chain lending and borrowing protocol. Users can supply assets to earn yield, borrow against their collateral, and manage positions across Ethereum, Base, Arbitrum, and other supported EVM chains. The Wayfinder Aave V3 adapter provides full access to market data, position reads, and execution operations.

## Capabilities

- **Market data** — list all markets with rates, caps, LTV parameters, and optional reward incentives
- **Position reads** — snapshot user deposits, borrows, and collateral status per chain or across all supported chains
- **Lending** — supply and withdraw assets
- **Borrowing** — borrow assets and repay debt (variable rate mode)
- **Collateral management** — enable or disable supplied assets as collateral
- **Rewards** — claim accrued incentive rewards on aTokens and debt tokens

## CLI Usage

Aave V3 does not have direct CLI commands. All interactions use the coding interface via Python scripts and the `get_adapter` helper.

### Adapter Setup

```python
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.aave_v3_adapter import AaveV3Adapter

# Read-only (market data, position queries)
adapter = get_adapter(AaveV3Adapter)

# With signing wallet (fund-moving operations)
adapter = get_adapter(AaveV3Adapter, "main")
```

### Read Methods

These methods do not require a signing wallet.

| Method | Description |
|--------|-------------|
| `get_all_markets(chain_id, include_rewards=False)` | Returns all markets on a chain with point-in-time rates, caps, LTV, and optional reward data |
| `get_full_user_state_per_chain(chain_id, account, include_rewards=False, include_zero_positions=False)` | User position snapshot for a single chain — deposits, borrows, collateral flags |
| `get_full_user_state(account, include_rewards=False, include_zero_positions=False)` | User position snapshot across all supported chains |

### Execution Methods

All execution methods require a signing wallet: `get_adapter(AaveV3Adapter, "main")`.

| Method | Description |
|--------|-------------|
| `lend(chain_id, underlying_token, qty, native=False)` | Supply an asset as collateral. `qty` is in raw base units (wei). Set `native=True` for the chain's native token. |
| `unlend(chain_id, underlying_token, qty, native=False, withdraw_full=False)` | Withdraw a supplied asset. Use `withdraw_full=True` to withdraw the entire balance. |
| `borrow(chain_id, underlying_token, qty, native=False)` | Borrow an asset against collateral. Uses variable rate mode. |
| `repay(chain_id, underlying_token, qty, native=False, repay_full=False)` | Repay borrowed debt. Use `repay_full=True` for full repayment (MAX_UINT256 semantics). |
| `set_collateral(chain_id, underlying_token, use_as_collateral=True)` | Enable a supplied asset as collateral. Pass the underlying token address (not the aToken). |
| `remove_collateral(chain_id, underlying_token)` | Disable a supplied asset as collateral. Convenience wrapper around `set_collateral`. |
| `claim_all_rewards(chain_id, assets=None, to_address=None)` | Claim accrued incentive rewards. If `assets` is omitted, the adapter auto-derives the incentivized token list. |

All methods return a tuple `(success: bool, result)`. Check `success` before using the result.

## Example Script

A basic supply (lend) flow with safety checks:

```python
#!/usr/bin/env python3
"""Supply USDC to Aave V3 on Arbitrum."""
import asyncio
import sys
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.aave_v3_adapter import AaveV3Adapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_ARBITRUM

USDC_ARBITRUM = "0xaf88d065e77c8cC2239327C5EDb3A432268e5831"
AMOUNT_WEI = 100_000_000  # 100 USDC (6 decimals)

async def main():
    force = "--force" in sys.argv

    adapter = get_adapter(AaveV3Adapter, "main")

    # 1. Check current position
    ok, state = await adapter.get_full_user_state_per_chain(
        chain_id=CHAIN_ID_ARBITRUM,
        account=adapter.wallet.address,
    )
    if not ok:
        raise RuntimeError(f"Failed to read state: {state}")

    print(f"Health factor: {state.get('health_factor')}")
    print(f"Total collateral USD: {state.get('total_collateral_usd')}")
    print(f"Total debt USD: {state.get('total_debt_usd')}")

    if not force:
        print("\nDry run complete. Pass --force to execute.")
        return

    # 2. Supply USDC
    ok, result = await adapter.lend(
        chain_id=CHAIN_ID_ARBITRUM,
        underlying_token=USDC_ARBITRUM,
        qty=AMOUNT_WEI,
    )
    if not ok:
        raise RuntimeError(f"Lend failed: {result}")
    print(f"Supply successful: {result}")

    # 3. Enable as collateral
    ok, result = await adapter.set_collateral(
        chain_id=CHAIN_ID_ARBITRUM,
        underlying_token=USDC_ARBITRUM,
    )
    if not ok:
        raise RuntimeError(f"Set collateral failed: {result}")
    print(f"Collateral enabled: {result}")

if __name__ == "__main__":
    asyncio.run(main())
```

Save scripts to `.wayfinder_runs/` and execute via `run_script`:

```bash
poetry run wayfinder run_script --script_path .wayfinder_runs/aave_supply.py --args '["--dry-run"]' --wallet_label main
poetry run wayfinder run_script --script_path .wayfinder_runs/aave_supply.py --args '["--force"]' --wallet_label main
```

## Supported Chains

Aave V3 is deployed across multiple chains. Always pass the correct `chain_id` — deployments are per-chain. Use the chain constants from `wayfinder_paths.core.constants.chains`:

- Ethereum (`CHAIN_ID_ETHEREUM`)
- Arbitrum (`CHAIN_ID_ARBITRUM`)
- Base (`CHAIN_ID_BASE`)
- Optimism (`CHAIN_ID_OPTIMISM`)
- Polygon (`CHAIN_ID_POLYGON`)

Check the adapter or market data for the full list of currently supported chains.

## Important Notes

- **Amounts are in raw base units (wei).** For example, 100 USDC (6 decimals) is `100_000_000`, and 1 ETH (18 decimals) is `1_000_000_000_000_000_000`. Always convert human-readable amounts to raw units before passing to adapter methods.
- **Always check user state before operations.** Query `get_full_user_state_per_chain` to verify balances, health factor, and collateral status before executing.
- **Monitor health factor.** Borrowing reduces the health factor. A health factor below 1.0 triggers liquidation. Always verify the health factor after borrows and before withdrawals.
- **Variable rate mode only.** All borrows and repayments use variable rate mode (`interestRateMode=2`).
- **Supplying does not auto-enable collateral.** After supplying an asset, explicitly call `set_collateral` if you intend to borrow against it.
- **Native token handling.** Pass `native=True` when supplying/borrowing the chain's native token (e.g., ETH on Ethereum). This may result in multiple transactions for wrapping/unwrapping.
- **Rewards are on aTokens and debt tokens**, not the underlying. `claim_all_rewards` can auto-derive the incentivized asset list when `assets` is omitted.

## SparkLend

SparkLend (see `skills/lending-protocols/`) extends the Aave V3 adapter architecture with additional support for native ETH operations. If your use case involves SparkLend, refer to the lending-protocols skill for SparkLend-specific details.

## References

- [Aave V3 Reference](references/aave-v3.md) — Full adapter API reference, method signatures, gotchas, and script examples
- [Coding Interface](../coding-interface/SKILL.md) — Script execution, `get_adapter` usage, testing workflow, and adapter discovery
- [Adapters Reference](../coding-interface/references/adapters.md) — All available adapters, capabilities, and configuration
- [Error Reference](references/errors.md)
