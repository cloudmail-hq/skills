# Troubleshooting

## Exit codes

Branch on the exit code, not the message. These codes are part of the CLI's
contract.

| Code | Name | Meaning | What to do |
|---|---|---|---|
| 0 | ok | Succeeded | Continue. For a send, still check `status` (`pending_approval`). |
| 1 | error | Unclassified | Read stderr. |
| 2 | usage | Bad arguments or flags; nothing sent | Fix the command. Check `cloudmail schema <cmd>`. |
| 3 | not_found | No such message, mailbox or approval | List the collection to find a valid id. Check `-m`. |
| 4 | denied | Authenticated, but lacking a capability or scope | Don't retry. Tell the user which capability or scope is missing. |
| 5 | conflict | Exists already, or state changed | Read it again, then decide. `APPROVAL_REVISED`, `IDEMPOTENCY_KEY_REUSED` and `IDEMPOTENCY_IN_PROGRESS` live here. |
| 6 | unauthenticated | No usable credential | Check `cloudmail auth status`; the API token may be missing, revoked or expired. (The CLI's own schema text mentions "an Access service token"; that applies only to legacy Access deployments.) |
| 7 | rate_limited | Too many requests, or send quota | Wait `retry_after_seconds`. For `SEND_QUOTA`, tell the user. |
| 8 | network | Never reached the server | Check the base URL and connectivity, then retry. |
| 9 | server | 5xx (`SERVER_ERROR`, `SERVER_UNAVAILABLE`) | Retry, but a send only with the same `--idempotency-key`. |
| 10 | dry_run | Previewed, **nothing sent** | Expected with `--dry-run`. |
| 11 | write_refused | Blocked locally, nothing sent | A send needs `--yes` without a terminal, or `--read-only` is on. Don't add `--force` to get past it; if in doubt, write a draft. |
| 12 | invalid | Server rejected the body | Fix the fields in `details`. |
| 13 | too_large | Payload too big | Shrink or drop attachments. |
| 130 | interrupted | Cancelled | — |

### When to retry

This is the single rule set; other files point here.

| Exit and code | Retry? |
|---|---|
| 7 `RATE_LIMITED` | Yes, after `retry_after_seconds`. The CLI already retries this itself unless `--retries 0`. |
| 7 `SEND_QUOTA` | **No.** The cap won't clear in minutes. Tell the user. |
| 8, 9 on a read | Yes, with backoff. |
| 8, 9 on a send | Only with the **same** `--idempotency-key` you used first. Without one, check Sent and `approval list` before anything else. |
| 5 `IDEMPOTENCY_IN_PROGRESS` | Yes, after a second, with the same key. |
| Every other code | No. Something has to change first. |
| 0 with `status: "pending_approval"` | **Never.** It is held, not failed. |

`code` values in the envelope are uppercase (for example `RECIPIENT_NOT_ALLOWED`,
`FORBIDDEN`, `SEND_QUOTA`). The server's own lowercase codes (`draft_only`,
`recipient_not_allowed`, `person_required`) appear in the `error` text, in MCP
results, and in REST bodies.

Errors print a JSON envelope on stderr:

```json
{"code": "NOT_FOUND", "error": "Email not found",
 "remediation": "list messages with `cloudmail mail list` to find a valid id",
 "exit_code": 3, "kind": "not_found", "retryable": false}
```

The `remediation` field usually says exactly what to do.

## HTTP statuses

| HTTP | CLI code(s) | Cause | Fix |
|---|---|---|---|
| 401 | `UNAUTHENTICATED` (exit 6) | Token missing, revoked or expired, or from another deployment | `cloudmail auth status`. Ask the user for a valid token. Check `base-url`. |
| 403 | `INSUFFICIENT_SCOPE` (4) | The token lacks a scope, named in the message | The user creates a token with that scope. |
| 403 | `FORBIDDEN` (4), naming a capability | The user's grant on that mailbox lacks it, for example `sendAs` | An administrator grants it in Settings → Access. Or write a draft. |
| 403 | `SESSION_REQUIRED`, `REAUTH_REQUIRED`, `PERSON_REQUIRED` (4) | Browser-only action | The user does it in the web app. |
| 403 | `FORBIDDEN` (4), error mentions draft only | Agent sends are off for this mailbox (server code `draft_only`, or `drafts_only` for an agent inbox) | Write a draft. |
| 402 | `LICENCE_REQUIRED` (4) | The deployment's licence lapsed | An administrator renews it. |
| 409 | `CONFLICT` (5) | Already exists, already decided, or changed since read | Read it again. Don't blindly retry. |
| 409 | `APPROVAL_REVISED` (5) | The held send was revised after you fetched it; nothing sent | `approval show`, review, approve again. |
| 409 | `IDEMPOTENCY_KEY_REUSED` (5) | Same key, different arguments | Use a new key for a different request. |
| 409 | `IDEMPOTENCY_IN_PROGRESS` (5) | The first request with this key is still running | Wait a second and rerun with the same key. |
| 422 | `RECIPIENT_NOT_ALLOWED` (12) | Agent inbox recipient outside `allowed_recipients` | Don't send. Tell the user. |
| 429 | `RATE_LIMITED` (7) | 600 API requests or 120 MCP requests a minute | Wait. The CLI retries this itself unless `--retries 0`. |
| 429 | `SEND_QUOTA` (7) | Mailbox send cap (20/hour, 100/day by default) | Tell the user, or schedule the message. |

## `pending_approval` is not an error

A send that returns `status: "pending_approval"` (HTTP 202, exit 0) is held for
a person. Don't treat it as a failure, don't retry, and don't send another way.
Tell the user. To change it, use `cloudmail approval revise <approval-id>`.
See [sending-and-approvals.md](sending-and-approvals.md).

The CLI's stderr says "sent as" with an empty id even for a held send. Trust the
`status` field on stdout.

## Common situations

**"command not found: cloudmail"**: see [install.md](install.md). If it was
just installed, check that the install directory (default `~/.local/bin`) is on
`PATH`.

**Exit 8 with "no such host"**: the base URL is wrong or unset. Check it with
`cloudmail config get base-url` and ask the user for the right one.

**Exit 11 on a send**: there is no terminal, so the CLI needs `--yes`. Add it
only for a message the user wants sent. Or `--read-only` / `CLOUDMAIL_READ_ONLY`
is on.

**Exit 6 even though a token is set**: the token belongs to a different
deployment or profile, or it was revoked. `cloudmail auth status` shows which
source it came from. `CLOUDMAIL_TOKEN` overrides a stored token.

**A credentials file ignored with a warning**: it is readable by other users.
The user runs `chmod 600` on it.

**Exit 4 on `mail send` but drafts work**: you have `draft` but not
`sendAs`/`sendOnBehalf` on that mailbox. Write a draft and tell the user.

**Search returns odd results**: an operator name is probably misspelled. Unknown
operators fall back to plain text search.

**The deployment uses Cloudflare Access**: API tokens are ignored there. See the
legacy section in [auth.md](auth.md).

**Anything else**: `cloudmail <command> --help`, `cloudmail guide`, or
`cloudmail schema <command>` for the exact flags. `--verbose` traces the
requests to stderr. It shows the idempotency key but not the token.
