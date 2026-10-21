#!/usr/bin/env bash
# Remove the Corebrum Omarchy integration installed by install.sh.
# Leaves ~/.local/bin/corebrum-up and Corebrum itself in place, and does not
# stop a running mesh.
set -euo pipefail

APPS="${HOME}/.local/share/applications"
ICON_DIR="${HOME}/.local/share/icons/hicolor/256x256/apps"
PLUGIN_ID=corebrum.mesh
PLUGIN_DIR="${HOME}/.config/omarchy/plugins/${PLUGIN_ID}"
MENU="${HOME}/.config/omarchy/extensions/omarchy-menu.jsonc"

step() { printf '\e[32m==>\e[0m %s\n' "$*"; }

step "Removing bar widget"
omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
rm -rf "$PLUGIN_DIR"
omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true

step "Removing Corebrum submenu"
if [[ -f "$MENU" ]] && grep -q '"corebrum' "$MENU"; then
  cp "$MENU" "${MENU}.bak.$(date +%s)"
  python3 - "$MENU" <<'PY'
import sys, pathlib
menu = pathlib.Path(sys.argv[1])
lines = [l for l in menu.read_text().splitlines()
         if not l.lstrip().startswith(('"corebrum', "// Corebrum mesh"))]
menu.write_text("\n".join(lines) + "\n")
PY
fi

step "Removing app launchers"
rm -f "${APPS}/corebrum.desktop"
if [[ -f "${APPS}/Corebrum Web.desktop" ]]; then
  omarchy webapp remove "Corebrum Web" || rm -f "${APPS}/Corebrum Web.desktop"
fi
rm -f "${ICON_DIR}/corebrum.png" "${ICON_DIR}/corebrum-web.png"
gtk-update-icon-cache "${HOME}/.local/share/icons/hicolor" &>/dev/null || true

step "Done"
