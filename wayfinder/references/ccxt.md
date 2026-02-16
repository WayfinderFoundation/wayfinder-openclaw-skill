# CCXT (Centralized Exchanges)

## Overview

The SDK includes a `ccxt_adapter` that acts as a **multi-exchange factory** for centralized exchanges (CEXes). Each configured exchange becomes a property on the adapter (e.g. `adapter.aster`, `adapter.binance`), and you call the CCXT unified API on that exchange object.

- **Type**: `CCXT`
- **Module**: `wayfinder_paths.adapters.ccxt_adapter.adapter.CCXTAdapter`
- **Capabilities**: `exchange.factory`

## When to use (and when not to)

- Use for CEX workflows (Aster, Binance, etc.) **when the user has API credentials** and explicitly wants centralized exchange data or trading.
- Do **not** use CCXT for Hyperliquid by default. Prefer the native Wayfinder Hyperliquid surfaces (`hyperliquid` resources + `hyperliquid_execute`) unless the user explicitly asks for CCXT/Hyperliquid.

## Config (`config.json`)

Add a `ccxt` section with exchange IDs and credentials (exchange IDs must match CCXT exchange ids):

```json
{
  "ccxt": {
    "aster": { "apiKey": "…", "secret": "…" },
    "binance": { "apiKey": "…", "secret": "…", "enableRateLimit": true },
    "hyperliquid": { "walletAddress": "0x...", "privateKey": "0x..." }
  }
}
```

Notes:
- Credentials are passed straight through to each CCXT exchange constructor; exchange-specific params (e.g. `password`, `uid`, `options`) are supported.
- Exchange IDs must match CCXT’s exchange ids (e.g. `binance`, `bybit`, `aster`, `hyperliquid`).
- Always `await adapter.close()` in a `finally` to avoid leaking HTTP sessions.

### Credentials quick reference

| Exchange | Required params |
|----------|----------------|
| binance | `apiKey`, `secret` |
| hyperliquid | `walletAddress`, `privateKey` |
| aster | `apiKey`, `secret` |
| bybit | `apiKey`, `secret` |
| dydx | `apiKey`, `secret`, `password` |

## Init patterns

### Config-driven (recommended)

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.ccxt_adapter import CCXTAdapter

async def main():
    adapter = get_adapter(CCXTAdapter)
    try:
        ticker = await adapter.binance.fetch_ticker("BTC/USDT")
        print(ticker.get("last"))
    finally:
        await adapter.close()

asyncio.run(main())
```

### Explicit exchanges kwarg (no `config.json` required)

```python
import asyncio
from wayfinder_paths.adapters.ccxt_adapter import CCXTAdapter

async def main():
    adapter = CCXTAdapter(exchanges={"aster": {}, "binance": {}})
    try:
        ticker = await adapter.aster.fetch_ticker("ETH/USDT")
        print(ticker.get("last"))
    finally:
        await adapter.close()

asyncio.run(main())
```

The `exchanges=` kwarg takes priority over `config["ccxt"]`.

## Running CCXT scripts

CCXT is not exposed as a top-level `poetry run wayfinder` command. Use a one-off script via `run_script`.

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.ccxt_adapter import CCXTAdapter

async def main():
    adapter = get_adapter(CCXTAdapter)
    try:
        ticker = await adapter.aster.fetch_ticker("ETH/USDT")
        print(ticker.get("last"))
    finally:
        await adapter.close()

if __name__ == "__main__":
    asyncio.run(main())
```

Run it:

```bash
poetry run wayfinder run_script --script_path .wayfinder_runs/ccxt_ticker.py --wallet_label main
```

## Examples

### Multi-exchange comparison

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.ccxt_adapter import CCXTAdapter

async def main():
    adapter = get_adapter(CCXTAdapter)
    try:
        binance = await adapter.binance.fetch_ticker("ETH/USDT")
        aster = await adapter.aster.fetch_ticker("ETH/USDT")
        print("Binance:", binance.get("last"))
        print("Aster:  ", aster.get("last"))
    finally:
        await adapter.close()

asyncio.run(main())
```

### Hyperliquid via CCXT (when explicitly requested)

Hyperliquid defaults to swap/perps in CCXT; perp symbols use the `:USDC` suffix:

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.ccxt_adapter import CCXTAdapter

async def main():
    adapter = get_adapter(CCXTAdapter)
    try:
        ticker = await adapter.hyperliquid.fetch_ticker("ETH/USDC:USDC")
        print("ETH perp last:", ticker.get("last"))
    finally:
        await adapter.close()

asyncio.run(main())
```

## Gotchas (read before writing automation)

- **Always close**: Each exchange holds open HTTP sessions; always `await adapter.close()` in a `finally`.
- **Hyperliquid auth**: Hyperliquid CCXT uses wallet auth (`walletAddress`, `privateKey`), not `apiKey`/`secret`.
- **Hyperliquid spot vs perp**: CCXT Hyperliquid defaults to `swap`. For spot, use spot symbols and set `params={"type":"spot"}` as needed.
- **Symbol formats vary**: Many perps/futures use suffixes like `ETH/USDT:USDT`. Always `await exchange.load_markets()` and inspect `exchange.markets` for available symbols.
- **Rate limits**: If you’re making many calls, set `enableRateLimit: true` (or manage concurrency yourself). Don’t double-throttle with both strict semaphores and `enableRateLimit`.
- **`get_adapter(CCXTAdapter)` with no `ccxt` config is “empty”**: If `config.json` has no `ccxt` section, `get_adapter(CCXTAdapter)` loads zero exchanges (accessing `adapter.binance` raises `AttributeError`). For public-data-only access, construct `CCXTAdapter(exchanges={...})` directly.
- **Prefer native Hyperliquid surfaces for reads**: For funding history/meta/orderbooks, prefer the SDK/Wayfinder Hyperliquid adapter and resources unless CCXT is explicitly required.
- **Exchange instances are properties**: `await adapter.binance.fetch_ticker(...)` is correct; `await adapter.fetch_ticker("binance", ...)` is not.
- **Aster quirks**:
  - Minimum order sizes can be large (e.g., BTC min ~0.001). Check `exchange.markets[symbol]["limits"]["amount"]["min"]` before ordering.
  - `fetch_balance()` may underreport futures margin; don’t hard-gate execution on it.
  - Market orders can return `status="open"` and `filled=0` initially; confirm via `fetch_positions()` after a short delay.

## Common CCXT calls

- `fetch_ticker(symbol)` / `fetch_order_book(symbol)`
- `fetch_balance()`
- `create_order(symbol, "market"|"limit", "buy"|"sell", amount, price?)`
- `cancel_order(id, symbol?)`
- `fetch_open_orders(symbol?)`

Always `await adapter.close()` to avoid leaking sessions.
