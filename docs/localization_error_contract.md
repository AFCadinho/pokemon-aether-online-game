# Localized backend error contract

Status: active

Player-facing backend failures use a stable machine-readable code:

```json
{
  "detail": {
    "code": "guild_name_unavailable",
    "message": "That guild name is already in use."
  }
}
```

The code controls player presentation. The English `message` remains compatibility
and diagnostic metadata and must never be rendered directly by a player-facing UI.

`BackendErrorLocalization` resolves codes for English, Dutch, and Brazilian
Portuguese. It understands top-level `code`, `errorCode`, and `error_code` fields, as
well as nested `detail` and `body.detail` responses. Known codes map to a localized
domain message. Unknown codes use `backend.error.generic`; raw server details remain
available through `diagnostic_message()` or `diagnosticError` after `decorate()`.

Player-facing account, action, storage, social, trade, shop, mail, and battle HTTP
clients route response errors through this resolver. Background content-metadata
loaders retain diagnostic-only failures and never render their raw text. Connection,
TLS, and timeout failures use the same localized safe-message policy.

The account service preserves existing domain codes. Legacy `HTTPException` responses
without a code receive a stable category:

- `request_invalid`;
- `authentication_required`;
- `action_forbidden`;
- `resource_not_found`;
- `request_conflict`;
- `payload_too_large`;
- `rate_limited`;
- `service_error` or `service_unavailable`;
- `request_timeout`;
- `request_failed`.

When adding a new player-facing backend failure:

1. add a specific stable code at the backend source;
2. keep variable values as separate response fields;
3. map the code in `BackendErrorLocalization`;
4. add every referenced translation key to all three catalogs;
5. test known-code, unknown-code, and diagnostic behavior;
6. never parse English prose to decide gameplay or UI behavior.
