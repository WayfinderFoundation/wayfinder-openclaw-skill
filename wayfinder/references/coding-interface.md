# Coding Interface (Custom Scripts)

Use this guide when pre-built CLI commands aren't sufficient and you need to write a custom Python script for a multi-step DeFi flow.

## Where scripts live

Scripts must live in the SDK runs directory (sandboxed):

- Default: `$WAYFINDER_SDK_PATH/.wayfinder_runs/`
- Override: `$WAYFINDER_RUNS_DIR`

Run them via the CLI tool:

```bash
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --wallet_label main
```

`run_script` refuses to execute anything outside the runs directory.

## Before you write code (don’t guess)

Prefer fetching authoritative info on demand instead of relying on stale docs:

- **Adapter list + capabilities:** `poetry run wayfinder resource wayfinder://adapters` and `wayfinder://adapters/{name}`
- **Strategy list + wiring:** `poetry run wayfinder resource wayfinder://strategies` and `wayfinder://strategies/{name}`
- **Token IDs + decimals:** `poetry run wayfinder resource wayfinder://tokens/search/<chain_code>/<query>` and `wayfinder://tokens/gas/<chain_code>`

For deeper adapter workflow docs (method names, gotchas), use this repo’s pull script from the skill folder (`wayfinder/`):

```bash
./scripts/pull-sdk-ref.sh --list
./scripts/pull-sdk-ref.sh brap aave morpho
./scripts/pull-sdk-ref.sh --version
```

## Basic script structure

```python
#!/usr/bin/env python3
import asyncio

async def main() -> None:
    ...

if __name__ == "__main__":
    asyncio.run(main())
```

Run via:

```bash
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --wallet_label main
```

## Using `get_adapter()`

`get_adapter()` wires config + (optional) signing for adapters:

```python
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter

# Write paths (signing): pass a config.json wallet label
moonwell = get_adapter(MoonwellAdapter, "main")

# Read-only paths: omit wallet label
moonwell_readonly = get_adapter(MoonwellAdapter)
```

Notes:
- `wallet_label` must exist in `config.json["wallets"]` and include `private_key_hex` for local signing.
- Most adapter methods return `(ok: bool, result_or_error)`. Always unpack and check `ok`.

## Web3 / RPC access

For raw chain reads/writes not exposed by an adapter:

```python
import asyncio
from wayfinder_paths.core.utils.web3 import web3_from_chain_id

async def main() -> None:
    async with web3_from_chain_id(8453) as w3:  # Base
        block = await w3.eth.block_number
        print("block:", block)

if __name__ == "__main__":
    asyncio.run(main())
```

Do not hardcode RPC URLs in scripts. `web3_from_chain_id(...)` resolves RPCs from `config.json["strategy"]["rpc_urls"]` when set; otherwise it falls back to Wayfinder’s RPC proxy at `system.api_base_url` (auth via `system.api_key` / `WAYFINDER_API_KEY`).

## Minimal verified examples

These examples are intentionally small and use only surfaces that exist in the SDK (v0.5.0).

### Token lookup (IDs, decimals, gas token)

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.token_adapter import TokenAdapter

async def main() -> None:
    token = get_adapter(TokenAdapter)

    ok, usdc = await token.get_token("usd-coin-base")
    if not ok:
        raise RuntimeError(usdc)
    print("USDC decimals:", usdc["decimals"], "address:", usdc["address"])

    ok, gas = await token.get_gas_token("base")
    if not ok:
        raise RuntimeError(gas)
    print("Base gas token:", gas["symbol"], gas["token_id"])

if __name__ == "__main__":
    asyncio.run(main())
```

### On-chain balance (raw + decimals)

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.balance_adapter import BalanceAdapter

WALLET = "0x0000000000000000000000000000000000000000"

async def main() -> None:
    bal = get_adapter(BalanceAdapter)
    ok, out = await bal.get_balance_details(wallet_address=WALLET, token_id="usd-coin-base")
    if not ok:
        raise RuntimeError(out)
    print(out)

if __name__ == "__main__":
    asyncio.run(main())
```

For full portfolio balances (USD totals + chain breakdown), prefer the MCP resource:

```bash
poetry run wayfinder resource wayfinder://balances/main
```

### BRAP swap (low-level, raw units)

In scripts, prefer the CLI flow (`quote_swap` → `execute`) unless you explicitly need BRAP internals.

If you do use `BRAPAdapter` directly, **amounts must be raw base units**:

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.mcp.utils import parse_amount_to_raw
from wayfinder_paths.adapters.brap_adapter import BRAPAdapter
from wayfinder_paths.adapters.token_adapter import TokenAdapter

async def main() -> None:
    brap = get_adapter(BRAPAdapter, "main")
    token = get_adapter(TokenAdapter)

    ok, from_meta = await token.get_token("usd-coin-base")
    if not ok:
        raise RuntimeError(from_meta)

    amount_raw = str(parse_amount_to_raw("100", int(from_meta["decimals"])))  # 100 USDC
    sender = brap.config["strategy_wallet"]["address"]

    ok, out = await brap.swap_from_token_ids(
        from_token_id="usd-coin-base",
        to_token_id="ethereum-base",
        from_address=sender,
        amount=amount_raw,
        slippage=0.005,  # 0.5% (decimal fraction)
    )
    print(ok, out)

if __name__ == "__main__":
    asyncio.run(main())
```

## Running scripts safely

`run_script` has no built-in “dry-run vs live” switch. If your script can move funds:

1) Implement script-level flags like `--dry-run` and `--confirm-live`
2) Pass them via `--args`

```bash
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--dry-run"]' --wallet_label main
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--confirm-live"]' --wallet_label main
```

For fund-moving changes, prefer fork-mode scenario testing (Gorlami) before broadcasting. See [simulation-dry-run.md](simulation-dry-run.md).

## Environment variables

- `WAYFINDER_SDK_PATH` — path to the `wayfinder-paths-sdk` checkout
- `WAYFINDER_CONFIG_PATH` — path to `config.json` (default: `$WAYFINDER_SDK_PATH/config.json`)
- `WAYFINDER_RUNS_DIR` — overrides the runs directory (default: `.wayfinder_runs/` under the SDK root)
- `WAYFINDER_API_KEY` — Wayfinder API key (fallback if not in `config.json["system"]["api_key"]`)

