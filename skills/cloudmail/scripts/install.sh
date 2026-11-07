#!/bin/sh
# Install the cloudmail CLI from a GitHub release (macOS and Linux).
#
#   sh install.sh
#
# Environment:
#   CLOUDMAIL_VERSION      release tag to install, e.g. v0.3.0, or "latest" to
#                          reinstall the latest even if cloudmail is already on PATH
#                          (default: the latest release)
#   CLOUDMAIL_INSTALL_DIR  where to put the binary (default: ~/.local/bin)
#   CLOUDMAIL_REPO         owner/repo of the releases (default: cloudmail-hq/cloudmail)
#
# Downloads SHA256SUMS and the matching cloudmail_<version>_<os>_<arch>.tar.gz,
# refuses to install on a checksum mismatch, and never needs root unless you
# choose a root-owned directory. Needs curl, tar, and sha256sum or shasum.
set -eu
# pipefail is POSIX since 2024; older shells (dash < 0.5.12) lack it.
# shellcheck disable=SC3040
if (set -o pipefail) 2>/dev/null; then set -o pipefail; fi

repo="${CLOUDMAIL_REPO:-cloudmail-hq/cloudmail}"
dir="${CLOUDMAIL_INSTALL_DIR:-$HOME/.local/bin}"
version="${CLOUDMAIL_VERSION:-}"

say() { printf '%s\n' "$*" >&2; }
die() { say "install.sh: $*"; exit 1; }

if [ -z "$version" ] && command -v cloudmail >/dev/null 2>&1; then
	say "cloudmail is already installed: $(cloudmail --version 2>/dev/null || echo unknown)"
	say "set CLOUDMAIL_VERSION=latest (or vX.Y.Z) to install anyway"
	exit 0
fi

command -v curl >/dev/null 2>&1 || die "curl is required"
command -v tar >/dev/null 2>&1 || die "tar is required"
if command -v sha256sum >/dev/null 2>&1; then
	sha256() { sha256sum "$1" | awk '{ print $1 }'; }
elif command -v shasum >/dev/null 2>&1; then
	sha256() { shasum -a 256 "$1" | awk '{ print $1 }'; }
else
	die "sha256sum or shasum is required to verify the download"
fi

case "$(uname -s)" in
	Darwin) os=darwin ;;
	Linux) os=linux ;;
	*) die "unsupported OS $(uname -s); on Windows use the PowerShell steps in references/install.md" ;;
esac
case "$(uname -m)" in
	x86_64 | amd64) arch=amd64 ;;
	arm64 | aarch64) arch=arm64 ;;
	*) die "unsupported architecture $(uname -m); build from source (references/install.md)" ;;
esac

case "$version" in
	"" | latest) base="https://github.com/$repo/releases/latest/download" ;;
	v[0-9]*) base="https://github.com/$repo/releases/download/$version" ;;
	*) die "CLOUDMAIL_VERSION must be a tag like v0.3.0, or latest" ;;
esac

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

curl -fsSL --proto '=https' -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" ||
	die "no SHA256SUMS at $base; refusing to install an unverified binary (or build from source, references/install.md)"

# Take the archive name from SHA256SUMS, so the version in it never has to be
# guessed. The pattern is strict: the name is used in a URL and a file path.
# Tolerates CRLF line endings, "*name" (binary mode) and upper-case hex.
line=$(tr -d '\r' <"$tmp/SHA256SUMS" | awk -v os="$os" -v arch="$arch" '
	{ f = $2; sub(/^\*/, "", f) }
	f ~ ("^cloudmail_[0-9A-Za-z.+-]+_" os "_" arch "\\.tar\\.gz$") && $1 ~ /^[0-9A-Fa-f]+$/ && length($1) == 64 {
		print tolower($1), f; exit
	}')
[ -n "$line" ] || die "SHA256SUMS lists no cloudmail_<version>_${os}_${arch}.tar.gz"
want=${line%% *}
name=${line#* }

say "downloading $name"
curl -fsSL --proto '=https' -o "$tmp/$name" "$base/$name" || die "could not download $base/$name"

got=$(sha256 "$tmp/$name")
[ "$got" = "$want" ] || die "checksum mismatch for $name (expected $want, got $got); not installed"

mkdir "$tmp/x"
tar -xzf "$tmp/$name" -C "$tmp/x" || die "could not unpack $name"
bin="$tmp/x/cloudmail"
[ -f "$bin" ] || bin=$(find "$tmp/x" -type f -name cloudmail | head -n 1)
[ -n "$bin" ] && [ -f "$bin" ] || die "$name has no cloudmail binary"

mkdir -p "$dir"
# Copy beside the target, then rename, so a running cloudmail is never half-written.
cp "$bin" "$dir/.cloudmail.new.$$"
chmod 0755 "$dir/.cloudmail.new.$$"
mv -f "$dir/.cloudmail.new.$$" "$dir/cloudmail"
say "installed $dir/cloudmail ($("$dir/cloudmail" --version 2>/dev/null || echo "$name"))"

case ":$PATH:" in
	*":$dir:"*) ;;
	*) say "note: $dir is not on PATH; add: export PATH=\"$dir:\$PATH\"" ;;
esac
