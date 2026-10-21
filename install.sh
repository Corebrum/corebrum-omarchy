#!/usr/bin/env bash
# Install the Corebrum Omarchy integration:
#   - corebrum-up into ~/.local/bin (the previous copy is backed up)
#   - "Corebrum" and "Corebrum Web" app launcher entries with the Corebrum icon
#   - the corebrum.mesh bar widget (left = start/stop, right = Corebrum menu)
#   - a "Corebrum" submenu in the Omarchy menu
# Safe to re-run: every step replaces what an earlier run installed.
set -euo pipefail

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="${HOME}/.local/bin"
APPS="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"
ICON_SRC="${HOME}/.local/lib/corebrum/dist/corebrum-transparent.png"
PLUGIN_ID=corebrum.mesh
PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
MENU="${HOME}/.config/omarchy/extensions/omarchy-menu.jsonc"
WEB_URL=http://127.0.0.1:6502

step() { printf '\e[32m==>\e[0m %s\n' "$*"; }

command -v omarchy >/dev/null || { echo "omarchy is not installed." >&2; exit 1; }
[[ -x "${BIN}/corebrum" && -x "${BIN}/zenohd" ]] || {
  echo "Expected ${BIN}/corebrum and ${BIN}/zenohd. Install Corebrum first." >&2
  exit 1
}

step "Installing corebrum-up"
mkdir -p "$BIN"
if [[ -f "${BIN}/corebrum-up" ]] && ! cmp -s "${SRC}/bin/corebrum-up" "${BIN}/corebrum-up"; then
  backup="${BIN}/corebrum-up.bak.$(date +%s)"
  cp "${BIN}/corebrum-up" "$backup"
  echo "    previous version saved to ${backup}"
fi
install -m 755 "${SRC}/bin/corebrum-up" "${BIN}/corebrum-up"

step "Installing icon"
mkdir -p "$ICON_DIR"
if [[ -f "$ICON_SRC" ]]; then
  magick "$ICON_SRC" -resize 256x256 "${ICON_DIR}/corebrum.png" 2>/dev/null ||
    cp "$ICON_SRC" "${ICON_DIR}/corebrum.png"
  gtk-update-icon-cache "${HOME}/.local/share/icons/hicolor" &>/dev/null || true
else
  echo "    ${ICON_SRC} not found; launchers will have no icon"
fi

step "Creating app launchers"
mkdir -p "$APPS"
cat >"${APPS}/corebrum.desktop" <<EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Corebrum
Comment=Start or attach to the Corebrum mesh (Zenoh, daemon, web UI)
Exec=${BIN}/corebrum-up
Icon=corebrum
Terminal=false
StartupWMClass=org.corebrum.mesh
Categories=Development;Network;
Actions=web;stop;

[Desktop Action web]
Name=Open Web UI
Exec=omarchy-launch-or-focus-webapp Corebrum ${WEB_URL}

[Desktop Action stop]
Name=Stop Mesh
Exec=${BIN}/corebrum-up stop
EOF
omarchy webapp install "Corebrum Web" "$WEB_URL" "${ICON_DIR}/corebrum.png"

step "Installing bar widget ${PLUGIN_ID}"
updating=false
[[ -d "$PLUGIN_DIR" ]] && updating=true
mkdir -p "$PLUGIN_DIR"
cp "${SRC}/plugin/${PLUGIN_ID}/"* "$PLUGIN_DIR/"
omarchy plugin validate "$PLUGIN_DIR"

step "Adding the Corebrum submenu to the Omarchy menu"
mkdir -p "$(dirname "$MENU")"
[[ -f "$MENU" ]] || printf '{\n}\n' >"$MENU"
cp "$MENU" "${MENU}.bak.$(date +%s)"
python3 - "$MENU" "${SRC}/menu/corebrum-menu.jsonc" <<'PY'
import sys, pathlib
menu, snippet = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]).read_text().rstrip("\n")
lines = [l for l in menu.read_text().splitlines()
         if not l.lstrip().startswith(('"corebrum', "// Corebrum mesh"))]
while lines and not lines[-1].strip():
    lines.pop()
if not lines or lines[-1].strip() != "}":
    sys.exit(f"{menu} does not end with '}}'; add {sys.argv[2]} by hand.")
lines.pop()
while lines and not lines[-1].strip():
    lines.pop()
menu.write_text("\n".join(lines + ["", snippet, "}"]) + "\n")
PY

step "Opening Zenoh through the firewall"
# Prompt lives in corebrum-up so a later reinstall opens the same two ports.
"${BIN}/corebrum-up" firewall

step "Enabling the bar widget"
if $updating; then
  # Plugin hot reload can keep running the old QML, so restart the shell.
  omarchy restart shell >/dev/null 2>&1 || true
else
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  sleep 1
fi
if ! omarchy plugin list | grep -qE "^${PLUGIN_ID}[[:space:]]+enabled"; then
  omarchy plugin enable "$PLUGIN_ID"
fi

step "Done"
cat <<EOF
  App launcher (Super+Space): "Corebrum" and "Corebrum Web"
  Bar brain icon: left-click = start / stop, right-click = Corebrum menu
  Move the icon:  omarchy bar move ${PLUGIN_ID} --section center
  Other Omarchy machines on this network can join when UFW allows TCP 7447 and UDP 7446.
EOF
