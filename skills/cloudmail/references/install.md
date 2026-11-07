# Installing the cloudmail CLI

## 1. Check first

```bash
cloudmail --version
```

If it prints a version (a release tag such as `cloudmail v0.3.0`, or a commit
hash for a source build), check that it has the commands this skill uses:

```bash
cloudmail schema approval revise >/dev/null && cloudmail schema agent-inbox create >/dev/null && echo ok
```

If that prints `ok`, skip to [auth.md](auth.md). If not, the CLI is too old, so
upgrade it with one of the options below.

Ask the user before installing software on their machine.

## 2. Release binary (recommended)

Releases are published at <https://github.com/cloudmail-hq/cloudmail/releases>
for:

| OS | amd64 | arm64 |
|---|---|---|
| macOS (darwin) | yes | yes |
| Linux | yes | yes |
| Windows | yes | yes |

Each release has one archive per platform, named
`cloudmail_<version>_<os>_<arch>.tar.gz` (`.zip` on Windows), and a
`SHA256SUMS` file listing their checksums. `<version>` has no leading `v`, for
example `cloudmail_0.3.0_linux_amd64.tar.gz`.

### macOS and Linux

The bundled script picks the OS and architecture, downloads the latest release
and `SHA256SUMS`, refuses to install on a checksum mismatch, and installs to
`~/.local/bin` without `sudo` (override with `CLOUDMAIL_INSTALL_DIR`):

```bash
sh scripts/install.sh            # from this skill's folder
```

Or, without the skill checkout, fetch the script from a tagged release of this
skill into a private temporary folder. Read it before running it:

```bash
d=$(mktemp -d)
curl -fsSLo "$d/install.sh" \
  https://raw.githubusercontent.com/cloudmail-hq/skills/v0.1.0/skills/cloudmail/scripts/install.sh
less "$d/install.sh"
sh "$d/install.sh"; rm -rf "$d"
```

To pin a version, set `CLOUDMAIL_VERSION=v0.3.0`. To reinstall when
`cloudmail` is already on `PATH`, set `CLOUDMAIL_VERSION=latest`.

If `~/.local/bin` is not on `PATH`, add it, for example
`export PATH="$HOME/.local/bin:$PATH"` in `~/.zshrc` or `~/.bashrc`.

### Windows (PowerShell)

Works in Windows PowerShell 5.1 and PowerShell 7. It installs to
`%LOCALAPPDATA%\cloudmail` without administrator rights; change `$dir` to put
it elsewhere.

```powershell
$ErrorActionPreference = "Stop"
$base = "https://github.com/cloudmail-hq/cloudmail/releases/latest/download"
$cpu  = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = if ($cpu -eq "ARM64") { "arm64" } else { "amd64" }
$dir  = Join-Path $env:LOCALAPPDATA "cloudmail"
$tmp  = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force $tmp, $dir | Out-Null
try {
  Invoke-WebRequest -UseBasicParsing "$base/SHA256SUMS" -OutFile "$tmp\SHA256SUMS"
  $line = Get-Content "$tmp\SHA256SUMS" |
    Where-Object { $_ -match "^([0-9A-Fa-f]{64}) [ *](cloudmail_[0-9A-Za-z.+-]+_windows_${arch}\.zip)\s*$" } |
    Select-Object -First 1
  if (-not $line) { throw "SHA256SUMS lists no windows_$arch archive" }
  $null = $line -match "^([0-9A-Fa-f]{64}) [ *](\S+)"
  $want = $Matches[1].ToLower(); $name = $Matches[2]
  Invoke-WebRequest -UseBasicParsing "$base/$name" -OutFile "$tmp\$name"
  $got = (Get-FileHash "$tmp\$name" -Algorithm SHA256).Hash.ToLower()
  if ($got -ne $want) { throw "checksum mismatch for $name; not installed" }
  Expand-Archive "$tmp\$name" -DestinationPath "$tmp\x"
  $exe = Get-ChildItem "$tmp\x" -Recurse -Filter cloudmail.exe | Select-Object -First 1
  if (-not $exe) { throw "$name has no cloudmail.exe" }
  Copy-Item $exe.FullName "$dir\cloudmail.exe" -Force
  "Installed $dir\cloudmail.exe"
} finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
```

If `cloudmail` is not found afterwards, add `$dir` to the user `PATH`
(**Settings → System → About → Advanced system settings → Environment
Variables**), then open a new terminal.

### Checking a download by hand

```bash
shasum -a 256 cloudmail_0.3.0_darwin_arm64.tar.gz     # macOS
sha256sum cloudmail_0.3.0_linux_amd64.tar.gz          # Linux
```

```powershell
(Get-FileHash cloudmail_0.3.0_windows_amd64.zip -Algorithm SHA256).Hash   # Windows
```

Compare the result with the matching line in the release's `SHA256SUMS`. If
they differ, delete the file and do not run it.

## 3. Build from source

Use this when no release fits, or when the user prefers to build. It needs Go
1.27 or later, git and make. The CLI is the Go module
`github.com/cloudmail-hq/cloudmail/cli`, in the `cli/` folder of the cloudmail
repository:

```bash
git clone https://github.com/cloudmail-hq/cloudmail.git
cd cloudmail/cli
make build                      # writes ./bin/cloudmail, stamped with the version
mkdir -p ~/.local/bin
cp bin/cloudmail ~/.local/bin/cloudmail
```

`make install` installs to `/usr/local/bin` instead, which usually needs
`sudo`; `make install PREFIX=$HOME/.local` avoids that. A plain
`go build -o cloudmail .` inside `cli/` also works, without the version stamp.

## 4. npm (planned)

An npm wrapper, `@cloudmail/cli`, that downloads the matching release binary is
planned but not published. Don't try `npm install @cloudmail/cli` until the
project announces it.

## After installing

```bash
cloudmail --version
cloudmail guide          # a short orientation written for programs
```

Then configure the deployment and token: [auth.md](auth.md).
