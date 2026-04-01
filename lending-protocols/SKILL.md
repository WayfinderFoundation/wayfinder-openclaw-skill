---
name: wayfinder-lending-protocols
description: Lend, borrow, and earn interest on DeFi lending protocols — Moonwell (Base), Morpho Blue and MetaMorpho vaults, Euler V2 eVaults, HyperLend (HyperEVM), Ethena sUSDe staking vault, SparkLend (MakerDAO). Supply assets, borrow against collateral, repay debt, claim rewards, check APY and positions. Use for lending, borrowing, supply, interest rate, collateral, health factor, yield, deposit USDC, earn on stablecoins, DeFi money markets.
---

# Lending Protocols

All lending adapters are instantiated via the coding interface:

```python
from wayfinder_paths.mcp.scripting import get_adapter
adapter = get_adapter(AdapterClass, "main")  # "main" = wallet label; omit for read-only
```

Scripts go in `.wayfinder_runs/` and are executed with `poetry run wayfinder run_script`.

---

## Moonwell (Base)

Lending/borrowing protocol on Base. Uses mToken addresses as the primary market identifier.

**Adapter:** `MoonwellAdapter`

```python
from wayfinder_paths.adapters.moonwell_adapter import MoonwellAdapter
adapter = get_adapter(MoonwellAdapter, "main")
```

### Key Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `get_all_markets` | `...` | All Moonwell markets with metadata and APYs |
| `get_full_user_state` | `account?, include_rewards?, include_usd?, include_apy?` | All positions and rewards |
| `get_apy` | `mtoken, apy_type, include_rewards` | Supply or borrow APY for a market |
| `get_borrowable_amount` | `account?` | Account liquidity in USD |
| `lend` | `mtoken, underlying_token, amount` | Supply underlying token |
| `unlend` | `mtoken, amount` | Withdraw (mToken amount, not underlying) |
| `borrow` | `mtoken, amount` | Borrow against collateral |
| `repay` | `mtoken, underlying_token, amount, repay_full=False` | Repay a borrow |
| `set_collateral` | `mtoken` | Enable asset as collateral |
| `remove_collateral` | `mtoken` | Disable asset as collateral |
| `claim_rewards` | `min_rewards_usd?` | Claim WELL rewards |

### Gotchas

- All methods take **mToken addresses**, not underlying token addresses.
- Amounts are **raw int units** (USDC = 6 decimals, WETH = 18, mTokens = 8).
- `unlend()` takes **mToken amount**, not underlying. Use `max_withdrawable_mtoken()` to get the right value.
- Supplying does NOT auto-enable collateral -- call `set_collateral()` separately.
- Always call `get_borrowable_amount()` before borrowing.
- Two USDC markets on Base: use `0xEdc817A28E8B93B03976FBd4a3dDBc9f7D176c22` (main).

---

## Morpho Blue + MetaMorpho (Multi-chain)

Morpho Blue is an isolated lending market primitive. MetaMorpho vaults are ERC-4626 wrappers over Blue allocations. Supports both direct market lending and vault-based strategies.

**Adapter:** `MorphoAdapter`

```python
from wayfinder_paths.adapters.morpho_adapter import MorphoAdapter
adapter = get_adapter(MorphoAdapter, "main")
```

### Key Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `get_all_markets` | `chain_id, listed=True, include_idle=False` | Market list with APYs and rewards |
| `get_market_entry` | `chain_id, market_unique_key` | Single market metadata |
| `get_market_state` | `chain_id, market_unique_key` | Market state + allocator liquidity |
| `get_market_historical_apy` | `chain_id, market_unique_key, interval, start_timestamp?, end_timestamp?` | APY time series |
| `get_all_vaults` | `chain_id, listed=True, include_v2=True` | MetaMorpho vault list with APYs |
| `get_vault_entry` | `chain_id, vault_address` | Single vault metadata |
| `get_full_user_state` | `account, include_zero_positions=False` | Cross-chain position snapshot |
| `get_full_user_state_per_chain` | `chain_id, account, include_zero_positions=False` | Single-chain position snapshot |
| `get_claimable_rewards` | `chain_id, account?` | Claimable Merkl + URD rewards |

### Execution Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `supply_collateral` | `chain_id, market_unique_key, qty` | Deposit collateral (required before borrowing) |
| `withdraw_collateral` | `chain_id, market_unique_key, qty, withdraw_full=False` | Withdraw collateral (check health factor first) |
| `lend` | `chain_id, market_unique_key, qty` | Supply loan asset |
| `unlend` | `chain_id, market_unique_key, qty, withdraw_full=False` | Withdraw supply |
| `borrow` | `chain_id, market_unique_key, qty` | Borrow loan asset |
| `repay` | `chain_id, market_unique_key, qty, repay_full=False` | Repay borrow |
| `claim_rewards` | `chain_id, claim_merkl=True, claim_urd=True` | Claim Merkl + URD rewards |
| `vault_deposit` | `chain_id, vault_address, assets` | MetaMorpho ERC-4626 deposit |
| `vault_withdraw` | `chain_id, vault_address, assets` | MetaMorpho ERC-4626 withdraw |
| `vault_mint` | `chain_id, vault_address, shares` | MetaMorpho ERC-4626 mint |
| `vault_redeem` | `chain_id, vault_address, shares` | MetaMorpho ERC-4626 redeem |
| `borrow_with_jit_liquidity` | `chain_id, market_unique_key, qty, atomic=True` | Borrow with allocator JIT liquidity |

### Gotchas

- Morpho has **two layers**: direct Blue markets and MetaMorpho vaults. Use `get_all_markets` for the former and `get_all_vaults` for the latter.
- Deployed on many chains (Ethereum, Base, Arbitrum, Optimism, and more). Always pass the correct `chain_id`.
- **Collateral is separate from supply:** borrowing requires `supply_collateral(...)`, not `lend(...)`.
- **Full close uses shares:** `repay_full=True` / `withdraw_full=True` avoids dust from interest accrual.
- Read-only calls do not need a wallet label.

---

## Euler V2 (Multi-chain)

Euler v2 markets are **vaults** (EVK / eVaults). The vault address is both the market identifier and the ERC-4626 share token. Execution uses EVC (Ethereum Vault Connector) batching.

**Adapter:** `EulerV2Adapter`

```python
from wayfinder_paths.adapters.euler_v2_adapter import EulerV2Adapter
adapter = get_adapter(EulerV2Adapter, "main")
```

### Key Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `get_verified_vaults` | `chain_id, perspective="governed", limit=None` | Verified vault addresses |
| `get_all_markets` | `chain_id, perspective="governed", limit=None, concurrency=10` | Vault list with APYs, caps, LTV rows |
| `get_vault_info_full` | `chain_id, vault` | Full VaultLens output for a single vault |
| `get_full_user_state` | `chain_id, account, include_zero_positions=False` | Enabled vaults + balances + flags |
| `lend` | `chain_id, vault, amount` | Deposit into an eVault |
| `unlend` | `chain_id, vault, amount` | Withdraw from an eVault |
| `borrow` | `chain_id, vault, amount` | Borrow from a vault |
| `repay` | `chain_id, vault, amount` | Repay a borrow |
| `set_collateral` | `chain_id, vault` | Enable vault as collateral via EVC |
| `remove_collateral` | `chain_id, vault` | Disable vault as collateral via EVC |

### Gotchas

- Vault address = market identifier = share token. There is no separate mToken concept.
- Deployed on many chains (Ethereum, Base, Arbitrum, Berachain, and more). Always pass `chain_id`.
- Uses `perspective="governed"` by default to filter to verified vaults.

---

## HyperLend (HyperEVM)

Lending protocol on HyperEVM (Aave V3 fork). Provides lending, borrowing, and collateral management for stablecoins and native HYPE.

**Adapter:** `HyperlendAdapter`

```python
from wayfinder_paths.adapters.hyperlend_adapter import HyperlendAdapter
adapter = get_adapter(HyperlendAdapter, "main")
```

### Key Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `get_stable_markets` | `required_underlying_tokens?, buffer_bps?, min_buffer_tokens?` | Stablecoin opportunities with headroom |
| `get_assets_view` | `user_address` | User portfolio view |
| `get_all_markets` | | On-chain market discovery via UiPoolDataProvider |
| `get_market_entry` | `token` | Single market metadata |
| `get_full_user_state` | `account, include_zero_positions=False` | Aggregated user state |
| `lend` | `underlying_token, qty, chain_id, native=False` | Supply to HyperLend |
| `unlend` | `underlying_token, qty, chain_id, native=False` | Withdraw from HyperLend |
| `borrow` | `underlying_token, qty, chain_id, native=False` | Variable-rate borrow |
| `repay` | `underlying_token, qty, chain_id, native=False, repay_full=False` | Repay a borrow |
| `set_collateral` | `underlying_token, chain_id` | Enable asset as collateral |
| `remove_collateral` | `underlying_token, chain_id` | Disable asset as collateral |

### Gotchas

- All parameters are **keyword-only** (enforced with `*`).
- `qty` is raw int (wei), not float amounts.
- Uses `underlying_token` address, not a special receipt token.
- For native HYPE operations, pass `native=True` -- this uses the WrappedTokenGateway.
- `repay_full=True` reads on-chain debt, adds 0.01% buffer, and sends exact amount.
- `get_stable_markets()` and `get_assets_view()` do not take a `chain_id` -- they always query HyperEVM.

---

## Ethena sUSDe Vault (Ethereum)

ERC-4626 vault on Ethereum mainnet for staking USDe into sUSDe. Features a cooldown-based withdrawal process.

**Adapter:** `EthenaVaultAdapter`

```python
from wayfinder_paths.adapters.ethena_vault_adapter import EthenaVaultAdapter
adapter = get_adapter(EthenaVaultAdapter, "main")
```

### Key Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `get_apy` | | Spot APY estimate |
| `get_cooldown` | `account` | Cooldown end timestamp + underlying amount |
| `get_full_user_state` | `account, chain_id=1, include_apy=True, include_zero_positions=False` | Balances + cooldown + optional APY |
| `deposit_usde` | `amount_assets, receiver=None` | Stake USDe, receive sUSDe shares |
| `request_withdraw_by_shares` | `shares` | Start cooldown by sUSDe share amount |
| `request_withdraw_by_assets` | `assets` | Start cooldown by USDe asset amount |
| `claim_withdraw` | `receiver=None, require_matured=True` | Claim after cooldown matures |

### Gotchas

- The vault is **mainnet-only**. For other chains, the adapter reads balances but uses mainnet for cooldown and conversions.
- Withdrawals are **two-step**: first request a cooldown (`request_withdraw_by_shares` or `request_withdraw_by_assets`), then `claim_withdraw` after it matures.
- Amounts are raw ints (wei).
- Key addresses: USDe = `0x4c9EDD5852cd905f086C759E8383e09bff1E68B3`, sUSDe = `0x9D39A5DE30e57443BfF2A8307A4256c8797A3497`.

---

## SparkLend (Ethereum)

SparkLend is MakerDAO's lending protocol, built as an Aave V3 fork with additional native ETH operations.

**Adapter:** `SparkLendAdapter` (extends `AaveV3Adapter`)

```python
from wayfinder_paths.adapters.sparklend_adapter import SparkLendAdapter
adapter = get_adapter(SparkLendAdapter, "main")
```

### Read Methods (inherited from Aave V3)

| Method | Parameters | Description |
|--------|-----------|-------------|
| `get_all_markets` | `chain_id, include_rewards=False` | Market list with rates, caps, LTV, and optional rewards |
| `get_full_user_state_per_chain` | `chain_id, account, include_rewards=False, include_zero_positions=False` | Position snapshot for one chain |
| `get_full_user_state` | `account, include_rewards=False, include_zero_positions=False` | Cross-chain position snapshot |

### Execution Methods (inherited from Aave V3)

| Method | Parameters | Description |
|--------|-----------|-------------|
| `lend` | `chain_id, underlying_token, qty, native=False` | Supply underlying asset (`qty` is raw int) |
| `unlend` | `chain_id, underlying_token, qty, native=False, withdraw_full=False` | Withdraw supply |
| `borrow` | `chain_id, underlying_token, qty, native=False` | Borrow underlying (variable rate) |
| `repay` | `chain_id, underlying_token, qty, native=False, repay_full=False` | Repay borrow |
| `set_collateral` | `chain_id, underlying_token, use_as_collateral=True` | Toggle collateral flag |
| `remove_collateral` | `chain_id, underlying_token` | Disable asset as collateral |
| `claim_all_rewards` | `chain_id, assets=None, to_address=None` | Claim incentive rewards |

### SparkLend-Specific Methods

| Method | Parameters | Description |
|--------|-----------|-------------|
| `borrow_native` | `amount, chain_id` | Borrow native ETH (borrows WETH then unwraps) |
| `repay_native` | `amount, chain_id, repay_full=False` | Repay with native ETH (wraps then repays) |

### Gotchas

- SparkLend is an Aave V3 fork; all Aave V3 patterns apply (variable rate mode, collateral toggles, raw int amounts).
- Native ETH operations (`borrow_native`, `repay_native`) handle WETH wrapping/unwrapping automatically.
- Always pass the correct `chain_id`. Supplying an asset doesn't automatically enable it as collateral — call `set_collateral(...)`.
- See [Aave V3 reference](../aave/references/aave-v3.md) for full method documentation, script examples, and additional gotchas.

---

## References

- [Moonwell Reference](references/moonwell.md)
- [Morpho Reference](references/morpho.md)
- [Euler V2 Reference](references/euler-v2.md)
- [HyperLend Reference](references/hyperlend.md)
- [Ethena Vault Reference](references/ethena-vault.md)
- [Aave V3 / SparkLend](../aave/SKILL.md)
- [Coding Interface](../coding-interface/SKILL.md)
- [Error Reference](references/errors.md)
