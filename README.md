# Corebrum for Omarchy

Run [Corebrum](https://corebrum.com) on [Omarchy](https://omarchy.org) and make
it feel native: app launchers, a status icon in the bar, and a Corebrum
submenu in the Omarchy menu.

1. [Install Corebrum](#1-install-corebrum) and its Zenoh router
2. [Sign in](#2-sign-in)
3. [Install the Omarchy integration](#3-install-the-omarchy-integration)
4. [Confirm the mesh sees this machine](#4-confirm-the-mesh-sees-this-machine)

Tested with Corebrum 0.3.10 and Zenoh 1.10.1 on Omarchy (x86_64, glibc 2.44).

## 1. Install Corebrum

Omarchy is Arch, so skip the APT instructions in the Corebrum README and
install the Linux release archive plus a matching Zenoh router. There is no
Zenoh router package in the Arch repos (AUR's `zenoh-c` and `zenoh-cpp` are
libraries, not the router). Corebrum 0.3.10 talks to Zenoh 1.10.1.

Omarchy already ships `unzip`, `python`, `jq`, and `herdr`. The one missing
piece is pip, which Python workers use to install a task's own packages
(`COREBRUM_AUTO_INSTALL_DEPS` defaults to true). Arch Python is externally
managed, so install pip from pacman, not with `ensurepip` or `pip install --user`:

```bash
sudo pacman -S --needed python-pip
```

Download and install Corebrum and zenohd into `~/.local`. `uname -m` picks the
`x86_64` or `aarch64` build:

```bash
COREBRUM_VERSION=0.3.10
ZENOH_VERSION=1.10.1
ARCH=$(uname -m)
DL=$(mktemp -d)

mkdir -p ~/.local/bin ~/.local/lib/corebrum

curl -fL -o "$DL/corebrum.tar.xz" \
  "https://corebrum-releases.s3.amazonaws.com/releases/v${COREBRUM_VERSION}/corebrum-${ARCH}-unknown-linux-gnu.tar.xz"
sha256sum "$DL/corebrum.tar.xz"   # compare with the table below
tar -xJf "$DL/corebrum.tar.xz" -C ~/.local/lib/corebrum --strip-components=1
ln -sfn ~/.local/lib/corebrum/corebrum ~/.local/bin/corebrum

curl -fL -o "$DL/zenoh.zip" \
  "https://github.com/eclipse-zenoh/zenoh/releases/download/${ZENOH_VERSION}/zenoh-${ZENOH_VERSION}-${ARCH}-unknown-linux-gnu-standalone.zip"
unzip -o "$DL/zenoh.zip" -d "$DL/zenoh"
install -m 755 "$DL/zenoh/zenohd" ~/.local/bin/zenohd
install -m 755 "$DL"/zenoh/libzenoh_plugin_{rest,storage_manager}.so ~/.local/bin/
```

| Corebrum 0.3.10 archive | sha256 |
|---|---|
| `x86_64` | `d046e5329de47912ca0230b00c534d71d2c4439cdbdb71fe4209270ea6d8c1d2` |
| `aarch64` | `1978da5f021fd5b061a712db503c978dfd6a7eaf71faee2448ecdbab489e0164` |

> The `.sha256` files published next to the archives on S3 currently do not
> match the archives (for 0.3.9 as well), so compare against this table instead.

If you have access to the private repo and are logged in with `gh`, this is the
same archive:

```bash
gh release download --repo Corebrum/corebrum --pattern "corebrum-${ARCH}-unknown-linux-gnu.tar.xz"
```

Why the layout matters:

- The archive has a `corebrum` binary and a `dist/` folder (the web UI) beside
  it. The UI is found next to the **real** binary, not the symlink, so keep
  both in `~/.local/lib/corebrum` and only symlink the binary.
- `zenohd` loads plugins from the directory of its real binary first. Copy the
  REST and storage-manager `.so` files next to it. A plain router does not need
  them to start, but they cannot load from anywhere else.

`~/.local/bin` is already on Omarchy's PATH. Check:

```bash
corebrum --version   # corebrum 0.3.10
zenohd --version     # zenohd v1.10.1
python3 --version
```

## 2. Sign in

```bash
corebrum auth login
corebrum auth status
corebrum license sync
```

`auth login` opens https://corebrum.com in the browser and waits up to five
minutes for the callback. The token goes in the system keyring. If login
reaches the browser but then fails with a keyring or Secret Service error, the
session has no keyring daemon yet:

```bash
sudo pacman -S --needed gnome-keyring libsecret
gnome-keyring-daemon --start --components=secrets
```

Then run `corebrum auth login` again in that same terminal.

## 3. Install the Omarchy integration

```bash
git clone git@github.com:Corebrum/corebrum-omarchy.git
cd corebrum-omarchy
./install.sh     # install or update (safe to re-run)
./uninstall.sh   # remove everything except corebrum-up and Corebrum itself
```

Then start the mesh any of these ways:

- Left-click the brain icon in the bar
- **Corebrum** in the app launcher (`Super+Space`)
- **Corebrum → Start Mesh** in the Omarchy menu
- `corebrum-up` in a terminal

`corebrum-up` runs the router, the daemon, and the web UI as three panes
(`zenoh`, `daemon`, `web`) in a Herdr session named `corebrum`, separate from
your default Herdr session. It waits for each part to report ready, and will
not start a second copy or start when ports 7447 / 6502 are taken. Once the web
UI is serving it opens it as a **Corebrum Web** app window. Detach with
`Ctrl+Space` then `d`; the mesh keeps running. `corebrum-up stop` ends it and closes the Corebrum Web window.

### What gets installed

| Piece | Location | Source here |
|---|---|---|
| Mesh launcher script | `~/.local/bin/corebrum-up` | `bin/corebrum-up` |
| "Corebrum" app (start / open session) | `~/.local/share/applications/corebrum.desktop` | generated by `install.sh` |
| "Corebrum Web" app (web UI on `127.0.0.1:6502`) | `~/.local/share/applications/Corebrum Web.desktop` | `omarchy webapp install` |
| Icon | `~/.local/share/icons/hicolor/256x256/apps/corebrum.png` | Corebrum's `dist/corebrum-transparent.png` |
| Bar widget `corebrum.mesh` | `~/.config/omarchy/plugins/corebrum.mesh/` | `plugin/corebrum.mesh/` |
| Omarchy menu entries | `~/.config/omarchy/extensions/omarchy-menu.jsonc` | `menu/corebrum-menu.jsonc` |

### Bar icon

The brain icon is lit when zenohd (port 7447), the daemon, and the web UI
(port 6502) are all up, and dimmed when everything is stopped. Hover for details.

- **Left-click**: start the mesh when it is down, stop it when any part is up
- **Right-click**: Corebrum menu (Start / Open Session / Open Web UI / Stop)

Change the check interval with `omarchy bar set corebrum.mesh refreshIntervalSec 10`.
Force an update with `omarchy-shell corebrum.mesh refresh`.

## 4. Confirm the mesh sees this machine

With the mesh running:

```bash
corebrum compute-stats
```

This machine should show up with one worker per core. The daemon pins each
Python worker to a core; look for `pinned to CPU` in the `daemon` pane. The web
UI is at http://127.0.0.1:6502 (or **Corebrum Web** in the app launcher).
`corebrum cmos` opens the interactive shell.

### Without Herdr

To run the parts by hand, use three terminals. Zenoh's listen address uses a
slash; Corebrum's connect address uses `://`.

```bash
zenohd -l tcp/127.0.0.1:7447                                              # ready: "Zenoh can be reached at: tcp/127.0.0.1:7447"
corebrum daemon --zenoh-router tcp://127.0.0.1:7447 --capabilities python
corebrum web --zenoh-router tcp://127.0.0.1:7447                          # ready: "Serving React app from: .../dist"
```

Closing those terminals stops the mesh.

## Notes

- `corebrum-up` opens its terminal with app id `org.corebrum.mesh`. A plain
  `corebrum` id made Omarchy's launch-or-focus match any window with
  "Corebrum" in its title (e.g. a browser tab) instead of launching.
- If the `corebrum` Herdr session is already open in any terminal,
  `corebrum-up` focuses that window instead of opening a second one.
- Third-party bar plugins get a reduced bar API: `bar.run()` exists but
  `bar.shellQuote()` does not.
- After editing the plugin's QML, run `omarchy restart shell`; hot reload
  sometimes keeps the old code running.
