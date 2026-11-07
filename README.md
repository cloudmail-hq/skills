# cloudmail skill

An [Agent Skill](https://agentskills.io) that teaches AI coding agents (Claude
Code, Codex, Cursor, Gemini CLI, GitHub Copilot and others) to work with **your
own cloudmail deployment**. cloudmail is a self-hosted, agent-first mailbox that
runs on your Cloudflare account.

With the skill installed, an agent can:

- read, search and summarise mail across your mailboxes;
- draft replies for you to review;
- reply, send and forward when you ask it to;
- handle held sends correctly: a `pending_approval` result is reported to you,
  not retried, and changed with `approval revise` instead of a second send;
- run a dedicated **agent inbox** that sends on its own, but only to the
  recipients you allow;
- treat every email as untrusted data, never as instructions.

It works through the `cloudmail` CLI or through your deployment's MCP server at
`https://<your-domain>/mcp`.

## What you need

- A cloudmail deployment, for example `https://mail.example.com`.
- The `cloudmail` CLI ([install guide](skills/cloudmail/references/install.md)),
  or an MCP client connected to `https://<your-domain>/mcp`.
- An API token from **Settings → Account & security → API tokens**, given to the
  agent through `CLOUDMAIL_TOKEN_FILE` or `CLOUDMAIL_TOKEN`. Never paste it into
  the chat.

## Install the skill

The skill is the folder [`skills/cloudmail/`](skills/cloudmail/). Every agent
below loads it from a `skills/` directory.

### Any agent, with the `skills` installer

```bash
npx skills add tapetide-com/cloudmail-skill
```

[`skills`](https://github.com/vercel-labs/skills) detects the agents you have
and copies the skill into each one's skills folder.

### Claude Code

As a plugin, which also gets updates:

```text
/plugin marketplace add tapetide-com/cloudmail-skill
/plugin install cloudmail@tapetide-cloudmail
```

Or copy the folder by hand:

```bash
git clone https://github.com/tapetide-com/cloudmail-skill.git
mkdir -p ~/.claude/skills
cp -R cloudmail-skill/skills/cloudmail ~/.claude/skills/
```

Use `.claude/skills/` inside a project to share it with your team.

### Codex, Cursor, Gemini CLI, GitHub Copilot

All of these read `~/.agents/skills/` (user) and `.agents/skills/` (project):

```bash
mkdir -p ~/.agents/skills
cp -R cloudmail-skill/skills/cloudmail ~/.agents/skills/
```

Each tool also has its own folder, if you prefer it:

| Agent | User folder | Project folder |
|---|---|---|
| Codex | `~/.agents/skills` | `.agents/skills` |
| Cursor | `~/.cursor/skills` | `.cursor/skills` |
| Gemini CLI | `~/.gemini/skills` | `.gemini/skills` |
| GitHub Copilot | `~/.copilot/skills` | `.github/skills` |

Gemini CLI can also install it directly:
`gemini skills install https://github.com/tapetide-com/cloudmail-skill --path skills/cloudmail`.

### Other agents

Agents without skill support can still use it: point them at
[`skills/cloudmail/SKILL.md`](skills/cloudmail/SKILL.md) as instructions, for
example from `AGENTS.md`.

## Set up the CLI

```bash
cloudmail --version                       # install if missing
cloudmail config set base-url https://mail.example.com
export CLOUDMAIL_TOKEN_FILE=~/.config/cloudmail/token   # a chmod 600 file you created
cloudmail auth whoami
```

`skills/cloudmail/scripts/check-setup.sh` checks each step and says what is
missing.

## Examples

Ask your agent:

- "What's unread in support@example.com? Group it by what needs a reply."
- "Find the invoice from Acme last month across all my mailboxes."
- "Draft a reply to Bob's last email saying we'll ship Friday. Don't send it."
- "Reply to that thread and send it." In a mailbox that holds agent sends, the
  agent tells you the reply is waiting in Pending approval.
- "Change the held reply to say Thursday instead." The agent runs
  `approval revise`.
- "Create an agent inbox that can email @partner.example.org for 3 days, ask
  them for a quote, and tell me when they answer."

## Safety model

The skill tells the agent to read by default and to ask before it sends. The
real limits are enforced by your deployment, not by the skill:

- Token scopes and per-mailbox grants cap what a token can do.
- Agent sends from a person's mailbox are held for approval by default.
- An agent cannot approve its own sends.
- Agent inboxes can only send to their `allowed_recipients`.

## Contents

```
skills/cloudmail/
  SKILL.md                        the instructions agents load
  references/                     loaded on demand
    install.md  auth.md  reading.md  sending-and-approvals.md
    agent-inboxes.md  mcp.md  troubleshooting.md
  scripts/
    install.sh                    installs the CLI from a release, checksum-verified
    check-setup.sh                read-only setup check
.claude-plugin/                   Claude Code plugin and marketplace manifests
```

## Licence

Apache-2.0. See [LICENSE](LICENSE).
