# Error Handling

All Delta Lab queries are read-only `resource` calls. Errors return structured JSON: `{"ok": false, "error": {"code": "...", "message": "...", "details": ...}}`.

## Error Categories

### Validation Errors — bad input, fixable by the caller

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `invalid_request` | Missing or invalid required parameters | Empty symbol, invalid `lookback_days` (must be >= 1), `limit` exceeding max, malformed URI template | Tell the user which parameter is wrong and show the correct URI format |
| `invalid_token` | Symbol resolution failed | Typo in symbol, using coingecko ID instead of root symbol (e.g. `bitcoin` instead of `BTC`), lowercase where uppercase is expected | Suggest running `resource wayfinder://delta-lab/symbols` to see valid basis symbols, or `resource wayfinder://delta-lab/assets/search/all/<query>/25` for asset lookup |

### Resource Errors — something doesn't exist

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `not_found` | Asset, basis group, or resource not found | `asset_id` doesn't exist, symbol not tracked by Delta Lab, basis group has no data | List available symbols with `resource wayfinder://delta-lab/symbols` or search with `assets/search/...` |

### API & Integration Errors — upstream service failures

| Error Code | Meaning | Common Causes | User-Facing Guidance |
|------------|---------|---------------|----------------------|
| `token_error` | Delta Lab API call failed | Delta Lab service unavailable, network timeout, rate limit | Retry after a moment; if persistent, the Delta Lab service may be down |
| `price_error` | Price data unavailable | Asset too new or illiquid for price data, timeseries has no data for the requested window | Note that the asset may not have sufficient history for the requested lookback period; try a shorter lookback or different series |

## Error Details Object

The `details` field varies by error code and may contain:

| Field | Present On | Description |
|-------|-----------|-------------|
| `parameter` | `invalid_request` | The specific parameter that failed validation |
| `query` | `invalid_token`, `not_found` | The symbol or query that failed resolution |
| `candidates` | `invalid_token` | Fuzzy match candidates when the API provides suggestions |
| `suggestions` | `invalid_request` | Suggested valid values (e.g. valid basis symbols) when the API returns them |
| `upstream_error` | `token_error`, `price_error` | Raw error message from the Delta Lab API |

## HTTP Status Codes (from Delta Lab API)

When errors originate from the Delta Lab API directly, these status codes indicate the type of failure:

| Status | Meaning | Action |
|--------|---------|--------|
| **400** | Invalid parameters or unknown symbol | Check the error message — may include `suggestions` for valid symbols |
| **404** | Asset not found (single asset lookup only) | The `asset_id` doesn't exist; search for the asset instead |
| **500** | Internal server error | Transient; retry after a moment |

## Presenting Errors to Users

When an error is returned:

1. **Translate the code** — don't show raw error codes. Map to plain language (e.g. `not_found` -> "Delta Lab doesn't track that symbol").
2. **Include the actionable fix** — every error has a recovery path. Always tell the user what to do next.
3. **Show relevant details** — if `details.suggestions` or `details.candidates` exist, list them so the user can pick the right value.
4. **Offer to retry** — for transient errors (`token_error`, `price_error`), offer to retry. For validation errors, show the corrected URI.

## Common User-Facing Issues

| Symptom | Error Code | Resolution |
|---------|-----------|------------|
| "Unknown symbol" | `invalid_request` / `invalid_token` | Use uppercase root symbols (`BTC`, `ETH`, `USD`). Run `wayfinder://delta-lab/symbols` to see all valid symbols |
| "No data for lookback" | `price_error` | The asset may not have enough history. Try a shorter `lookback_days` value |
| "Asset not found" | `not_found` | The `asset_id` doesn't exist. Search by symbol: `wayfinder://delta-lab/assets/search/all/<query>/25` |
| "Service unavailable" | `token_error` | Delta Lab API may be temporarily down. Retry after a moment |
| Null APY values in results | — | Not an error. APY is `null` when insufficient data exists for the lookback window. Filter or default: `apy["value"] or 0` |
| Unexpected results for a specific token | — | The broad `basis` screen may not include niche assets in the top N. Use `by-asset-ids` screens with the exact `asset_id` instead |
