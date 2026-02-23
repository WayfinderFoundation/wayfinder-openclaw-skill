# Coding Interface for Custom Operations

Use this guide when pre-built commands aren't sufficient and you need to write custom Python scripts for complex multi-step DeFi operations.

## When to Use Custom Scripts

- **Multi-step atomic flows** — operations that must succeed together or not at all
- **Custom logic** — conditional execution based on market state
- **Batched operations** — multiple protocol interactions in sequence
- **Complex calculations** — position sizing, rebalancing logic
- **Protocol combinations** — bridging multiple adapters in one flow

## Script Location

All scripts must live in the `.wayfinder_runs/` directory inside `$WAYFINDER_SDK_PATH` (default: `$HOME/wayfinder-paths-sdk`) (or `$WAYFINDER_RUNS_DIR`). This directory is:
- Git-ignored (except README.md)
- Sandboxed — `run_script` only executes scripts inside this directory
- Session-specific — use for one-off executions, not permanent strategies

```bash
mkdir -p "${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}/.wayfinder_runs"
```

## Referencing the SDK Source

Before writing a script, **pull the detailed reference docs** for the relevant adapter or strategy:

```bash
# Pull docs for the adapter you're using (reads from pinned SDK version in sdk-version.md)
./scripts/pull-sdk-ref.sh moonwell
./scripts/pull-sdk-ref.sh boros hyperliquid

# Available topics: strategies, setup, boros, brap, hyperlend, hyperliquid, polymarket, moonwell, pendle, uniswap, projectx, data
./scripts/pull-sdk-ref.sh --list

# Check the pinned SDK version
./scripts/pull-sdk-ref.sh --version

# Override the pinned version for a specific pull
./scripts/pull-sdk-ref.sh --commit abc123 moonwell
```

These docs cover method signatures, unit conventions, gotchas, execution patterns, and contract addresses. **Always pull them before writing a script.**

The SDK ref is tracked in `sdk-version.md`. The pull script checks out that ref when reading docs, then restores the SDK to its previous state.

You can also read the adapter source code directly:

```
$WAYFINDER_SDK_PATH/wayfinder_paths/adapters/          # All adapter implementations
$WAYFINDER_SDK_PATH/wayfinder_paths/mcp/scripting.py   # get_adapter() helper
$WAYFINDER_SDK_PATH/wayfinder_paths/strategies/        # Strategy implementations
```

Never guess adapter method names or parameters — read the reference docs or source first.

## Basic Script Structure

```python
#!/usr/bin/env python3
"""
Script: my_complex_operation.py
Description: Brief description of what this script does
"""
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter

async def main():
    # Your logic here
    pass

if __name__ == "__main__":
    asyncio.run(main())
```

## Using `get_adapter()`

The `get_adapter()` helper auto-wires configuration and signing:

```python
from wayfinder_paths.mcp.scripting import get_adapter

# Pattern: get_adapter(AdapterClass, wallet_label=None, **config_overrides)

# For write operations (need signing)
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter
adapter = get_adapter(MoonwellAdapter, "main")

# For read-only operations (no wallet needed)
from wayfinder_paths.adapters.pool_adapter import PoolAdapter
pool_adapter = get_adapter(PoolAdapter)

# With config overrides
adapter = get_adapter(MoonwellAdapter, "main", config_overrides={"custom_key": "value"})
```

### What `get_adapter()` Does

1. Loads `config.json` from `$WAYFINDER_CONFIG_PATH`
2. Finds wallet by label from `config["wallets"]`
3. Extracts `private_key_hex` and creates a signing callback
4. Detects the adapter's signing callback parameter names
5. Passes a wallet address **only if the adapter `__init__` accepts it** (e.g. `wallet_address`, `main_wallet_address`, `strategy_wallet_address`)
6. Instantiates the adapter with `config` + any `config_overrides`

### Read vs write patterns (address decoupling)

- **Prefer explicit accounts for reads:** Many adapters support read-only usage via `get_adapter(Adapter)` *if you pass an `account`/`owner`/`address` parameter to the read method*. This keeps reads decoupled from a specific wallet config.
- **Writes need a signing wallet:** Use `get_adapter(Adapter, "main")` (or a strategy wallet label when required) for anything that broadcasts transactions.
- **Some adapters still require a wallet address at init:** A few adapters raise if `wallet_address` is missing even for read-only methods (e.g. ProjectX/Uniswap-style adapters). For those, use `get_adapter(..., "main")` or construct with an explicit `wallet_address=...`.

## Web3 / RPC Access

If you need raw on-chain reads/writes that aren’t exposed by an adapter, use the SDK’s chain helper:

```python
import asyncio

from wayfinder_paths.core.utils.web3 import web3_from_chain_id

CHAIN_ID = 8453  # Base


async def main():
    async with web3_from_chain_id(CHAIN_ID) as w3:
        block = await w3.eth.block_number
        print("block:", block)


if __name__ == "__main__":
    asyncio.run(main())
```

Do **not** hardcode RPC URLs in scripts. `web3_from_chain_id(...)` resolves RPCs from `strategy.rpc_urls` when set; otherwise it falls back to Wayfinder’s RPC proxy at `system.api_base_url` (auth via `system.api_key` / `WAYFINDER_API_KEY`).

## Adapter Quick Reference

### BalanceAdapter — Wallet Operations

```python
from wayfinder_paths.adapters.balance_adapter import BalanceAdapter

adapter = get_adapter(BalanceAdapter, "main")

# Read balances
success, balances = await adapter.get_balances(chain_id=8453)  # Base

# Transfer tokens
success, result = await adapter.transfer(
    token_address="0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913",  # USDC
    to_address="0x...",
    amount=100_000_000,  # 100 USDC (6 decimals)
    chain_id=8453
)
```

### TokenAdapter — Token Metadata

```python
from wayfinder_paths.adapters.token_adapter import TokenAdapter

adapter = get_adapter(TokenAdapter)

# Resolve token by ID or query
success, token = await adapter.get_token("usd-coin-base")
success, token = await adapter.get_token("USDC", chain_id=8453)

# Get gas token for chain
success, gas_token = await adapter.get_gas_token(chain_id=8453)

# Fuzzy search
success, results = await adapter.search_tokens("usdc", chain_id=8453)
```

### BRAPAdapter — Swaps and Bridges

```python
from wayfinder_paths.adapters.brap_adapter import BRAPAdapter

adapter = get_adapter(BRAPAdapter, "main")

# Get quote
success, quote = await adapter.get_quote(
    from_token_id="usd-coin-base",
    to_token_id="ethereum-base",
    amount=100.0,  # Human-readable
    wallet_address="0x..."
)

# Execute swap (if quote successful)
if success and quote.get("best_quote"):
    success, result = await adapter.execute_swap(quote["best_quote"])
```

### MoonwellAdapter — Lending Protocol

```python
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter

adapter = get_adapter(MoonwellAdapter, "main")

# mToken addresses (Base)
USDC_MTOKEN = "0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22"
WETH_MTOKEN = "0x628ff693426583D9a7FB391E54366292F509D457"

# Supply (lend)
success, result = await adapter.lend(
    mtoken=USDC_MTOKEN,
    amount=100_000_000  # 100 USDC in wei
)

# Set as collateral
success, result = await adapter.set_collateral(mtoken=USDC_MTOKEN)

# Borrow
success, result = await adapter.borrow(
    mtoken=WETH_MTOKEN,
    amount=50_000_000_000_000_000  # 0.05 WETH in wei
)

# Repay
success, result = await adapter.repay(
    mtoken=WETH_MTOKEN,
    amount=50_000_000_000_000_000
)

# Withdraw (unlend)
success, result = await adapter.unlend(
    mtoken=USDC_MTOKEN,
    amount=100_000_000
)
```

### HyperliquidAdapter — Perps Trading

```python
from wayfinder_paths.adapters.hyperliquid_adapter import HyperliquidAdapter

adapter = get_adapter(HyperliquidAdapter, "main")

# Get account state
success, state = await adapter.get_user_state()

# Place market order
success, result = await adapter.place_order(
    coin="ETH",
    is_buy=True,
    sz=0.1,  # Size in base asset
    order_type="market",
    slippage=0.01  # 1%
)

# Place limit order
success, result = await adapter.place_order(
    coin="ETH",
    is_buy=True,
    sz=0.1,
    order_type="limit",
    limit_px=3000.0
)

# Update leverage
success, result = await adapter.update_leverage(
    coin="ETH",
    leverage=5,
    is_cross=True
)

# Close position (reduce-only)
success, result = await adapter.place_order(
    coin="ETH",
    is_buy=False,  # Opposite of position direction
    sz=0.1,
    order_type="market",
    reduce_only=True
)
```

### PendleAdapter — PT/YT Markets

```python
from wayfinder_paths.adapters.pendle_adapter import PendleAdapter

adapter = get_adapter(PendleAdapter, "main")

# Discover active markets — returns list directly (no tuple)
markets = await adapter.list_active_pt_yt_markets(chain="base")
market = markets[0]  # list of dicts with marketAddress, ptAddress, fixedApy, etc.

# Get market history — returns dict directly (no tuple)
history = await adapter.fetch_market_history(
    chain_id=8453,
    market_address="0x...",
    time_frame="day",  # "hour", "day", or "week"
)

# Execute swap — mutations DO return (bool, result) tuples
success, result = await adapter.execute_swap(
    chain="base",
    market_address="0x...",
    token_in="0x...",   # e.g. USDC address
    token_out="0x...",  # e.g. PT address
    amount_in="100000000",  # raw base units as string
    slippage=0.01,
)
```

### BorosAdapter — Fixed-Rate Markets

```python
from wayfinder_paths.adapters.boros_adapter import BorosAdapter

adapter = get_adapter(BorosAdapter, "main")

# Discover markets
success, markets = await adapter.list_markets_all()

# Fast tenor-level APR scan (returns BorosTenorQuote dataclass instances)
success, quotes = await adapter.list_tenor_quotes(underlying_symbol="HYPE", platform="hyperliquid")
if success:
    for q in quotes:
        print(q.tenor_days, q.mid_apr)  # attribute access, NOT q["mid_apr"]

# Detailed quote for a single market (returns BorosMarketQuote dataclass)
success, quote = await adapter.quote_market(market_dict)
if success:
    print(quote.mid_apr, quote.best_bid_apr, quote.best_ask_apr)

# Place a rate order
success, result = await adapter.place_rate_order(
    market_id=123,
    token_id=3,          # USDT collateral
    size_yu_wei=50 * 10**18,
    side="long",
)
```

### HyperlendAdapter — HyperEVM Lending

```python
from wayfinder_paths.adapters.hyperlend_adapter import HyperlendAdapter

adapter = get_adapter(HyperlendAdapter, "main")

# Get market snapshot
success, snapshot = await adapter.get_market_snapshot()

# Supply
success, result = await adapter.supply(
    token="USDT0",
    amount=100_000_000  # 100 USDT0 in wei
)

# Withdraw
success, result = await adapter.withdraw(
    token="USDT0",
    amount=100_000_000
)
```

## Example: Complex Multi-Step Flow

```python
#!/usr/bin/env python3
"""
Script: moonwell_supply_and_borrow.py
Description: Supply USDC as collateral and borrow ETH on Moonwell
"""
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter

USDC_MTOKEN = "0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22"
WETH_MTOKEN = "0x628ff693426583D9a7FB391E54366292F509D457"

async def main():
    adapter = get_adapter(MoonwellAdapter, "main")

    # Step 1: Supply USDC
    print("Supplying 100 USDC...")
    success, result = await adapter.lend(mtoken=USDC_MTOKEN, amount=100_000_000)
    if not success:
        print(f"Supply failed: {result}")
        return
    print(f"Supply tx: {result}")

    # Step 2: Enable as collateral
    print("Enabling USDC as collateral...")
    success, result = await adapter.set_collateral(mtoken=USDC_MTOKEN)
    if not success:
        print(f"Set collateral failed: {result}")
        return
    print(f"Collateral tx: {result}")

    # Step 3: Borrow ETH (conservative amount)
    print("Borrowing 0.01 ETH...")
    success, result = await adapter.borrow(mtoken=WETH_MTOKEN, amount=10_000_000_000_000_000)
    if not success:
        print(f"Borrow failed: {result}")
        return
    print(f"Borrow tx: {result}")

    print("Done! Position opened successfully.")

if __name__ == "__main__":
    asyncio.run(main())
```

## Example: Conditional Execution Based on Market State

```python
#!/usr/bin/env python3
"""
Script: conditional_swap.py
Description: Only swap if price is favorable
"""
import asyncio
from decimal import Decimal
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.brap_adapter import BRAPAdapter
from wayfinder_paths.adapters.token_adapter import TokenAdapter

TARGET_RATE = Decimal("2500")  # Only swap if ETH < $2500

async def main():
    brap = get_adapter(BRAPAdapter, "main")
    token = get_adapter(TokenAdapter)

    # Get current ETH price
    success, eth_token = await token.get_token("ethereum-base")
    if not success:
        print(f"Failed to get ETH token: {eth_token}")
        return

    current_price = Decimal(str(eth_token.get("price_usd", 0)))
    print(f"Current ETH price: ${current_price}")

    if current_price >= TARGET_RATE:
        print(f"Price ${current_price} >= target ${TARGET_RATE}, skipping swap")
        return

    # Price is favorable, get quote
    success, quote = await brap.get_quote(
        from_token_id="usd-coin-base",
        to_token_id="ethereum-base",
        amount=100.0,
        wallet_address="0x..."  # Your address
    )

    if not success:
        print(f"Quote failed: {quote}")
        return

    print(f"Quote received: {quote}")

    # Execute swap
    if quote.get("best_quote"):
        success, result = await brap.execute_swap(quote["best_quote"])
        print(f"Swap result: {result}" if success else f"Swap failed: {result}")

if __name__ == "__main__":
    asyncio.run(main())
```

## Running Scripts

**Always test before live execution.** Follow this workflow:

### 1. Safe Run (recommended)

```bash
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
cd "$WAYFINDER_SDK_PATH"

# Recommended: implement your own --dry-run / --force flags inside the script
poetry run wayfinder run_script --script_path .wayfinder_runs/my_script.py --args '["--dry-run"]' --wallet_label main
```

Review the output carefully — verify operations, amounts, and addresses are correct.

### 2. Live Execution (only after safe run passes)

```bash
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
cd "$WAYFINDER_SDK_PATH"
poetry run wayfinder run_script --script_path .wayfinder_runs/my_script.py --args '["--force"]' --wallet_label main
```

**Never skip the safe-run step for scripts that move funds.**

### 3. Direct Execution (bypasses sandbox — use sparingly)

```bash
export WAYFINDER_SDK_PATH="${WAYFINDER_SDK_PATH:-$HOME/wayfinder-paths-sdk}"
cd "$WAYFINDER_SDK_PATH"
poetry run python .wayfinder_runs/my_script.py
```

## Return Pattern Convention

Most adapter methods return `(success: bool, result_or_error: Any)`:

```python
success, result = await adapter.some_method(...)
if success:
    # result contains the data (tx hash, response object, etc.)
    print(f"Success: {result}")
else:
    # result contains error message (string), NOT the expected data type
    print(f"Error: {result}")
```

**Important caveats:**

1. **Type changes on failure**: When `success=False`, `result` is an error **string**, not the typed data you'd get on success. Always check `success` before accessing fields on `result` — e.g., calling `result.mid_apr` on an error string raises `AttributeError`.

2. **Nested results**: Some methods return compound data as the second element that requires further unpacking. For example, Hyperliquid's `get_meta_and_asset_ctxs()` returns `(True, [meta_dict, ctxs_list])` — unpack with `meta, ctxs = result`.

3. **Pendle reads return data directly (no tuple)**: Pendle read methods like `list_active_pt_yt_markets()` and `fetch_market_history()` return the data directly, not `(bool, result)` tuples. Only Pendle mutation methods (`execute_swap`, `execute_convert`, `get_full_user_state`) return tuples.

4. **Boros quotes return dataclass instances**: `list_tenor_quotes()` returns `list[BorosTenorQuote]` and `quote_market()` returns `BorosMarketQuote` — access fields via attributes (`q.mid_apr`), not dict keys (`q["mid_apr"]`).

**Defensive pattern:**

```python
success, result = await adapter.some_method(...)
if not success:
    print(f"Error: {result}")  # result is a string here
    return

# Now safe to access typed fields
# For nested results:
meta, ctxs = result  # if result is a 2-element list
# For dataclass results:
print(result.mid_apr)  # if result is a BorosMarketQuote
```

## Error Handling Best Practices

```python
async def safe_operation():
    adapter = get_adapter(SomeAdapter, "main")

    success, result = await adapter.risky_operation()
    if not success:
        # Log error, don't proceed
        print(f"Operation failed: {result}")
        return None

    # Continue with next step
    return result
```

## Environment Variables

Scripts inherit these from the execution environment:

| Variable | Purpose |
|----------|---------|
| `WAYFINDER_CONFIG_PATH` | Path to config.json |
| `WAYFINDER_RUNS_DIR` | Override runs directory |
| `WAYFINDER_API_KEY` | Fallback API key |

## Security Notes

1. **Scripts are sandboxed** — only `.wayfinder_runs/` scripts can be executed via `run_script`
2. **Private keys stay in config.json** — never hardcode keys in scripts
3. **Safe run first** — implement a non-fund-moving mode in your script and run it before `--force`
4. **Review before execution** — safety hooks show confirmation prompts for fund-moving operations
