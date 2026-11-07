#!/bin/sh
# Check that the cloudmail CLI is installed, configured and authenticated.
# Read-only: it runs only `--version`, `auth status` and `auth whoami`, and it
# never prints the token.
#
#   sh check-setup.sh [--profile NAME]
#
# Exit 0 when everything is ready. Otherwise: 127 CLI missing, 2 no deployment
# configured, 6 no token or token rejected, 8 deployment unreachable, or the
# exit code of `auth whoami`.
set -eu
# pipefail is POSIX since 2024; older shells (dash < 0.5.12) lack it.
# shellcheck disable=SC3040
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi

say() { printf '%s\n' "$*" >&2; }
# field NAME: the value of "NAME": ... in the JSON on stdin (string, bool or
# number). Uses jq when installed; otherwise a whitespace-tolerant sed.
field() {
	if command -v jq >/dev/null 2>&1; then
		jq -r --arg k "$1" '.[$k] // empty | tostring' 2>/dev/null || true
	else
		tr ',' '\n' | sed -n "s/^[[:space:]{]*\"$1\"[[:space:]]*:[[:space:]]*\"\{0,1\}\([^\"}]*\)\"\{0,1\}[[:space:]}]*$/\1/p" | head -n 1 || true
	fi
}

if ! command -v cloudmail >/dev/null 2>&1; then
	say "FAIL cloudmail is not installed (or not on PATH)."
	say "     Install it: references/install.md, or sh scripts/install.sh"
	exit 127
fi
say "ok   $(cloudmail --version 2>/dev/null || echo 'version unknown')"

# auth status reports configuration and reachability as JSON. It exits non-zero
# when the deployment cannot be reached, so read its fields, not its exit code.
status=$(cloudmail --read-only --output json "$@" auth status 2>/dev/null) || true
if [ -z "$status" ]; then
	say "FAIL could not read \`cloudmail auth status\`; run it by hand to see why."
	exit 1
fi
base=$(printf '%s\n' "$status" | field base_url)
token=$(printf '%s\n' "$status" | field token_present)
source=$(printf '%s\n' "$status" | field token_source)
reachable=$(printf '%s\n' "$status" | field reachable)

case "$base" in
	"" | http://localhost:5173)
		say "FAIL no deployment configured (base URL is '${base:-unset}', the CLI's local-dev default)."
		say "     Ask the user for their cloudmail address, then:"
		say "     cloudmail config set base-url https://mail.example.com"
		exit 2
		;;
esac
say "ok   deployment: $base"

if [ "$token" != "true" ]; then
	say "FAIL no API token found."
	say "     Ask the user to create one at Settings -> Account & security -> API tokens"
	say "     and provide it with CLOUDMAIL_TOKEN_FILE=<path>, CLOUDMAIL_TOKEN in the"
	say "     environment, or: cloudmail auth login --with-token < <file>"
	exit 6
fi
# token_source is "env", "file:<path>" or similar; it never contains the token.
say "ok   token found (${source:-stored credentials})"

if [ "$reachable" != "true" ]; then
	say "FAIL cannot reach $base: check the address and the network."
	exit 8
fi

# Keep stdout (the JSON) and stderr (the error envelope) apart.
errf=$(mktemp)
trap 'rm -f "$errf"' EXIT
code=0
out=$(cloudmail --read-only --output json "$@" auth whoami 2>"$errf") || code=$?
case $code in
	0) say "ok   authenticated"; printf '%s\n' "$out"; exit 0 ;;
	6) say "FAIL the deployment rejected the token (401): missing, revoked, expired, or for another deployment." ;;
	4) say "FAIL authenticated but denied: the token lacks the scope for this call." ;;
	8) say "FAIL cannot reach $base: check the address and the network." ;;
	*) say "FAIL auth whoami exited $code." ;;
esac
cat "$errf" >&2
exit "$code"
