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

Release binaries are published at
<https://github.com/tapetide-com/cloudmail/releases> for:

| OS | amd64 | arm64 |
|---|---|---|
| macOS (darwin) | yes | yes |
| Linux | yes | yes |
| Windows | yes | not yet |

Each release asset is a single binary named
`cloudmail-<version>-<os>-<arch>` (with `.exe` on Windows), plus a
`SHA256SUMS` file listing their checksums.

### macOS and Linux

The bundled script picks the OS and architecture, downloads the latest release,
checks it against `SHA256SUMS`, and installs to `~/.local/bin` (override with
`CLOUDMAIL_INSTALL_DIR`):

```bash
sh scripts/install.sh            # from this skill's folder
```

Or, without the skill checkout, fetch the script from a tagged release of this
skill. Read it before running it:

```bash
curl -fsSLo /tmp/cloudmail-install.sh \
  https://raw.githubusercontent.com/tapetide-com/cloudmail-skill/v0.1.0/skills/cloudmail/scripts/install.sh
sh /tmp/cloudmail-install.sh
```

To pin a version, set `CLOUDMAIL_VERSION=v0.3.0` before running it.

If `~/.local/bin` is not on `PATH`, add it, for example
`export PATH="$HOME/.local/bin:$PATH"` in `~/.zshrc` or `~/.bashrc`.

### Windows (PowerShell)

```powershell
$repo = "tapetide-com/cloudmail"
$tag  = (Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest").tag_name
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$name = "cloudmail-$tag-windows-$arch.exe"
$base = "https://github.com/$repo/releases/download/$tag"
$dir  = "$env:LOCALAPPDATA\cloudmail"; New-Item -ItemType Directory -Force $dir | Out-Null
Invoke-WebRequest "$base/$name" -OutFile "$dir\cloudmail.exe"
$want = ((Invoke-WebRequest "$base/SHA256SUMS").Content -split "`n" | Where-Object { $_ -match [regex]::Escape($name) }) -split '\s+' | Select-Object -First 1
$got  = (Get-FileHash "$dir\cloudmail.exe" -Algorithm SHA256).Hash.ToLower()
if ($got -ne $want) { Remove-Item "$dir\cloudmail.exe"; throw "checksum mismatch for $name" }
"Installed $dir\cloudmail.exe; add $dir to PATH"
```

Windows on ARM can run the amd64 build under emulation until an arm64 build is
published.

### Checking a download by hand

```bash
shasum -a 256 cloudmail-v0.3.0-darwin-arm64     # macOS
sha256sum cloudmail-v0.3.0-linux-amd64          # Linux
```

Compare the result with the matching line in the release's `SHA256SUMS`. If
they differ, delete the file and do not run it.

## 3. Build from source

Use this when no release fits, or when the user prefers to build. It needs Go
1.27 or later and git. The CLI lives in the `cli/` folder of the cloudmail
repository:

```bash
git clone https://github.com/tapetide-com/cloudmail.git
cd cloudmail/cli
make build                      # writes ./bin/cloudmail, stamped with the version
install -m 0755 bin/cloudmail ~/.local/bin/cloudmail
```

`make install` installs to `/usr/local/bin` instead (`PREFIX=` changes it).
A plain `go build -o cloudmail .` inside `cli/` also works.

`go install …@latest` is not supported: the module is not published at a
public Go import path.

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
