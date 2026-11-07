# Authentication and configuration

## What you need

1. **The deployment's address**, for example `https://mail.example.com`. Ask
   the user; every deployment has its own.
2. **An API token**, which looks like `ttk_<id>_<secret>`. The user creates it
   in the web app at **Settings → Account & security → API tokens**. The token
   is shown only once.

## Point the CLI at the deployment

```bash
cloudmail config set base-url https://mail.example.com
cloudmail config set mailbox support@example.com     # optional default mailbox
```

Or per process: `CLOUDMAIL_BASE_URL=https://mail.example.com` and
`CLOUDMAIL_MAILBOX=support@example.com`. A `--base-url` flag overrides both.
Settings resolve as config file, then environment, then flags.

## Give the token to the CLI

Tokens are never accepted as command-line flags. A flag is visible to every
user on the machine and lands in shell history. Use one of these, best first
for agents:

1. Ask the user to create the token and save it themselves, for example: "Create
   a token, save it to `~/.config/cloudmail/token`, run
   `chmod 600 ~/.config/cloudmail/token`, and tell me when it's done." Don't
   ask them to paste it into the conversation, and don't write it to disk
   yourself.
2. Then pick one way to hand it to the CLI:

| Method | How | Notes |
|---|---|---|
| Stored per profile (simplest) | `cloudmail auth login --with-token < ~/.config/cloudmail/token` | Run once. Saved `0600` in `credentials` beside the config, and checked against the deployment first. Works in every later shell. |
| Token file per command | `CLOUDMAIL_TOKEN_FILE=~/.config/cloudmail/token cloudmail …` | Agent shells often don't keep `export`s between commands, so prefix each command. |
| Environment | `CLOUDMAIL_TOKEN` set by the user's shell profile, a secret manager or CI | Only works if it is in your process environment. It overrides the file and the stored token. |

Precedence: `CLOUDMAIL_TOKEN` beats `CLOUDMAIL_TOKEN_FILE`, which beats the
stored token. `cloudmail auth logout` deletes the stored token but does not
revoke it. To revoke a token, use the web app or `cloudmail token revoke <id>`.

## Check it worked

```bash
cloudmail auth status        # auth_method: api-token, and where the token came from
cloudmail auth whoami        # user, mailboxes, capabilities, and the token's scopes
cloudmail auth can sendAs support@example.com   # exit 0 if allowed, 4 if not
```

Capabilities are `read`, `draft`, `sendAs`, `sendOnBehalf`, `organise`,
`delete`, `deletePermanently`, `manageRules` and `manageSettings`. A capability
list of `null` means unrestricted: the user is an administrator, or per-mailbox
roles are not enforced on this deployment.

## Scopes and mailbox limits

A token can be limited to **scopes** and to specific **mailboxes**. What it can
do is the user's own access ∩ its scopes ∩ its mailboxes. A scope never adds
anything the user could not already do.

| Scope | Allows |
|---|---|
| `mail:read` | list, read, search, attachments, people, analytics |
| `mail:draft` | drafts |
| `mail:send` | send, reply, forward, scheduled sends (held for approval by default) |
| `mail:send:auto` | sending without approval, only where the mailbox is set to `auto` |
| `mail:organize` | move, label, read/star, snooze, trash |
| `mailboxes:manage` | mailbox settings; creating agent inboxes (administrators) |
| `approvals:manage` | approving or rejecting held sends (never its own) |
| `domains:manage`, `webhooks:manage`, `admin` | administration |

Suggest the narrowest token for the job:

```bash
# Reading and drafting only
cloudmail token create assistant-reader --scope mail:read,mail:draft \
  --mailbox support@example.com --expires-in 30

# Reading, drafting and sending (sends held for approval)
cloudmail token create assistant --scope mail:read,mail:draft,mail:send \
  --mailbox support@example.com --expires-in 30
```

`--expires-in` is in days (`0` for never). `token create` prints the secret once, to stdout. If you ran it, the secret would
land in your transcript, so give the user the command to run in their own
terminal, or have them create the token in the web app.

A token created with neither scopes nor mailboxes acts with the user's full
authority. A scoped token can only create narrower child tokens, and revoking a
token revokes the tokens it created.

## Several deployments: profiles

```bash
cloudmail config set base-url https://mail.example.com --in-profile work
cloudmail --profile work auth login --with-token < work-token
cloudmail --profile work mail list --folder inbox
cloudmail config use work            # make it the default
cloudmail config profiles
```

`CLOUDMAIL_PROFILE` selects a profile per process. The config file is
`~/.config/cloudmail/config.json`; `cloudmail config path` prints the real
location. It never holds a secret.

## Things a token cannot do

Some actions need a signed-in person in the browser, and the server refuses an
API token for them by design (`session_required`, `reauth_required` or
`person_required`, exit 4):

- changing a mailbox's agent send mode or its recipient allowlist;
- changing passwords, 2FA or users;
- licence activation, account deletion and export, Cloudflare connection, and
  AI gateway changes.

Tell the user to do these in the web app.

## Legacy: Cloudflare Access deployments

A deployment still in Cloudflare Access mode ignores API tokens. There, the
user creates an Access service token and exports
`CLOUDMAIL_CLIENT_ID` and `CLOUDMAIL_CLIENT_SECRET` (or
`CLOUDMAIL_CLIENT_SECRET_FILE`), with `CLOUDMAIL_TOKEN` unset.
