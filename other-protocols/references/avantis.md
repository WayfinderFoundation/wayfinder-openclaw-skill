# Avantis (avUSDC Vault on Base)

## Overview

Avantis provides an **ERC-4626 vault** on **Base** where users can deposit USDC and receive vault shares (avUSDC), and later redeem shares back to USDC.

- **Type**: `AVANTIS`
- **Module**: `wayfinder_paths.adapters.avantis_adapter.adapter.AvantisAdapter`
- **Capabilities**: `market.list`, `position.read`, `vault.deposit`, `vault.withdraw`

## High-value reads

Primary adapter: `wayfinder_paths/adapters/avantis_adapter/adapter.py`

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_all_markets()` | Single “market” describing the configured vault (TVL, supply, share price) | No |
| `get_vault_manager_state()` | Read Avantis vault manager state (buffer ratio, balances, rewards, etc.) | No |
| `get_pos(account=..., include_usd=False)` | Position snapshot (shares, assets, maxRedeem/maxWithdraw) | No (if you pass `account`) |
| `get_full_user_state(account=..., include_usd=False)` | Standardized user state wrapper | No (if you pass `account`) |

### Script example: read-only position

```python
import asyncio

from wayfinder_paths.adapters.avantis_adapter import AvantisAdapter
from wayfinder_paths.mcp.scripting import get_adapter

USER = "0x0000000000000000000000000000000000000000"

async def main() -> None:
    adapter = get_adapter(AvantisAdapter)  # read-only
    ok, pos = await adapter.get_pos(account=USER, include_usd=True)
    if not ok:
        raise RuntimeError(pos)
    print(pos)

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

Execution requires a signing wallet and a wallet address:

```python
from wayfinder_paths.adapters.avantis_adapter import AvantisAdapter
from wayfinder_paths.mcp.scripting import get_adapter

adapter = get_adapter(AvantisAdapter, "main")  # wires sign_callback + wallet_address
```

| Method | Purpose | Notes |
|--------|---------|-------|
| `deposit(amount=...)` | Deposit USDC into the vault | `amount` is **raw USDC units** (6 decimals on Base) |
| `withdraw(amount=...)` | Redeem vault shares back to USDC | `amount` is **raw share units** (avUSDC share decimals) |

## Gotchas

- **Base-only:** the adapter is configured for Base (`chain_id=8453`).
- **Not lending:** `borrow()`/`repay()` are intentionally unsupported.
- **Reads may still need an address:** if you call `get_pos()` without `account=...`, it falls back to `self.wallet_address` (so either pass `account` or construct with a wallet).
- **USD values are best-effort:** `include_usd=True` relies on token price metadata availability; treat it as enrichment, not a source of truth.

