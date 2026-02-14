# Error Handling

All errors return structured JSON: `{"ok": false, "error": {"code": "...", "message": "...", "details": ...}}`.

## Error Categories

### Validation Errors — bad input, fixable by the caller

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `invalid_request` | Missing or invalid required parameters | Omitted `action`, empty `strategy`, missing `token_id` for balance query | Tell the user which parameter is missing and show the correct command format |
| `invalid_wallet` | Wallet missing `address` or `private_key_hex` | Wallet label exists but entry is incomplete; read-only wallet used for execution | Ask the user to check their config.json wallet entry has both fields |
| `invalid_token` | Token resolution failed — missing `chain_id` or contract `address` after lookup | Typo in token ID, token not indexed, ambiguous symbol without chain qualifier | Suggest running `resource wayfinder://tokens/search/<chain>/<query>` and show the closest matches |
| `invalid_amount` | Amount not parseable, not positive, or zero after decimal scaling | Non-numeric string, negative value, amount like `0.000000001` that rounds to 0 for a low-decimal token | Show the parsed value and the token's decimals so the user understands the rounding |

### Resource Errors — something doesn't exist

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `not_found` | Directory, manifest, wallet, or resource not found | Strategy name typo, adapter not installed, wallet label doesn't match config | List available resources (`resource wayfinder://strategies`) so the user can pick the right name |
| `not_supported` | Strategy does not implement the requested action | Calling `withdraw` on a strategy that only supports `status`/`deposit` | Show which actions the strategy does support (from its manifest) |
| `requires_confirmation` | Operation needs explicit user confirmation before proceeding | `discover_portfolio` across >= 3 protocols without `--parallel` flag | Explain the operation scope and ask the user to confirm or pass `--parallel` |

### API & Integration Errors — upstream service failures

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `token_error` | Token adapter API call failed | Wayfinder API down, network timeout, invalid API key | Check API key validity; retry after a moment; show the raw error message from details |
| `quote_error` | Swap/bridge quote generation failed | No liquidity for pair, amount too small for routing, bridge route unavailable | Suggest trying a different amount, checking if the pair is supported, or using a different route |
| `balance_error` | Balance query failed | RPC node down, rate-limited, invalid chain_id | Retry; if persistent, check RPC URL configuration |
| `activity_error` | Activity/transaction history query failed | Indexer lag, unsupported chain for activity | Inform user the history service may be temporarily unavailable |
| `price_error` | Price lookup failed | Token not priced by CoinGecko, API rate limit | Note that the token may be too new or illiquid for price data; balances are still valid without prices |

### Execution Errors — on-chain failures

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `executor_error` | On-chain transaction failed | Insufficient gas, contract revert, nonce conflict, allowance issue | Show the revert reason if available; check gas balance; for USDT-style tokens, mention the zero-allowance reset |
| `strategy_error` | Strategy runtime exception | Unhandled edge case in strategy code, external dependency failure mid-execution | Show the exception message; suggest checking `status` before retrying |

## Error Details Object

The `details` field varies by error code and may contain:

| Field | Present On | Description |
|-------|-----------|-------------|
| `parameter` | `invalid_request` | The specific parameter that failed validation |
| `wallet_label` | `invalid_wallet`, `not_found` | The wallet label that was looked up |
| `query` | `invalid_token` | The token query that failed resolution |
| `candidates` | `invalid_token` | Fuzzy match candidates when available |
| `raw_amount` | `invalid_amount` | The original amount string provided |
| `scaled_amount` | `invalid_amount` | The amount after decimal scaling (shows why it became zero) |
| `decimals` | `invalid_amount` | Token decimals used for scaling |
| `tx_hash` | `executor_error` | Transaction hash if the tx was submitted before failing |
| `revert_reason` | `executor_error` | Decoded revert reason from the contract |
| `strategy` | `strategy_error`, `not_supported` | Strategy name |
| `supported_actions` | `not_supported` | List of actions the strategy does implement |
| `protocols` | `requires_confirmation` | The protocols that would be queried |
| `upstream_error` | `token_error`, `quote_error`, `balance_error`, `activity_error`, `price_error` | Raw error message from the upstream service |

## Presenting Errors to Users

When an error is returned, follow this pattern:

1. **Translate the code** — don't show raw error codes. Map to plain language (e.g., `invalid_token` -> "I couldn't find that token").
2. **Include the actionable fix** — every error above has a recovery path. Always tell the user what to do next.
3. **Show relevant details** — if `details.candidates` exists, list the closest token matches. If `details.revert_reason` exists, explain what the contract rejected.
4. **Offer to retry** — for transient errors (`token_error`, `balance_error`, `quote_error`, `activity_error`, `price_error`), offer to retry. For validation errors, show the corrected command.

## Common User-Facing Issues

| Symptom | Error Code | Resolution |
|---------|-----------|------------|
| "Missing config" | `not_found` | Run setup or create `config.json` manually |
| "strategy_wallet not configured" | `invalid_wallet` | Add wallet with matching label to config.json |
| "Minimum deposit" | `invalid_amount` | Check strategy minimum requirements (e.g., Hyperliquid >= 5 USDC) |
| "Insufficient gas" | `executor_error` | Fund wallet with native gas token for the target chain |
| "Token not found" | `invalid_token` | Use `resource wayfinder://tokens/search/<chain>/<query>` to find the correct coingecko ID |
| "No quote available" | `quote_error` | Try a different amount, check pair liquidity, or use an alternative route |
| "Nonce too low" | `executor_error` | A previous transaction is pending; wait or speed it up |
| "Allowance reset needed" | `executor_error` | For USDT-style tokens, the CLI auto-resets allowance — retry if it was a transient RPC issue |
| "Rate limited" | `token_error` / `balance_error` | Wait a few seconds and retry the request |
