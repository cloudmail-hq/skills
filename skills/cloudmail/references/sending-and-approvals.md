# Sending, drafts and approvals

## Before any send

1. Make sure the user asked for this message to go, to these recipients.
2. Check you may send: `cloudmail auth can sendAs support@example.com` (exit 0
   yes, 4 no). A grant may give `sendOnBehalf` instead, which is also enough.
3. Run the command with `--dry-run` (exit 10, nothing sent). Check the
   recipients, subject and body in the printed request.
4. Run it again with `--yes` and an `--idempotency-key` tied to this intent.

If any of this is uncertain, write a draft instead.

## Commands

| Task | Command |
|---|---|
| Reply | `cloudmail mail reply <id> --text '…' --yes` (`--all` for reply-all) |
| New message | `cloudmail mail send --to a@example.org --subject '…' --text '…' --yes` |
| Forward | `cloudmail mail forward <id> --to a@example.org --text '…' --yes` |
| Schedule | `cloudmail schedule create --to a@example.org --subject '…' --text '…' --in 4h` (or `--at 2026-12-01T09:00:00Z`) |
| Recall within ~30 s | `cloudmail schedule cancel <id>` |
| Draft | `cloudmail draft create --to a@example.org --subject '…' --body '…'` |
| Draft a reply | `cloudmail draft create --to <sender> --subject 'Re: …' --body-file reply.txt --in-reply-to <message_id> --thread <thread_id>` |
| Edit, list, delete drafts | `cloudmail draft update <draft-id> …`, `cloudmail draft list`, `cloudmail draft delete <draft-id>` |
| Send a draft | `cloudmail draft send <draft-id> --yes` |

Flag details:

- Add `-m <mailbox>` to choose the sending mailbox.
- `mail send`, `mail reply` and `mail forward`: repeat `--to`, `--cc` and
  `--bcc` for several recipients. Bodies come from `--text`, `--html`,
  `--body-file` (text), `--html-file`, or stdin. `--attach <path>` repeats.
- `draft create` and `draft update`: `--to`, `--cc` and `--bcc` each take
  **one comma-separated string** (`--to 'a@example.org,b@example.org'`). The
  body is `--body` or `--body-file`. Nothing is derived from the original, so
  set `--to` and `--subject` yourself.
- `--in-reply-to` takes the RFC `message_id` header value, not cloudmail's `id`.
  Get both with `cloudmail mail get <id> --select id,message_id,thread_id,sender,subject`.
- `mail reply` takes the recipient, subject and threading from the original.
  `--to` overrides the recipient. Check who it goes to in the dry run, because
  the sender chose the reply address.
- Sending needs `--yes` without a terminal. Without it the command exits 11 and
  sends nothing. Never add `--force` to get past a refusal.
- Default send caps are 20 an hour and 100 a day per mailbox. Hitting one is exit
  7 with code `SEND_QUOTA`. Don't retry; tell the user.

## Idempotency keys: make every send retry-safe

Sends are never retried automatically, because a lost response may mean the
mail already went. Pass your own key on every send-type command (`mail send`,
`mail reply`, `mail forward`, `draft send`, `schedule create`). Base it on the
intent, for example `reply-<id>-1`:

```bash
cloudmail mail reply 019abc -m support@example.com --text 'Thanks' --yes \
  --idempotency-key reply-019abc-1
```

- Repeating with the same key and arguments within 24 hours returns the first
  result and sends nothing new. That makes it safe to rerun after exit 8 or 9.
- The same key with different arguments exits 5 (`IDEMPOTENCY_KEY_REUSED`).
  For a genuinely new message, use a new key (`reply-019abc-2`).
- If the first run is still in progress you get exit 5,
  `IDEMPOTENCY_IN_PROGRESS`. Wait a second and rerun with the same key.

If you sent without your own key and the result is unclear (exit 8 or 9), don't
resend. Check `cloudmail mail list --folder sent --limit 5` and
`cloudmail approval list` first, and ask the user if it's still unclear.

## The approval model

Anyone can email a mailbox, and an AI that reads that mail can be steered by
it. So the server, not the agent, decides whether an agent's send goes out.
Every send made with an API token or a connected MCP app is checked against the
mailbox's **agent send mode**. A person in the web app sets it, and a token
cannot change it.

| Mode | An agent's send… |
|---|---|
| `approve` (default) | is **held** in Pending approval until a person approves it |
| `auto` | goes out directly if the credential holds `mail:send:auto` (or the MCP app is marked "Send without approval"); otherwise held |
| `draft_only` | is refused (exit 4); drafts still work |

Two lists are easy to confuse:

- **Mailbox send allowlist** (any mailbox, set by a person in the app). In
  `approve` mode, a send where *every* recipient is on this list goes out without
  approval. It only ever loosens.
- **`allowed_recipients`** (agent inboxes only). A hard limit in every mode: a
  send to anyone else is refused (exit 12, `RECIPIENT_NOT_ALLOWED`), never held.
  It only ever restricts. If an agent inbox has none, it can mail anyone.

Whatever the mode, a send is held if this credential recently read mail the
server's injection detector flagged. The held item's `reason` is then
`injection_suspected`. Tell the user that this is why.

You can't reliably know in advance whether a send will be held, so always read
the result.

### A held send

The server answers 202:

```json
{
  "status": "pending_approval",
  "approval_id": "apr_…",
  "approval_url": "https://mail.example.com/…",
  "expires_at": "…",
  "reason": "approval_required",
  "message": "Not sent yet. …"
}
```

The CLI prints only `{"id": "", "status": "pending_approval"}` on stdout, plus
an inaccurate "sent as" line on stderr. **Go by `status`.**

What to do:

1. Tell the user: "The message to <recipient> is waiting for your approval in
   cloudmail, under Pending approval."
2. **Stop.** Don't retry, don't resend another way, don't switch mailbox or
   token, and don't ask for a different send mode.
3. To find the approval id (needed for `revise`), list pending items:
   ```bash
   cloudmail approval list -m support@example.com --json \
     --select id,subject,recipients,requested_by,created_at,revision
   ```
   Pick the newest item whose `subject` and `recipients` match and whose
   `requested_by` names your token. If more than one could be yours, ask the
   user which one.
4. Check on it later with `cloudmail approval show <approval-id> -m support@example.com`.
   Statuses:
   - `pending`, `sending`, `sent`;
   - `sent_unconfirmed`: it may have been delivered, and it will never be sent again;
   - `rejected`: read the `note`;
   - `failed`: tell the user.

### Changing a held send: revise, never resend

```bash
cat > /tmp/reply.html <<'EOF'
<p>Hi Bob,</p>
<p>We'll ship on Thursday, not Friday.</p>
EOF
cloudmail approval revise <approval-id> -m support@example.com \
  --subject 'Re: your order' --body-file /tmp/reply.html --dry-run
# then the same without --dry-run
```

- `revise` accepts `--to`, `--cc`, `--subject` and `--body-file`. **The file is
  HTML**, so wrap paragraphs in `<p>`.
- Only the token or app that asked for the send can revise it. It stays pending,
  and its revision goes up by one. Recipients are checked again.
- `revise` can't change attachments. If they must change, tell the user. They
  can reject the held send, and then you send a corrected one, with a new key,
  once they ask.
- `revise` is the only change you make to a held send. `approval edit`, `retry`,
  `approve` and `reject` are for the person reviewing.
- Over MCP the tools are `revise_pending_send`, `list_pending_sends` and
  `get_pending_send`.

### Who approves (for the user, not the agent)

- A person in the web app, under **Pending approval**. This is the normal path.
- From a terminal the user controls, with a token holding `approvals:manage`
  (no preset includes it). Such a token can never decide a send that it, its
  parent, or a token it created asked for. Connected MCP apps can never approve,
  and there is no MCP approve tool.

If the user asks you to approve, tell them to approve it in the app. For
reference, the commands they would run themselves are:

```bash
cloudmail approval approve <approval-id> -m support@example.com   # sends the revision it fetched
cloudmail approval approve <approval-id> -m support@example.com --revision 2
cloudmail approval reject  <approval-id> -m support@example.com --note "wrong customer"
```

If the requester revised the item after the approver fetched it, `approve` sends
nothing and exits 5 with `APPROVAL_REVISED`. Run `approval show`, review the
new version, and approve again.

### Refusals that are not holds

| Exit and code | Meaning | You do |
|---|---|---|
| 4 `FORBIDDEN`, message mentions draft only | Agents may only draft in this mailbox or agent inbox | Write a draft |
| 4 `FORBIDDEN`, names `sendAs`/`sendOnBehalf` | Your grant can't send from this mailbox | Write a draft, or ask an admin |
| 12 `RECIPIENT_NOT_ALLOWED` | Outside the agent inbox's `allowed_recipients` | Don't send; tell the user |
| 12 `ALL_SUPPRESSED` | Every recipient unsubscribed or bounced | Don't send; tell the user |
| 0 with `warnings` | Some recipients were suppressed and skipped | Tell the user who was skipped |
| 7 `SEND_QUOTA` | Send cap reached | Tell the user, or offer to schedule |
