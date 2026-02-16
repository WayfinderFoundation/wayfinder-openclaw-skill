# Simulation / Dry-Run (Gorlami forks)

Use this when you’re changing or writing a **fund-moving** flow (swaps, lending, bridging, looping) and want to validate it on a fork before broadcasting live transactions.

## Quickstart: run a strategy on a fork

Preferred entrypoint: `wayfinder_paths/run_strategy.py` with `--gorlami`.

This runs against a virtual fork where each transaction updates state for the next step.

```bash
poetry run python wayfinder_paths/run_strategy.py moonwell_wsteth_loop_strategy \
  --action status \
  --gorlami \
  --config config.json
```

Deposit/update example:

```bash
poetry run python wayfinder_paths/run_strategy.py moonwell_wsteth_loop_strategy \
  --action deposit \
  --main-token-amount 20 \
  --gorlami \
  --config config.json

poetry run python wayfinder_paths/run_strategy.py moonwell_wsteth_loop_strategy \
  --action update \
  --gorlami \
  --config config.json
```

### Fork funding controls (optional)

- Default: `--gorlami` seeds **0.1 ETH** to `main_wallet` and `strategy_wallet` (unless you pass `--gorlami-no-default-gas`)
- `--gorlami-fund-native-eth ADDRESS:ETH` — seed native gas manually
- `--gorlami-fund-erc20 TOKEN:WALLET:AMOUNT:DECIMALS` — seed ERC20 (AMOUNT in human units)
- `--gorlami-no-default-gas` — disable default gas seeding
- If chain inference fails, pass `--gorlami-chain-id <id>`

## Run a script on a fork (`gorlami_fork`)

Use the context manager in `wayfinder_paths/core/utils/gorlami.py`:

- Creates a fork for `chain_id`
- Seeds native + ERC20 balances via Gorlami REST endpoints
- Temporarily routes `web3_from_chain_id(...)` to the fork RPC for that chain
- Deletes the fork on exit

Pattern:

```python
from wayfinder_paths.core.utils.gorlami import gorlami_fork

async def run():
    async with gorlami_fork(8453) as (client, info):
        # Your normal adapter/web3 code runs against the fork here
        ...
```

## Scenario checklist (before “live”)

1. **Read-only validation first:** confirm token addresses/decimals and chain IDs; fetch a quote/status/analyze before executing anything.
2. **Happy-path fork run:** seed balances (native gas + required ERC20s) and run the full sequence on a fork.
3. **Assertions:** check receipt `status=1` and assert at least one state change per step (balance moved, position changed, allowance set).
4. **At least one failure scenario:** too little balance, missing allowance, slippage too tight, wrong decimals; ensure the flow stops safely.
5. **Only then: live execution:** start small, require explicit confirmation, and verify on-chain receipts.

## Fork-mode gotchas

- Fork RPCs can intermittently 5xx; keep scripts resilient (retry reads when safe, assert after writes).
- `eth_estimateGas` can fail for complex router/multicalls on forks; use a safe fallback gas limit in simulation mode.
- Waiting for “confirmations” can hang (forks may not mine extra blocks); use 0 confirmations but still wait for receipt.
- Cross-chain bridges don’t relay between forks; simulate by running multiple forks and seeding destination balances manually.

