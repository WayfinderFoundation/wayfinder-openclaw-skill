---
name: wayfinder-strategies
description: Manage automated DeFi yield strategies — deposit, withdraw, exit, check status, analyze returns, run updates. Strategies include basis trading (delta-neutral funding), HYPE yield (Boros fixed-rate), stablecoin yield rotation, leveraged wstETH loop (Moonwell), multi-vault split, and concentrated LP (ProjectX). Use for earn yield, passive income, auto-compound, strategy status, deploy capital, APY, farming, vault, run strategy.
---

# Wayfinder Strategies

Manage automated DeFi strategies through the Wayfinder SDK. Each strategy has a `manifest.yaml` defining its adapters, chains, and parameters. All strategies share a common lifecycle interface for status checks, analysis, quoting, deposits, rebalancing, withdrawals, and exits.

## `run_strategy` — Strategy lifecycle management

Run strategy actions: check status, analyze, quote, deposit, update, withdraw, or exit.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `strategy` | string | **Yes** | — | Strategy directory name; must have `manifest.yaml` |
| `action` | `status` \| `analyze` \| `snapshot` \| `policy` \| `quote` \| `deposit` \| `update` \| `withdraw` \| `exit` | **Yes** | — | — |
| `amount_usdc` | float | No | `1000.0` | **Read-only analysis:** hypothetical deposit for `analyze`, `snapshot`, `quote` |
| `amount` | TEXT | No | — | Float value; generic amount parameter (strategy-specific) |
| `main_token_amount` | TEXT | **deposit** | — | Float value; **actual deposit:** amount of strategy's deposit token |
| `gas_token_amount` | float | No | `0.0` | **Actual deposit:** optional gas token amount |

**Amount parameter rules:**
- **For read-only analysis** (`analyze`, `snapshot`, `quote`): use `--amount_usdc`
- **For actual deposits** (`deposit`): use `--main_token_amount` (required) + optionally `--gas_token_amount`
- The deposit token varies by strategy (USDC on Base for stablecoin_yield, USDC on Arbitrum for boros_hype, etc.)

```bash
poetry run wayfinder resource wayfinder://strategies
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action status
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action analyze --amount_usdc 100
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action quote --amount_usdc 100
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action deposit --main_token_amount 100 --gas_token_amount 0.01
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action update
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action withdraw
poetry run wayfinder run_strategy --strategy stablecoin_yield_strategy --action exit
```

**Errors:** `invalid_request` (empty strategy), `not_found` (missing manifest), `not_supported` (strategy lacks the method), `strategy_error` (runtime exception).

**Note:** `withdraw` liquidates positions but funds stay in the strategy wallet. `exit` transfers funds from the strategy wallet back to the main wallet. These are separate steps.

## Available Strategies

| Strategy | Status | Chain | Token | Risk | Description |
|----------|--------|-------|-------|------|-------------|
| `basis_trading_strategy` | stable | Hyperliquid | USDC | Medium | Delta-neutral funding rate capture with matched spot/perp positions |
| `boros_hype_strategy` | stable | Arbitrum + HyperEVM + Hyperliquid | HYPE/USDC | Medium | Multi-leg HYPE yield with fixed-rate funding lock via Boros |
| `hyperlend_stable_yield_strategy` | stable | HyperEVM | USDT0 | Low | Stablecoin yield optimization on HyperLend with rotation policy |
| `moonwell_wsteth_loop_strategy` | stable | Base | USDC/WETH/wstETH | Medium-High | Leveraged wstETH carry trade via Moonwell looping |
| `multi_vault_split_strategy` | stable | Multi-chain | USDC | Low-Medium | Diversified allocation across HLP, Boros, and Avantis vaults |
| `stablecoin_yield_strategy` | wip | Base | USDC | Low | Auto-rotates across best stablecoin pools on Base |
| `projectx_thbill_usdc_strategy` | wip | HyperEVM | THBILL/USDC | Medium | Concentrated liquidity market making on ProjectX (V3 fork) |

## Strategy Workflow

The standard lifecycle for any strategy follows these steps:

1. **Discover** — List available strategies and their current status:
   ```bash
   poetry run wayfinder resource wayfinder://strategies
   ```

2. **Analyze** — Run hypothetical analysis with a simulated deposit amount:
   ```bash
   poetry run wayfinder run_strategy --strategy <name> --action analyze --amount_usdc 1000
   ```

3. **Deposit** — Fund the strategy with real tokens:
   ```bash
   poetry run wayfinder run_strategy --strategy <name> --action deposit --main_token_amount 500 --gas_token_amount 0.01
   ```

4. **Update** — Rebalance or execute the strategy's core logic:
   ```bash
   poetry run wayfinder run_strategy --strategy <name> --action update
   ```

5. **Withdraw** — Liquidate all positions; funds remain in the strategy wallet:
   ```bash
   poetry run wayfinder run_strategy --strategy <name> --action withdraw
   ```

6. **Exit** — Transfer funds from the strategy wallet back to the main wallet:
   ```bash
   poetry run wayfinder run_strategy --strategy <name> --action exit
   ```

## Amount Parameter Rules

| Context | Parameter | Purpose |
|---------|-----------|---------|
| Read-only (`analyze`, `snapshot`, `quote`) | `--amount_usdc` | Hypothetical USDC deposit for simulation — no funds move |
| Actual deposit (`deposit`) | `--main_token_amount` | Real amount of the strategy's deposit token — funds move |
| Actual deposit (`deposit`) | `--gas_token_amount` | Optional gas token to send alongside the deposit |

The deposit token is strategy-specific. Check `manifest.yaml` or the strategy's documentation for which token and chain to use.

## References

- [Strategies Reference](references/strategies.md) — Detailed per-strategy documentation, parameters, adapters, and entry/exit flows
- [Commands Reference](../wayfinder/references/commands.md) — Full CLI command reference including `run_strategy`
- [Error Reference](references/errors.md)
