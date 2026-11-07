# Pre-publication review of the cloudmail skill

Reviewed on 2026-11-07, against commit 286fedd. Commands were checked against
`cloudmail schema` and `cloudmail --help` from the CLI at 881ff10, and against
`--dry-run --base-url https://mail.example.com`. A second, independent review
came from Gemini 3.8 Flash (High) through `agy`; its findings are marked (G).

Checks after the fixes:

- `claude plugin validate --strict .` passes.
- `uvx --from skills-ref agentskills validate skills/cloudmail` passes.
- `shellcheck -s sh` is clean on both scripts.
- `install.sh` was tested under sh and dash against a local fake release. It
  installs from a `SHA256SUMS` with CRLF line endings, upper-case hex and
  `*name` entries. It refuses a tampered archive and leaves nothing installed.

## Publishing and links

| Finding | Resolution |
|---|---|
| Every link pointed at `tapetide-com/cloudmail-skill` or `tapetide-com/cloudmail` | Changed to `cloudmail-hq/skills` and `cloudmail-hq/cloudmail` in the README, `plugin.json`, `SKILL.md` metadata, `install.sh`, `install.md` (script URL, PowerShell, build from source) and `SUBMISSION_PLAN.md`. No `tapetide-com` reference is left. |
| Marketplace was named `tapetide-cloudmail` | Renamed to `cloudmail`. It passes strict validation and is not a reserved name, so the install line is `/plugin install cloudmail@cloudmail`. |
| README clone-and-copy steps used the old folder name | The clone now goes into `cloudmail-skills/`, and the `cp` lines match it. |
| `SUBMISSION_PLAN.md` described the old asset names and an open question about the org | Rewritten for the cloudmail-hq names, the new assets, the `v0.1.0` tag that `install.md` links to, and the CLI fixes the skill depends on. The settled question was removed. |
| `skills-ref validate` is not an executable the package provides (G) | Changed to `uvx --from skills-ref agentskills validate`. |
| LICENSE said "Copyright (c) 2026 Cloudflare, Inc." | The skill is Tapetide's own work. Only the main app is forked from cloudflare/agentic-inbox, and its NOTICE says so. Changed to "Copyright 2026 Tapetide", which matches the plugin manifests. |

## Install script and PowerShell snippet

| Finding | Resolution |
|---|---|
| Downloaded the old bare-binary names `cloudmail-<tag>-<os>-<arch>` | `install.sh` now downloads `cloudmail_<version>_<os>_<arch>.tar.gz` from `releases/latest/download/` (or `releases/download/<tag>/` when pinned). It reads the exact name from `SHA256SUMS` with a strict pattern, then verifies and unpacks it. It no longer probes the redirect for the tag. |
| No `pipefail` | Added `set -o pipefail` where the shell supports it, in both scripts. |
| CRLF or upper-case hex in `SHA256SUMS` broke matching (G) | Carriage returns are stripped and the hash is lower-cased. The hash must be 64 hex characters. |
| A missing `sha256sum` and `shasum` gave a raw `not found` error (G) | The script checks for them, with `tar` and `curl`, before downloading. |
| `install` is not POSIX (G) | Replaced with `cp` to a temporary name, `chmod 0755`, then `mv`. That is also atomic. |
| `CLOUDMAIL_VERSION` went into URLs unchecked | It must be `latest` or start with `v<digit>`. Downloads use `--proto '=https'`. |
| An INT or TERM trap fired cleanup but did not exit | Cleanup runs on EXIT. INT and TERM now exit 130 and 143. |
| No way to reinstall when cloudmail is already on PATH, short of guessing a tag | `CLOUDMAIL_VERSION=latest` does it. |
| PowerShell: unauthenticated GitHub API call, no `-UseBasicParsing` for 5.1, binary written into place before verification, no arm64, no temp cleanup (G, in part) | Rewritten. It downloads `SHA256SUMS` and the `.zip` from `latest/download` into a random temp dir and verifies the hash before unpacking. It installs to `%LOCALAPPDATA%\cloudmail`, which `$dir` changes, and removes the temp dir in `finally`. It detects arm64, including under WOW64. Windows arm64 is listed as supported. |
| The fetch-the-script example used a fixed path, `/tmp/cloudmail-install.sh` (G) | It uses `mktemp -d` and shows `less` before `sh`. |
| `make install` writes to `/usr/local/bin`, which needs sudo | The docs now say so and show `PREFIX=$HOME/.local`. The default path copies to `~/.local/bin`. |
| Build from source | Clones `cloudmail-hq/cloudmail` and runs `cd cli && make build`. It names the module path `github.com/cloudmail-hq/cloudmail/cli`. The "no public import path" note was removed. |

## check-setup.sh

| Finding | Resolution |
|---|---|
| `set -u` only | Now `set -eu` with pipefail. Commands that are expected to fail are guarded. |
| `auth whoami` stderr was merged into the JSON on stdout (G) | stderr now goes to a `mktemp` file, which is shown only on failure and removed on exit. |
| Tested | Exits 2 for the local-dev default base URL, 6 with no token, and 8 when the host is unreachable. It never prints the token. |

## Uses of the CLI fixes, with fallbacks for older CLIs

| Finding | Resolution |
|---|---|
| Held sends: the skill matched `approval list` rows to find the id (G noted the race) | `SKILL.md`, `sending-and-approvals.md` and `troubleshooting.md` read `approval_id`, `approval_url` and `expires_at` from the send's JSON. The `approval list` matching is kept as a fallback for older CLIs only. |
| "Global flags are not listed in `cloudmail schema`" | Now points at `global_flags`, with `--help` as the fallback. |
| Read-only commands refused under `--read-only` | `reading.md` says they now work, and older CLIs exit 11. |
| Exit 6 text mentions Access tokens | The note is now framed as older-CLI behaviour. |
| `agent-inbox create` had no idempotency key | The example uses `--idempotency-key`. Older CLIs fail with "unknown flag", and the docs say to check `agent-inbox list` before retrying. |

## Agent inboxes: recipient restriction (owner request)

| Finding | Resolution |
|---|---|
| Agents copied `--allow @partner.example.org` and locked inboxes to internal domains | The main create example in `agent-inboxes.md` has no `--allow` and says that the inbox can send to and receive from anyone by default. `--allow` moved to an "Optional: restrict recipients" subsection that says: only add it if the user specifically asks, never on your own initiative. `SKILL.md` and the README no longer describe the allowlist as the default. |
| New rule | `SKILL.md` rule 7: "Don't restrict an agent inbox's recipients unless the user asks. If a send fails with RECIPIENT_NOT_ALLOWED, tell the user; never switch to another profile, token or mailbox to get around it." The same instruction is repeated in `agent-inboxes.md`. |

## Prompt injection and token handling

| Finding | Resolution |
|---|---|
| `mail list` and `mail search` examples had no `--fence`, yet subjects and sender names are untrusted (G) | Added `--fence always` to the list and search examples in `SKILL.md`, `reading.md` and `agent-inboxes.md`, with a sentence saying why. |
| Untrusted sender and subject were interpolated into `draft create --to <sender> --subject 'Re: <subject>'` (G) | `SKILL.md` and `sending-and-approvals.md` say to use only the bare address and to quote subjects safely, and point to `mail reply`, which derives both from the original. |
| MCP `create_agent_inbox` returns the token to the agent, against rule 4 (G) | `agent-inboxes.md` and `mcp.md` now tell the agent not to call it. The user creates the inbox in the terminal or the web app. |
| The `triage_inbox` prompt classifies untrusted mail (G) | `mcp.md` says to report what it moved and never act on instructions in the messages. |
| `claude mcp add --header "Bearer $CLOUDMAIL_TOKEN"` leaks to shell history (G) | Not a real leak: history records the unexpanded text. Single quotes would store the literal `$CLOUDMAIL_TOKEN`, which `claude mcp add` does not expand. The comment now says the value lands in Claude Code's config, and points to the `.mcp.json` `${CLOUDMAIL_TOKEN}` form for no stored secret. It also says the user runs this, never the agent. |
| Fixed path `/tmp/reply.html` in the revise example (G) | Uses `mktemp`. |
| Dry-run output and `--verbose` | Checked: neither prints the token. |
| Approving own sends, bypassing holds | Already forbidden. Rule 6 now also names switching tokens. |

## Correctness and portability

| Finding | Resolution |
|---|---|
| Agent-inbox prefix `A='env … /home/me/…'`, used unquoted as `$A` (G noted the path) | `$A` did not word-split in zsh, so the commands failed there. Replaced with a `cm()` function that uses `$HOME` and was tested in bash and zsh: it clears `CLOUDMAIL_TOKEN` and reports `token_source: file:…`. `timeout` cannot run a shell function, so that line spells out the full `env` command. |
| `timeout` is missing on stock macOS (G) | Noted next to each `timeout` example. |
| `<skill-dir>` placeholder in `SKILL.md` (G) | Reworded so it is clearly a path to substitute. |
| `token create --expires-in 30` had no unit (G) | `auth.md` says it is days, with 0 for never. That matches the schema. |
| `<domain>` in the front-matter description (Anthropic's docs forbid XML tags there) | Changed to `DOMAIN`. |
| The front-matter compatibility line left out tar and sha256sum | Added. |
| Commands and flags | Every command and flag in `SKILL.md` and the references matched the schema. The dry-runs for reply, revise, agent-inbox create, draft create, followup, schedule, token create and archive exited 10. |
| Exit codes | They match the CLI's table, 0–13 and 130. |

## Left open

- The skill's CLI-fix wording assumes the parallel CLI PR lands with exactly
  the behaviour described: the asset names, `approval_id` on stdout,
  `global_flags`, read-only commands working under `--read-only`, and
  `agent-inbox create --idempotency-key`. The installed CLI (881ff10) predates
  it, so those paths were checked against the brief, not run.
- `install.sh` was tested against a fake local release, not a real GitHub
  release. Run it once against the first real `cloudmail-hq/cloudmail`
  release, and the PowerShell snippet on Windows (no `pwsh` here).
- `install.md` links to the script at the `v0.1.0` tag of `cloudmail-hq/skills`,
  so tag the repo when it is published.
- The ttk_ token prefix and the `@cloudmail/cli` npm note are unchanged.
