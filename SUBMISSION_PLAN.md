# Submission plan for the cloudmail skill

Status: **nothing has been published.** Every step below needs the owner's
approval. Venue facts were checked on 2026-11-07. Entries marked *unverified*
come from secondary sources and need checking before you submit.

## Prerequisites (do these first, in order)

1. **Publish the CLI.** Make `tapetide-com/cloudmail` public with a GitHub
   release whose assets match what the skill expects:
   `cloudmail-<tag>-<os>-<arch>[.exe]` plus a `SHA256SUMS` file. `make release`
   builds the binaries. It does not yet write `SHA256SUMS`; generate it with
   `cd dist && shasum -a 256 cloudmail-* > SHA256SUMS`. Without this release,
   the skill's install section only has the build-from-source path.
2. **Make this repo public** as `tapetide-com/cloudmail-skill`. The README, the
   plugin marketplace commands and `npx skills add` all assume that name.
3. Run `claude plugin validate --strict .` and fix anything new.
4. Optionally, run `skills-ref validate skills/cloudmail` from
   github.com/agentskills/agentskills.
5. Wait at least a week, and gather some stars and installs. Several lists
   require both.

## Skill and plugin venues

| Venue | URL | How to submit | Requirements | Qualify? |
|---|---|---|---|---|
| Own Claude Code marketplace | github.com/tapetide-com/cloudmail-skill | Nothing to submit. Users run `/plugin marketplace add tapetide-com/cloudmail-skill`. | `.claude-plugin/marketplace.json` (included). The name `tapetide-cloudmail` must not collide with reserved names. | **Yes**, as soon as the repo is public |
| skills.sh (Vercel `skills` CLI) | https://skills.sh | No form. It is listed automatically from install telemetry once people run `npx skills add tapetide-com/cloudmail-skill`. | Public repo with a valid `SKILL.md` | **Yes**, automatic |
| Anthropic plugin directory (claude.ai, Cowork, Claude Code) | https://claude.ai/directory, portal https://claude.ai/directory/manage | Developer portal form, then Anthropic reviews each version | Public GitHub repo, paid claude.ai plan, `claude plugin validate --strict` clean, README of 40+ words, square PNG icon (included), safety and policy review | **Yes**. The best single listing. |
| `anthropics/claude-plugins-official` | https://github.com/anthropics/claude-plugins-official | The repo README points to https://clau.de/plugin-directory-submission; the Claude Code docs say it is partner-only. Outside PRs are closed. | Curated | **Maybe**. Partner or invite route. |
| `anthropics/skills` | https://github.com/anthropics/skills | No contribution process documented | Anthropic's own catalogue | **No** |
| skillsmp.com | https://skillsmp.com | Automatic crawl of public GitHub repos (*unverified*; the site blocked our fetch) | Reportedly 2+ stars | **Likely**, after stars |
| claude-plugins.dev, skillhub.club | https://claude-plugins.dev, https://skillhub.club | Automatic indexing of public repos (*unverified*) | Public repo | **Likely** |
| ComposioHQ/awesome-claude-skills | https://github.com/ComposioHQ/awesome-claude-skills | PR titled "Add cloudmail skill", adding the folder and a README entry | Solves a real problem, confirms before destructive actions, tested on Claude | **Yes** |
| travisvn/awesome-claude-skills | https://github.com/travisvn/awesome-claude-skills | PR with one table row | 10+ stars. AI-written or AI-submitted PRs are closed. Rejects SaaS wrappers and promotional funnels. | **Not yet.** A human must write and file it after 10 stars, and argue that a self-hosted open-source product is not a funnel. |
| VoltAgent/awesome-agent-skills | https://github.com/VoltAgent/awesome-agent-skills | PR titled `Add skill: tapetide-com/cloudmail` | Description of 10 words or fewer, "real community usage" | **Later**, once there is usage |
| hesreallyhim/awesome-claude-code | https://github.com/hesreallyhim/awesome-claude-code | Issue form only, filed by a human (*unverified*) | Public for 1+ week | **Yes**, after a week |
| OpenAI Codex plugin directory | https://github.com/openai/plugins (`openai/skills` is deprecated) | A Codex plugin (`.codex-plugin/plugin.json`) submitted through the shared ChatGPT/Codex plugin directory. The submission page was not read (*unverified*). | Plugin manifest not yet in this repo | **Maybe**. Add a `.codex-plugin/` manifest first. Users can already copy the skill into `~/.agents/skills`. |
| Cursor Marketplace | https://cursor.com/marketplace | Publisher application, then a manual review of each plugin (*unverified*) | Open-source code | **Maybe** |
| cursor.directory | https://cursor.directory | Submit the GitHub repo in its "Agent Plugins" format (*unverified*) | | **Maybe** |
| agentskills.io | https://agentskills.io | Spec site only, no directory | — | n/a |

## MCP venues (for `https://<domain>/mcp`)

cloudmail has no single hosted MCP URL: each customer's server lives on their
own domain. Directories built around one public URL fit poorly, so list the
**project** (the GitHub repo) wherever that is allowed.

| Venue | URL | How to submit | Requirements | Qualify? |
|---|---|---|---|---|
| Official MCP Registry | https://registry.modelcontextprotocol.io | `mcp-publisher init`, then `mcp-publisher login github` (namespace `io.github.tapetide-com/…`) or `login dns` (`com.tapetide/…`), then `mcp-publisher publish` | `server.json`; `description` ≤ 100 chars; versions are immutable; the registry is still in preview. Remote URLs may use `{var}` templates with a `variables` block. | **Maybe, leaning yes.** Use `"url": "https://{domain}/mcp"` with a required `domain` variable. The schema allows it, but no example templates the whole host, and some clients only recently started honouring variables (VS Code 1.139). Test with a client before announcing. |
| Glama | https://glama.ai/mcp | Imports from the official registry or from the GitHub repo; claim with `glama.json` or a DNS check | HTTPS | **Yes**, through the registry or the repo |
| PulseMCP | https://pulsemcp.com | Direct submissions paused; it imports from the official registry | — | Indirectly, via the registry |
| GitHub MCP Registry | github/github-mcp-server discussion #1257 | Publish to the official registry, then post an onboarding request (*unverified*) | Public repo, licence | **Maybe** |
| mcp.so | https://mcp.so/submit | Form with the repo URL; reviewed before it goes live. A $39 fee is reported (*unverified*). | | **Yes**, with the repo URL |
| Smithery | https://smithery.ai | Smithery shut down its hosting, CLI and API on 2026-10-31 and is now a directory run by Arcade.dev. The new listing process is unclear. | One public MCP URL | **Unclear, poor fit** |
| punkpeye/awesome-mcp-servers | https://github.com/punkpeye/awesome-mcp-servers | One-line PR. Remote-only servers go to its sister list. CI wants a Glama listing first. | | **Maybe**, after Glama |
| MCP Market | https://mcpmarket.com/submit | Free queue (4–6 weeks) or $29 for a 24-hour listing (*unverified*) | | **Yes** |
| LobeHub MCP Marketplace | https://lobehub.com/mcp | Submit link; no requirements stated (*unverified*) | | **Maybe** |

## Suggested order

1. Prerequisites 1–3: the CLI release and both repos made public.
2. Launch day: own marketplace (automatic), skills.sh (automatic once
   installed), and the **Anthropic plugin directory** submission.
3. Same week: official MCP Registry (test the `{domain}` template first), then
   Glama, mcp.so and MCP Market.
4. After about a week and 10+ stars: ComposioHQ, hesreallyhim (issue by a
   human), travisvn (PR by a human), punkpeye.
5. Later: a Codex plugin manifest and the OpenAI directory, the Cursor
   Marketplace, VoltAgent once there is usage.

## Open questions for the owner

- Which GitHub org and repo name to use. The plan assumes `tapetide-com`.
- Whether to pay for mcp.so and MCP Market listings.
- Whether the MCP Registry namespace should be `com.tapetide` (DNS proof) or
  `io.github.tapetide-com`.
- Whether `make release` should also write `SHA256SUMS`. Right now
  `scripts/install.sh` refuses to install without it.
