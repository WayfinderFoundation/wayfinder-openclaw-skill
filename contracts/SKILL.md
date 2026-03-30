---
name: wayfinder-contracts
description: Compile, deploy, and interact with Solidity smart contracts — write .sol files, compile with OpenZeppelin, deploy to any EVM chain, fetch ABI from Etherscan, read contract state (eth_call), execute write transactions, verify on Etherscan. Use for smart contract, deploy token, ERC20, ERC721, NFT, Solidity, contract call, contract interaction, on-chain code.
---

# Contracts

Wayfinder provides commands for the full Solidity contract lifecycle: compiling `.sol` files (with OpenZeppelin import support), deploying to any supported chain, fetching ABIs from Etherscan, reading on-chain state via `eth_call`, and broadcasting state-changing transactions.

---

## Commands

### `compile_contract` — Compile Solidity contracts (read-only)

Compile a Solidity `.sol` file with OpenZeppelin import support.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `source_path` | string | **Yes** | — | Must be a `.sol` file inside the repo (or scratch dir inside the repo) |
| `contract_name` | string | No | — | Optional: validate/select a specific contract from the compilation output |

```bash
poetry run wayfinder compile_contract --source_path .wayfinder_runs/MyToken.sol
poetry run wayfinder compile_contract --source_path .wayfinder_runs/MyToken.sol --contract_name MyToken
```

---

### `deploy_contract` — Deploy a Solidity contract (fund-moving)

Compile, deploy, and optionally verify a Solidity contract. **This broadcasts a transaction**.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with `address` + `private_key_hex` |
| `source_path` | string | **Yes** | — | Solidity `.sol` file inside the repo |
| `contract_name` | string | **Yes** | — | Contract name to deploy from compilation output |
| `chain_id` | int | **Yes** | — | Target chain id |
| `constructor_args` | string (JSON) | No | — | JSON array string (e.g. `'["0xabc...", 1000]'`) |
| `verify` | flag | No | `true` | `--verify` / `--no-verify`; Etherscan V2 (API key required); deploy works without it |

```bash
# Deploy (no constructor args)
poetry run wayfinder deploy_contract --wallet_label main --source_path .wayfinder_runs/Counter.sol --contract_name Counter --chain_id 8453

# Deploy with constructor args + skip verification
poetry run wayfinder deploy_contract --wallet_label main --source_path .wayfinder_runs/MyToken.sol --contract_name MyToken --chain_id 8453 --constructor_args '[1000000]' --no-verify
```

**Artifacts:** successful deploys are persisted under `.wayfinder_runs/contracts/...` and can be browsed via `wayfinder://contracts`.

---

### `contract_get_abi` — Fetch contract ABI (read-only)

Fetch ABI for a deployed contract via Etherscan V2 (optionally resolves common proxy patterns first).

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `chain_id` | int | **Yes** | — | Target chain id |
| `contract_address` | string | **Yes** | — | Contract address |
| `resolve_proxy` | flag | No | `true` | `--resolve_proxy` / `--no-resolve_proxy`; attempt proxy implementation resolution (EIP-1967 / ZeppelinOS / EIP-897) |

```bash
poetry run wayfinder contract_get_abi --chain_id 8453 --contract_address 0xabc123...
```

---

### `contract_call` — Read from a deployed contract (read-only)

Read contract state via `eth_call`.

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `chain_id` | int | **Yes** | — | Target chain id |
| `contract_address` | string | **Yes** | — | Contract address |
| `function_name` | string | No | — | Use only for non-overloaded functions |
| `function_signature` | string | No | — | Prefer for overloaded functions (e.g. `balanceOf(address)`) |
| `args` | string (JSON) | No | — | JSON array string |
| `value_wei` | int | No | `0` | For payable calls (rare for `eth_call`) |
| `from_address` | string | No | — | Optional `from` for `eth_call` |
| `wallet_label` | string | No | — | Alternative to `from_address` (uses wallet address only; no signing) |
| `abi` | string (JSON) | No | — | Inline ABI JSON (minimal ABI recommended) |
| `abi_path` | string | No | — | Path to a `.json` ABI file inside this repo |

**ABI resolution:** if you omit `abi` and `abi_path`, the tool checks the local artifact store first (for contracts deployed via `deploy_contract`), then falls back to Etherscan V2 (requires API key + verified contract).

```bash
poetry run wayfinder contract_call --chain_id 8453 --contract_address 0xabc123... --function_signature "balanceOf(address)" --args '["0x..."]'
```

---

### `contract_execute` — Execute a contract write (fund-moving)

Encode calldata and broadcast a state-changing transaction. **This moves funds / changes state.**

| Parameter | Type | Required | Default | Notes |
|-----------|------|----------|---------|-------|
| `wallet_label` | string | **Yes** | — | Must resolve to a wallet with `address` + `private_key_hex` |
| `chain_id` | int | **Yes** | — | Target chain id |
| `contract_address` | string | **Yes** | — | Contract address |
| `function_name` | string | No | — | Use only for non-overloaded functions |
| `function_signature` | string | No | — | Prefer for overloaded functions |
| `args` | string (JSON) | No | — | JSON array string |
| `value_wei` | int | No | `0` | ETH value to send for payable functions |
| `abi` | string (JSON) | No | — | Inline ABI JSON (minimal ABI recommended) |
| `abi_path` | string | No | — | Path to a `.json` ABI file inside this repo |
| `wait_for_receipt` | flag | No | `true` | `--wait_for_receipt` / `--no-wait_for_receipt`; if disabled, return after broadcast |

**Safety:** always require explicit user confirmation before running `contract_execute`.

```bash
poetry run wayfinder contract_execute --wallet_label main --chain_id 8453 --contract_address 0xabc123... --function_signature "transfer(address,uint256)" --args '["0x...", 123]'
```

---

## Contract artifacts and the `wayfinder://contracts` resource

Every `deploy_contract` automatically persists source, ABI, and metadata under:

```
.wayfinder_runs/contracts/{chain_id}/{address_lowercase}/
```

An index is maintained at:

```
.wayfinder_runs/contracts/index.json
```

Browse your deployments:

```bash
poetry run wayfinder resource wayfinder://contracts
poetry run wayfinder resource wayfinder://contracts/8453/0xabc123...
```

For `contract_call` and `contract_execute`, ABI resolution order is:

1. **Inline `abi`** or repo file `abi_path` (if you provide it)
2. **Local artifact store ABI** (if the contract was deployed via `deploy_contract`)
3. **Etherscan V2 ABI fetch** (fallback; requires `system.etherscan_api_key` in `config.json` or `ETHERSCAN_API_KEY`, and the contract must be verified)

---

## Common workflow: compile, deploy, interact

1. **Write** your Solidity file and place it in-repo (committed or under `$WAYFINDER_SCRATCH_DIR`).

2. **Compile** to check for errors:

```bash
poetry run wayfinder compile_contract --source_path .wayfinder_runs/MyContract.sol
```

3. **Deploy** (requires a signing wallet in `config.json`):

```bash
poetry run wayfinder deploy_contract --wallet_label main --source_path .wayfinder_runs/MyContract.sol --contract_name MyContract --chain_id 8453
```

4. **Browse** what you deployed:

```bash
poetry run wayfinder resource wayfinder://contracts
poetry run wayfinder resource wayfinder://contracts/8453/0xabc123...
```

5. **Read** contract state:

```bash
poetry run wayfinder contract_call --chain_id 8453 --contract_address 0xabc123... --function_signature "balanceOf(address)" --args '["0x..."]'
```

6. **Execute** a state-changing function (always confirm with the user first):

```bash
poetry run wayfinder contract_execute --wallet_label main --chain_id 8453 --contract_address 0xabc123... --function_signature "transfer(address,uint256)" --args '["0x...", 123]'
```

---

## References

- [Contracts Reference](references/contracts.md) — artifact persistence, ABI resolution, safety notes, and common gotchas
- [Commands Reference](../wayfinder/references/commands.md) — full command listing for all Wayfinder commands
- [Error Reference](references/errors.md)
