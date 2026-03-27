# HyperLend

## Overview

HyperLend is a lending protocol on HyperEVM (Aave V3 fork). It provides lending, borrowing, and collateral management for stablecoins and native HYPE.

- **Type**: `HYPERLEND`
- **Module**: `wayfinder_paths.adapters.hyperlend_adapter.adapter.HyperlendAdapter`
- **Capabilities**: `market.list`, `market.read`, `market.stable_markets`, `market.assets_view`, `market.rate_history`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.set`, `collateral.remove`

## Market Data

```bash
# Describe HyperLend adapter
poetry run wayfinder resource wayfinder://adapters/hyperlend_adapter

# Discover positions
poetry run wayfinder wallets --action discover_portfolio --wallet_label main --protocols '["hyperlend"]'
```

### Read Methods

| Method | Purpose | Output |
|--------|---------|--------|
| `get_stable_markets(*, required_underlying_tokens=None, buffer_bps=None, min_buffer_tokens=None)` | Stablecoin opportunity list with headroom | `StableMarketsHeadroomResponse` |
| `get_assets_view(*, user_address)` | User portfolio view | `AssetsView` — `assets: list[dict]`, optional `total_value` |
| `get_lend_rate_history(*, token, lookback_hours, force_refresh=None)` | Rate time series | `LendRateHistory` — `rates: list[dict]` (timestamped records) |
| `get_market_entry(*, token)` | Single market metadata | `MarketEntry` |
| `get_all_markets()` | On-chain market discovery via `UiPoolDataProvider` | `list[dict]` — comprehensive market data (see below) |
| `get_full_user_state(*, account, include_zero_positions=False)` | Aggregated user state | `dict` with `positions`, `accountData`, `assetsView` |

**Note:** `get_stable_markets()` and `get_assets_view()` do **not** take a `chain_id` parameter — they always query HyperEVM. All parameters are keyword-only.

### `get_all_markets()` return fields

Each market dict includes: `underlying`, `symbol`, `decimals`, `a_token`, `variable_debt_token`, `is_active`, `is_frozen`, `is_paused`, `is_siloed_borrowing`, `is_stablecoin`, `usage_as_collateral_enabled`, `borrowing_enabled`, `price_usd`, `supply_apr`, `supply_apy`, `variable_borrow_apr`, `variable_borrow_apy`, `available_liquidity`, `total_variable_debt`, `tvl`, `supply_cap`, `supply_cap_headroom`.

### Data Accuracy

- Only report values fetched from HyperLend endpoints (`market_entry`, `lend_rate_history`). Do **not** estimate or invent APYs.
- HyperlendClient methods use `_authed_request(...)` even for `/public/hyperlend/*` routes — auth via `config.json` or env vars is always required.

## Execution

HyperLend operations are executed via one-off scripts:

```bash
# Run a HyperLend script (dry run)
poetry run wayfinder run_script --script_path .wayfinder_runs/hyperlend_supply.py --wallet_label main
```

### Execution Methods

| Method | Purpose | Notes |
|--------|---------|-------|
| `lend(*, underlying_token, qty, chain_id, native=False, strategy_name=None)` | Supply to HyperLend | `qty` is raw int (wei); handles ERC20 approval automatically. `native=True` uses WrappedTokenGateway for HYPE. |
| `unlend(*, underlying_token, qty, chain_id, native=False, strategy_name=None)` | Withdraw from HyperLend | Same unit rules as `lend`. |
| `borrow(*, underlying_token, qty, chain_id, native=False)` | Borrow from HyperLend | Variable-rate borrowing (mode=2). `native=True` borrows WHYPE then unwraps to HYPE (returns two tx hashes). |
| `repay(*, underlying_token, qty, chain_id, native=False, repay_full=False)` | Repay a borrow | `repay_full=True` reads actual debt from chain, adds 0.01% buffer, sends exact repay amount. |
| `set_collateral(*, underlying_token, chain_id)` | Enable asset as collateral | Calls `Pool.setUserUseReserveAsCollateral(asset, true)`. |
| `remove_collateral(*, underlying_token, chain_id)` | Disable asset as collateral | Calls `Pool.setUserUseReserveAsCollateral(asset, false)`. |

All parameters are **keyword-only** (enforced with `*`). All methods return `tuple[bool, Any]` — `(True, tx_hash)` on success, `(False, error_message)` on failure.

### Native HYPE special handling

- **`lend(native=True)`**: Deposits HYPE via WrappedTokenGateway's `depositETH` — wraps HYPE to WHYPE automatically.
- **`unlend(native=True)`**: Withdraws via WrappedTokenGateway's `withdrawETH` — unwraps back to HYPE.
- **`borrow(native=True)`**: Borrows WHYPE from Pool, then unwraps to HYPE. Returns `{"borrow_tx": hash, "unwrap_tx": hash}` (two transactions).
- **`repay(native=True)`**: Repays via WrappedTokenGateway's `repayETH` — sends native HYPE as `msg.value`.
- **`repay(native=True, repay_full=True)`**: Reads variable debt token balance on-chain, checks available HYPE balance, adds 0.01% buffer, sends exact amount. Fails with descriptive error if insufficient balance.

### `strategy_name` parameter

`lend()` and `unlend()` accept an optional `strategy_name` for ledger tracking. When provided, the operation is recorded in the LedgerAdapter with USD value enrichment.

### Script Examples

**Supply (lend):**

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.hyperlend_adapter import HyperlendAdapter

CHAIN_ID = 999  # HyperEVM
UNDERLYING_TOKEN = "0x..."  # HyperEVM underlying token address
QTY = 100_000_000  # raw base units (example only)

async def main():
    adapter = get_adapter(HyperlendAdapter, "main")
    ok, tx_hash = await adapter.lend(
        underlying_token=UNDERLYING_TOKEN,
        qty=QTY,
        chain_id=CHAIN_ID,
    )
    print(ok, tx_hash)

if __name__ == "__main__":
    asyncio.run(main())
```

**Borrow and repay:**

```python
async def borrow_and_repay():
    adapter = get_adapter(HyperlendAdapter, "main")

    # Enable collateral first
    ok, tx = await adapter.set_collateral(underlying_token="0x...", chain_id=999)
    if not ok:
        print(f"Set collateral failed: {tx}")
        return

    # Borrow (variable rate)
    ok, tx = await adapter.borrow(underlying_token="0x...", qty=50_000_000, chain_id=999)
    if not ok:
        print(f"Borrow failed: {tx}")
        return
    print(f"Borrow tx: {tx}")

    # Repay full debt (reads actual debt from chain)
    ok, tx = await adapter.repay(
        underlying_token="0x...", qty=0, chain_id=999, repay_full=True
    )
    print(f"Repay tx: {tx}")
```

**Borrow native HYPE:**

```python
async def borrow_native_hype():
    adapter = get_adapter(HyperlendAdapter, "main")

    # Borrow HYPE (borrows WHYPE + unwraps in two txs)
    ok, result = await adapter.borrow(
        underlying_token="0x...",  # WHYPE address
        qty=1_000_000_000_000_000_000,  # 1 HYPE in wei
        chain_id=999,
        native=True,
    )
    if ok:
        print(f"Borrow tx: {result['borrow_tx']}")
        print(f"Unwrap tx: {result['unwrap_tx']}")
```

### Unit Conversion Best Practice

1. Resolve token decimals via TokenClient
2. Convert human-readable → raw int units
3. Call adapter methods with raw units

## HyperLend Stable Yield Strategy

For automated yield on HyperLend, use the dedicated strategy:

```bash
poetry run wayfinder run_strategy --strategy hyperlend_stable_yield_strategy --action status
poetry run wayfinder run_strategy --strategy hyperlend_stable_yield_strategy --action analyze --amount_usdc 100
poetry run wayfinder run_strategy --strategy hyperlend_stable_yield_strategy --action deposit --main_token_amount 100 --gas_token_amount 0.1
poetry run wayfinder run_strategy --strategy hyperlend_stable_yield_strategy --action update
```

## Gotchas

- **Chain**: HyperLend runs on HyperEVM (chain ID 999). Ensure your wallet has HYPE for gas.
- **RPC resolution**: Don't hardcode RPC URLs in scripts. The SDK resolves JSON-RPC via `web3_from_chain_id(999)` using `strategy.rpc_urls` when set, otherwise it falls back to Wayfinder's RPC proxy at `system.api_base_url` (auth via `system.api_key` / `WAYFINDER_API_KEY`).
- **Units are raw ints**: All execution methods expect **raw integer units** (wei for ERC20). Do not pass floats or human-readable values directly.
- **Keyword-only args**: All public methods use keyword-only parameters — you must use `adapter.lend(underlying_token=..., qty=..., chain_id=...)`, not positional args.
- **Native HYPE borrow returns two tx hashes**: When `native=True`, `borrow()` returns a dict with `borrow_tx` and `unwrap_tx`, not a single hash.
- **`repay_full` reads chain state**: The `repay_full=True` option queries actual variable debt from chain, so it may fail if the variable debt token can't be resolved. The adapter caches debt token addresses internally.
- **Supported assets**: Primarily stablecoins (USDT0) and HYPE. Check `get_all_markets()` for current offerings and whether borrowing is enabled.
- **No guessing yields**: Do not claim extra yield sources unless fetched from a concrete data source. Rates change frequently.
