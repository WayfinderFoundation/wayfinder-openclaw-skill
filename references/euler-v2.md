# Euler v2 (EVK / eVaults)

## Overview

Euler v2 markets are **vaults** (EVK / eVaults). The vault address is both:
- the market identifier, and
- the ERC-4626 share token contract.

The Euler v2 adapter supports:
- Verified vault discovery (by “perspective”)
- Vault metadata + supply/borrow APYs + LTV rows (via lenses)
- Per-account position snapshots (enabled vaults + balances/flags)
- Execution via **EVC (Ethereum Vault Connector)** batching for deposits/withdrawals/borrows/repays

- **Type**: `EULER_V2`
- **Module**: `wayfinder_paths.adapters.euler_v2_adapter.adapter.EulerV2Adapter`
- **Capabilities**: `market.list`, `market.read`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.set`, `collateral.remove`

## Supported chains

Euler v2 chain support is explicit in `wayfinder_paths/core/constants/euler_v2_contracts.py` (`EULER_V2_BY_CHAIN`). As of the pinned SDK ref in `sdk-version.md`:

| Network | `chain_id` |
|--------|------------|
| Ethereum | `1` |
| BSC | `56` |
| Unichain | `130` |
| Monad | `143` |
| Sonic | `146` |
| TAC | `239` |
| HyperEVM | `999` |
| Swell | `1923` |
| Base | `8453` |
| Plasma | `9745` |
| Arbitrum | `42161` |
| Avalanche | `43114` |
| Linea | `59144` |
| BOB | `60808` |
| Berachain | `80094` |

## High-value reads

Primary adapter: `wayfinder_paths/adapters/euler_v2_adapter/adapter.py`

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_verified_vaults(chain_id, perspective="governed", limit=None)` | Verified vault addresses | No |
| `get_all_markets(chain_id, perspective="governed", limit=None, concurrency=10)` | Vault list + APYs + caps + LTV rows | No |
| `get_vault_info_full(chain_id, vault)` | Raw-ish VaultLens `getVaultInfoFull` output | No |
| `get_full_user_state(chain_id, account, include_zero_positions=False)` | Enabled vaults + balances + flags (one chain) | No (if you pass `account`) |

### Script example: list markets

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.euler_v2_adapter import EulerV2Adapter
from wayfinder_paths.core.constants.chains import CHAIN_ID_BASE

async def main() -> None:
    adapter = get_adapter(EulerV2Adapter)  # read-only
    ok, markets = await adapter.get_all_markets(chain_id=CHAIN_ID_BASE, perspective="governed", limit=50)
    if not ok:
        raise RuntimeError(markets)
    for m in markets[:10]:
        print(m.get("asset_symbol"), "supply_apy=", m.get("supply_apy"), "borrow_apy=", m.get("borrow_apy"))

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

Euler v2 execution requires wiring:
- `config["strategy_wallet"]["address"]`, and
- passing `strategy_wallet_signing_callback` to the adapter.

In `.wayfinder_runs/` scripts:

```python
from wayfinder_paths.mcp.scripting import get_adapter, _resolve_wallet
from wayfinder_paths.adapters.euler_v2_adapter import EulerV2Adapter

sign_cb, addr = _resolve_wallet("main")
adapter = get_adapter(
    EulerV2Adapter,
    config_overrides={"strategy_wallet": {"address": addr}},
    strategy_wallet_signing_callback=sign_cb,
)
```

Key execution methods:

| Method | Purpose | Notes |
|--------|---------|-------|
| `lend(chain_id, vault, amount, receiver=None)` | Deposit underlying into a vault | May send ERC20 approval first; deposit is EVC-batched |
| `unlend(chain_id, vault, amount=0, receiver=None, withdraw_full=False)` | Withdraw underlying | `withdraw_full=True` redeems **all shares** |
| `set_collateral(chain_id, vault, use_as_collateral=True, account=None)` | Enable/disable collateral | EVC `enableCollateral/disableCollateral` |
| `borrow(chain_id, vault, amount, receiver=None, collateral_vaults=None, enable_controller=True)` | Borrow underlying | Can batch-enable collateral + controller before borrow |
| `repay(chain_id, vault, amount, receiver=None, repay_full=False)` | Repay debt | `repay_full=True` uses MAX semantics; approval may be needed |

## Gotchas

- **Units are raw ints** of the underlying token.
- **Collateral isn’t automatic**: depositing does not enable collateral; call `set_collateral(...)` (or pass `collateral_vaults=[...]` to `borrow(...)`).
- **Controller matters**: borrows generally require a controller vault (`enable_controller=True` by default).
- **Perspectives gate discovery**: `perspective="governed"` is the safest default; other perspectives can include riskier/unreviewed vaults.
