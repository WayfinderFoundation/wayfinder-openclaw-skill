---
name: wayfinder-coding-interface
description: Write and run custom Python scripts using Wayfinder SDK adapters — multi-step DeFi flows, batched operations, conditional logic, protocol combinations, custom calculations, rebalancing, automated workflows. Use for write a script, automate, custom code, multi-step flow, programmatic access, get_adapter, run_script, complex operations beyond a single CLI command.
---

# Coding Interface for Custom Operations

Use the coding interface when pre-built CLI commands aren't sufficient. The `wayfinder-paths-sdk` provides a full Python scripting interface for multi-step flows, conditional logic, batched operations, protocol combinations, and custom calculations.

## `run_script` — Execute sandboxed Python scripts

Run a local Python script in a subprocess. Scripts must live inside the runs directory (`$WAYFINDER_RUNS_DIR` or `.wayfinder_runs/`).

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `script_path` | string | **Yes** | — | Must be `.py`, must exist, **must be inside the runs directory** |
| `args` | string (JSON) | No | — | Arguments passed to the script (JSON list) |
| `timeout_s` | int | No | `600` | Clamped to min 1 second |
| `env` | string (JSON) | No | — | Additional env vars for subprocess (JSON object) |
| `wallet_label` | string | No | — | For profile annotation |

**Validations:**
- Script path must resolve to inside the runs directory (sandboxed — no arbitrary file execution).
- Must be a `.py` file.
- Must exist on disk.
- Output is truncated to 20,000 chars.

```bash
# Recommended: implement --dry-run / --force in your script and pass it via --args
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--dry-run"]' --wallet_label main
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --args '["--force"]' --wallet_label main

# With timeout
poetry run wayfinder run_script --script_path .wayfinder_runs/my_flow.py --wallet_label main --timeout_s 120
```

## Custom Scripts via the Coding Interface

**For any operation that goes beyond a single CLI command, you SHOULD write a custom Python script.** The `wayfinder-paths-sdk` provides a full coding interface — use it whenever you need multi-step flows, conditional logic, batched operations, or protocol combinations.

### When to Write a Script

- **Multi-step atomic flows** — operations that must succeed together
- **Custom logic** — conditional execution based on market state
- **Batched operations** — multiple protocol interactions in sequence
- **Protocol combinations** — bridging multiple adapters in one flow
- **Complex calculations** — position sizing, rebalancing, PnL analysis
- **Anything the user asks that isn't a single CLI call**

### Script Location

All generated scripts **must** be saved to `.wayfinder_runs/` inside the SDK directory:

```
$WAYFINDER_SDK_PATH/.wayfinder_runs/my_script.py
```

This directory is sandboxed — `run_script` only executes scripts inside it. Create it if it doesn't exist:

```bash
mkdir -p "$WAYFINDER_SDK_PATH/.wayfinder_runs"
```

### Referencing the SDK Source

Before writing any script, **pull the detailed reference docs** for the adapter or strategy you're working with. The SDK ships comprehensive skill docs covering method signatures, gotchas, unit conventions, and execution patterns.

**Use the reference script:**

```bash
# List available topics
./scripts/pull-sdk-ref.sh --list

# Pull docs for specific adapters (supports multiple topics)
./scripts/pull-sdk-ref.sh moonwell
./scripts/pull-sdk-ref.sh boros hyperliquid
./scripts/pull-sdk-ref.sh strategies

# Pull everything
./scripts/pull-sdk-ref.sh --all

# Check the pinned SDK version
./scripts/pull-sdk-ref.sh --version
```

**Available topics:** `contracts`, `simulation`, `adapters`, `strategies`, `setup`, `brap`, `boros`, `ccxt`, `coding`, `hyperlend`, `hyperliquid`, `polymarket`, `moonwell`, `pendle`, `uniswap`, `projectx`, `aave`, `morpho`, `delta-lab`, `data`

The pinned SDK ref is tracked in `sdk-version.md` (a commit hash). `pull-sdk-ref.sh` reads docs from your local SDK checkout and **warns** if the SDK ref doesn't match the pinned version.

**Always run this before writing a script** — the docs cover critical details like:
- Exact method signatures and required parameters
- Unit conventions (raw base units vs human-readable, wei vs native)
- Gotchas (e.g., `unlend()` takes mToken amounts not underlying, withdrawal cooldowns, funding sign conventions)
- Execution patterns and safety rails
- Token/contract addresses

You can also read the adapter source code directly:

```
$WAYFINDER_SDK_PATH/wayfinder_paths/adapters/          # All adapter implementations
$WAYFINDER_SDK_PATH/wayfinder_paths/mcp/scripting.py   # get_adapter() helper
$WAYFINDER_SDK_PATH/wayfinder_paths/strategies/        # Strategy implementations
```

### Quick Start

```python
#!/usr/bin/env python3
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter

async def main():
    adapter = get_adapter(MoonwellAdapter, "main")  # Auto-wires config + signing
    success, result = await adapter.lend(mtoken="0x...", amount=100_000_000)
    print(f"Result: {result}" if success else f"Error: {result}")

if __name__ == "__main__":
    asyncio.run(main())
```

### Testing Workflow

**Always test before live execution.** Follow this workflow:

1. **Write** the script to `.wayfinder_runs/`
2. **Safe run** — run the script in a non-fund-moving mode first (recommended: implement `--dry-run` / `--force` in your script and pass it via `--args`):
   ```bash
   cd "$WAYFINDER_SDK_PATH"
   poetry run wayfinder run_script --script_path .wayfinder_runs/my_script.py --args '["--dry-run"]' --wallet_label main
   ```
3. **Review** the output. Verify the operations, amounts, and addresses are correct.
4. **Live execution** — only after confirming the safe run looks right, run with `--force`:
   ```bash
   poetry run wayfinder run_script --script_path .wayfinder_runs/my_script.py --args '["--force"]' --wallet_label main
   ```

**Never skip the safe-run step for scripts that move funds.**

## Adapter Discovery

To find available adapters and their methods, use the resource system:

```bash
# List all adapters with capabilities
poetry run wayfinder resource wayfinder://adapters

# Describe a single adapter (e.g. moonwell_adapter)
poetry run wayfinder resource wayfinder://adapters/moonwell_adapter
```

### Available Adapters

| Adapter | Protocol | Capabilities |
|---------|----------|-------------|
| `aave_v3_adapter` | Aave V3 (multi-chain) | `market.list`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.toggle`, `rewards.claim` |
| `avantis_adapter` | Avantis avUSDC vault (Base) | `market.list`, `position.read`, `vault.deposit`, `vault.withdraw` |
| `balance_adapter` | EVM wallets | `balance.read`, `transfer.main_to_strategy`, `transfer.strategy_to_main`, `transfer.send` |
| `boros_adapter` | Boros (Arbitrum) | `market.read`, `market.quote`, `position.open`, `position.close`, `collateral.deposit`, `collateral.withdraw` |
| `brap_adapter` | Cross-chain swaps | `swap.quote`, `swap.execute`, `swap.compare_routes`, `bridge.quote`, `gas.estimate` |
| `ccxt_adapter` | CEXes (Aster/Binance) | `exchange.factory` |
| `euler_v2_adapter` | Euler v2 (EVK / eVaults) | `market.list`, `market.read`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.set`, `collateral.remove` |
| `eigencloud_adapter` | EigenCloud (EigenLayer restaking) | `market.list`, `position.read`, `restaking.deposit`, `restaking.withdraw.queue`, `restaking.withdraw.complete`, `delegation.*`, `rewards.*` |
| `ethena_vault_adapter` | Ethena sUSDe vault (Ethereum) | `vault.read`, `vault.deposit`, `vault.withdraw`, `position.read`, `market.apy` |
| `hyperlend_adapter` | HyperLend (HyperEVM) | `market.stable_markets`, `market.assets_view`, `market.rate_history`, `lending.lend`, `lending.unlend` |
| `hyperliquid_adapter` | Hyperliquid DEX | `market.read`, `market.meta`, `market.funding`, `market.candles`, `market.orderbook`, `order.execute`, `order.cancel`, `position.manage`, `transfer`, `withdraw` |
| `ledger_adapter` | Local bookkeeping | `ledger.read`, `ledger.record`, `ledger.snapshot` |
| `lido_adapter` | Lido liquid staking (Ethereum) | `staking.stake`, `staking.wrap`, `staking.unwrap`, `withdrawal.request`, `withdrawal.claim`, `position.read` |
| `moonwell_adapter` | Moonwell (Base) | `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `collateral.set`, `collateral.remove`, `rewards.claim`, `position.read`, `market.apy`, `market.collateral_factor` |
| `morpho_adapter` | Morpho Blue + MetaMorpho | `market.list`, `market.read`, `position.read`, `lending.lend`, `lending.unlend`, `lending.borrow`, `lending.repay`, `vault.list`, `vault.deposit`, `vault.withdraw`, `rewards.read`, `rewards.claim` |
| `multicall_adapter` | EVM batch calls | `multicall.aggregate` |
| `pendle_adapter` | Pendle | `pendle.markets.read`, `pendle.market.snapshot`, `pendle.swap.quote`, `pendle.swap.execute`, `pendle.convert.quote`, `pendle.positions.database`, and more |
| `polymarket_adapter` | Polymarket | `market.read`, `market.search`, `market.orderbook`, `market.candles`, `position.read`, `order.execute`, `order.cancel`, `bridge.deposit`, `bridge.withdraw` |
| `pool_adapter` | DeFi Llama | `pool.read`, `pool.discover` |
| `projectx_adapter` | ProjectX (V3 fork) | `projectx.pool.overview`, `projectx.positions.list`, `projectx.liquidity.mint`, `projectx.liquidity.increase`, `projectx.liquidity.decrease`, `projectx.fees.collect`, `projectx.swap.exact_in` |
| `token_adapter` | Token metadata | `token.read`, `token.price`, `token.gas` |
| `uniswap_adapter` | Uniswap V3 | `uniswap.liquidity.add`, `uniswap.liquidity.increase`, `uniswap.liquidity.remove`, `uniswap.fees.collect`, `uniswap.position.get`, `uniswap.positions.list`, `uniswap.fees.uncollected`, `uniswap.pool.get` |

## References

- [Coding Interface Reference](references/coding-interface.md) — Full adapter API reference, examples, and patterns
- [Adapters Reference](references/adapters.md) — Adapter capabilities and configuration
- [Simulation & Dry-Run](../wayfinder/references/simulation-dry-run.md) — Testing and simulation patterns
- [Commands Reference](../wayfinder/references/commands.md) — Full CLI command reference
- [Error Reference](references/errors.md)
