# Contracts (Solidity compile/deploy + interaction)

## Overview

Wayfinder Paths includes MCP tools (and corresponding `poetry run wayfinder ...` commands) for Solidity contract work:

- **Compile:** `compile_contract` (read-only)
- **Deploy:** `deploy_contract` (fund-moving; optional Etherscan verification)
- **Interact:** `contract_get_abi`, `contract_call` (read-only), `contract_execute` (fund-moving)
- **Browse local deployments:** `wayfinder://contracts` and `wayfinder://contracts/{chain_id}/{address}`

## Quick workflow

1) Put your Solidity file in-repo (committed or under `$WAYFINDER_SCRATCH_DIR`).
2) Compile:

```bash
poetry run wayfinder compile_contract --source_path .wayfinder_runs/MyContract.sol
```

3) Deploy (requires a signing wallet in `config.json`):

```bash
poetry run wayfinder deploy_contract --wallet_label main --source_path .wayfinder_runs/MyContract.sol --contract_name MyContract --chain_id 8453
```

4) Browse what you deployed:

```bash
poetry run wayfinder resource wayfinder://contracts
poetry run wayfinder resource wayfinder://contracts/8453/0xabc123...
```

5) Call or execute functions:

```bash
# Read-only
poetry run wayfinder contract_call --chain_id 8453 --contract_address 0xabc123... --function_signature "balanceOf(address)" --args '["0x..."]'

# State-changing (broadcasts a tx)
poetry run wayfinder contract_execute --wallet_label main --chain_id 8453 --contract_address 0xabc123... --function_signature "transfer(address,uint256)" --args '["0x...", 123]'
```

## Artifact persistence (important)

Every `deploy_contract` automatically persists source + ABI + metadata under:

```
.wayfinder_runs/contracts/{chain_id}/{address_lowercase}/
```

An index is maintained at:

```
.wayfinder_runs/contracts/index.json
```

The `wayfinder://contracts` resources read from this artifact store.

## ABI resolution + Etherscan requirements

For `contract_call` / `contract_execute`, ABI resolution is:

1) **Inline `abi`** or repo file `abi_path` (if you provide it)
2) **Local artifact store ABI** (if the contract was deployed via `deploy_contract`)
3) **Etherscan V2 ABI fetch** (fallback; requires `system.etherscan_api_key` in `config.json` or `ETHERSCAN_API_KEY`, and the contract must be verified)

Notes:
- If the function is overloaded, prefer `function_signature` like `deposit(uint256)` (not just `function_name`).
- `contract_get_abi` defaults `resolve_proxy=true` and attempts common proxy resolution before fetching ABI.

## Safety notes

- Always require explicit user confirmation before `deploy_contract` and `contract_execute`.
- Use `contract_call` for `view`/`pure` functions; `contract_execute` rejects `view`/`pure`.
- Use `value_wei` for payable functions (defaults to `0`).
- Constructor args for `deploy_contract` must be a JSON array (or JSON-encoded array string) and are auto-cast to the ABI types.

## Common gotchas

- **Node/npm required for OpenZeppelin imports:** OZ imports are supported by auto-installing `@openzeppelin/contracts` into an ignored cache dir on first use.
- **Only `@openzeppelin/*` imports are supported:** relative imports (e.g. `./Foo.sol`) and other packages will fail compilation.
- **Fork deploys:** if deploying to a fork (e.g. Gorlami), set `verify=false` (explorers can’t verify fork contracts).

