#!/bin/sh
# Install the cloudmail CLI from the latest GitHub release (macOS and Linux).
#
#   sh install.sh
#
# Environment:
#   CLOUDMAIL_VERSION      tag to install, e.g. v0.3.0 (default: latest release)
#   CLOUDMAIL_INSTALL_DIR  where to put the binary (default: ~/.local/bin)
#   CLOUDMAIL_REPO         owner/repo of the releases (default: tapetide-com/cloudmail)
#
# Downloads one binary and SHA256SUMS, refuses to install on a checksum mismatch,
# and never needs root unless you choose a root-owned directory.
set -eu

repo="${CLOUDMAIL_REPO:-tapetide-com/cloudmail}"
dir="${CLOUDMAIL_INSTALL_DIR:-$HOME/.local/bin}"
version="${CLOUDMAIL_VERSION:-}"

say() { printf '%s\n' "$*" >&2; }
die() { say "install.sh: $*"; exit 1; }

if command -v cloudmail >/dev/null 2>&1 && [ -z "$version" ]; then
	say "cloudmail is already installed: $(cloudmail --version 2>/dev/null || echo unknown)"
	say "set CLOUDMAIL_VERSION=vX.Y.Z to install a specific version anyway"
	exit 0
fi

command -v curl >/dev/null 2>&1 || die "curl is required"

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

if [ -z "$version" ]; then
	# The redirect target of /releases/latest ends in the tag; no API token needed.
	url=$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest") ||
		die "could not reach https://github.com/$repo/releases"
	version="${url##*/}"
	case "$version" in
		v*) ;;
		*) die "no published release found at https://github.com/$repo/releases; build from source (references/install.md)" ;;
	esac
fi

name="cloudmail-$version-$os-$arch"
base="https://github.com/$repo/releases/download/$version"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT INT TERM

say "downloading $name"
curl -fsSL -o "$tmp/$name" "$base/$name" || die "no asset $name in release $version"
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || die "release $version has no SHA256SUMS; refusing to install an unverified binary"

want=$(awk -v n="$name" '{ f = $2; sub(/^\*/, "", f); if (f == n) print $1 }' "$tmp/SHA256SUMS")
[ -n "$want" ] || die "SHA256SUMS has no entry for $name"
if command -v sha256sum >/dev/null 2>&1; then
	got=$(sha256sum "$tmp/$name" | awk '{print $1}')
else
	got=$(shasum -a 256 "$tmp/$name" | awk '{print $1}')
fi
[ "$got" = "$want" ] || die "checksum mismatch for $name (expected $want, got $got); not installed"

mkdir -p "$dir"
install -m 0755 "$tmp/$name" "$dir/cloudmail"
say "installed $dir/cloudmail ($("$dir/cloudmail" --version 2>/dev/null || echo "$version"))"

case ":$PATH:" in
	*":$dir:"*) ;;
	*) say "note: $dir is not on PATH; add: export PATH=\"$dir:\$PATH\"" ;;
esac
