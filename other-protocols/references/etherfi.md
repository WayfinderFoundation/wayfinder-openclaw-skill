# ether.fi (Liquid Restaking)

## Overview

ether.fi is a liquid restaking protocol on Ethereum mainnet. Stake ETH to receive eETH (rebasing), wrap to weETH (non-rebasing, DeFi-composable), and manage async withdrawals via WithdrawRequest NFTs.

- **Type**: `ETHERFI`
- **Module**: `wayfinder_paths.adapters.etherfi_adapter.adapter.EtherfiAdapter`
- **Capabilities**: `staking.stake`, `staking.wrap`, `staking.unwrap`, `withdrawal.request`, `withdrawal.claim`, `position.read`

## Supported chains

Ethereum mainnet only (`chain_id = 1`). All methods raise `ValueError` for other chains.

## Contract addresses (Ethereum mainnet)

| Contract | Address |
|----------|---------|
| LiquidityPool | `0x308861A430be4cce5502d0A12724771Fc6DaF216` |
| eETH | `0x35fA164735182de50811E8e2E824cFb9B6118ac2` |
| weETH | `0xCd5fE23C85820F7B72D0926FC9b05b43E359b7ee` |
| WithdrawRequestNFT | `0x7d5706f6ef3f89b3951e23e557cdfbc3239d4e2c` |

## High-value reads

| Method | Purpose | Wallet needed? |
|--------|---------|----------------|
| `get_pos(account?, chain_id=1, include_shares=True)` | eETH/weETH balances, weETH→eETH conversion rate, total pooled ether | No (if you pass `account`) |
| `is_withdraw_finalized(token_id, chain_id=1)` | Check if a WithdrawRequest NFT is claimable | No |
| `get_claimable_withdraw(token_id, chain_id=1)` | Get claimable ETH amount for a finalized request (returns 0 if not finalized) | No |

### `get_pos` response structure

```python
{
    "protocol": "etherfi",
    "chain_id": 1,
    "account": "0x...",
    "contracts": { "liquidity_pool": "0x...", "eeth": "0x...", "weeth": "0x...", "withdraw_request_nft": "0x..." },
    "eeth": {
        "balance_raw": int,       # eETH balance (wei)
        "shares_raw": int,        # eETH internal share count
    },
    "weeth": {
        "balance_raw": int,       # weETH balance (wei)
        "eeth_equivalent_raw": int, # weETH converted to eETH equivalent (wei)
        "rate": int,              # weETH/eETH conversion rate (1e18 = 1:1)
    },
    "liquidity_pool": {
        "total_pooled_ether": int,
    }
}
```

### Script example: check position

```python
import asyncio
from wayfinder_paths.mcp.scripting import get_adapter
from wayfinder_paths.adapters.etherfi_adapter import EtherfiAdapter

USER = "0x0000000000000000000000000000000000000000"

async def main() -> None:
    adapter = get_adapter(EtherfiAdapter)  # read-only
    ok, pos = await adapter.get_pos(account=USER)
    if not ok:
        raise RuntimeError(pos)
    print("eETH balance:", pos["eeth"]["balance_raw"])
    print("weETH balance:", pos["weeth"]["balance_raw"])
    print("weETH→eETH rate:", pos["weeth"]["rate"])

if __name__ == "__main__":
    asyncio.run(main())
```

## Execution (fund-moving)

All execution methods require a signing wallet (`get_adapter(EtherfiAdapter, "<wallet_label>")`).

| Method | Purpose | Notes |
|--------|---------|-------|
| `stake_eth(amount_wei, chain_id=1, referral?, check_paused=True)` | Stake ETH → receive eETH shares | Payable tx; checks if pool is paused by default |
| `wrap_eeth(amount_eeth, chain_id=1, approval_amount=MAX_UINT256)` | Wrap eETH → weETH | Performs approval tx first |
| `wrap_eeth_with_permit(amount_eeth, permit, chain_id=1)` | Wrap eETH → weETH with EIP-2612 permit | Single atomic tx, no approval needed |
| `unwrap_weeth(amount_weeth, chain_id=1)` | Unwrap weETH → eETH | No approval required |
| `request_withdraw(amount_eeth, recipient?, chain_id=1, include_request_id=True)` | Request async withdrawal → mints WithdrawRequest NFT | Approval tx first; returns `request_id` (NFT token ID) |
| `request_withdraw_with_permit(amount_eeth, permit, owner?, chain_id=1, include_request_id=True)` | Request async withdrawal with EIP-2612 permit | Single atomic tx |
| `claim_withdraw(token_id, chain_id=1)` | Claim finalized withdrawal → receive ETH | Must be NFT owner; must be finalized first |

### Withdrawal flow

1. **Request**: `request_withdraw(amount_eeth=...)` → returns `{"tx": "0x...", "request_id": <nft_token_id>}`
2. **Wait**: Poll `is_withdraw_finalized(token_id=...)` (can take **days**)
3. **Claim**: `claim_withdraw(token_id=...)` → receives ETH

### EIP-2612 permit format

For `wrap_eeth_with_permit` and `request_withdraw_with_permit`:

```python
permit = {
    "value": int,      # Allowance amount
    "deadline": int,   # Unix timestamp
    "v": int,          # Signature v
    "r": bytes | str,  # Signature r (hex or bytes, auto-normalized to 32 bytes)
    "s": bytes | str,  # Signature s (hex or bytes, auto-normalized to 32 bytes)
}
```

## Gotchas

- **Mainnet only:** all operations require `chain_id=1`. Other chains raise `ValueError`.
- **eETH is rebasing:** internal shares determine balances. Wrapping a full eETH balance can leave 1 wei dust due to share-based rounding.
- **weETH is non-rebasing:** value accrues via increasing weETH→eETH rate, not balance changes. Use weETH for DeFi composability.
- **Withdrawals are slow:** async processing takes **days** (batch-processed by ether.fi). Always poll `is_withdraw_finalized()` before calling `claim_withdraw()`.
- **`request_id` is best-effort:** `include_request_id=True` parses the NFT token ID from the tx receipt. This can return `None` even on successful transactions.
- **No APYs or rewards:** the adapter returns only on-chain balances and conversions. Do not invent yield figures.
- **Amounts are raw ints (wei):** all `amount_*` parameters use raw integer units.
