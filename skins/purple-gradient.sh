#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-/Applications/Codex.app}"
RESOURCES_DIR="$APP_PATH/Contents/Resources"
ASAR_PATH="$RESOURCES_DIR/app.asar"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-purple-gradient.XXXXXX")"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

if [[ ! -f "$ASAR_PATH" ]]; then
  echo "Cannot find app.asar at: $ASAR_PATH" >&2
  exit 1
fi

if ! command -v npm >/dev/null 2>&1; then
  echo "npm is required so this script can run @electron/asar." >&2
  exit 1
fi

echo "Extracting $ASAR_PATH"
npm exec --yes @electron/asar -- extract "$ASAR_PATH" "$WORK_DIR/app"

CSS_FILE="$(find "$WORK_DIR/app/webview/assets" -maxdepth 1 -type f -name 'app-main-*.css' | head -n 1)"
INDEX_FILE="$WORK_DIR/app/webview/index.html"

if [[ -z "$CSS_FILE" || ! -f "$CSS_FILE" ]]; then
  echo "Could not find webview/assets/app-main-*.css in app.asar." >&2
  exit 1
fi

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "Could not find webview/index.html in app.asar." >&2
  exit 1
fi

python3 - "$CSS_FILE" "$INDEX_FILE" <<'PY'
import pathlib
import sys

css_path = pathlib.Path(sys.argv[1])
index_path = pathlib.Path(sys.argv[2])

marker_start = "/* codex-purple-gradient:start */"
marker_end = "/* codex-purple-gradient:end */"
override = f"""
{marker_start}
:root {{
  --codex-purple-gradient-background:
    radial-gradient(circle at 18% 12%, rgba(168, 85, 247, 0.34), transparent 30%),
    radial-gradient(circle at 86% 8%, rgba(217, 70, 239, 0.24), transparent 28%),
    linear-gradient(135deg, #12091f 0%, #2d1457 46%, #5b21b6 100%);
}}

html,
body,
#root {{
  background: var(--codex-purple-gradient-background) !important;
}}

body {{
  background-color: #12091f !important;
}}

.main-surface:where(:is([data-codex-window-type=browser],[data-codex-window-type=chrome-extension],[data-codex-window-type=electron]) .main-surface),
.browser-main-surface {{
  background-color: color-mix(in srgb, var(--color-token-main-surface-primary) 88%, transparent) !important;
  backdrop-filter: blur(18px);
}}
{marker_end}
""".strip()

css = css_path.read_text()
if marker_start in css and marker_end in css:
    before = css.split(marker_start, 1)[0].rstrip()
    after = css.split(marker_end, 1)[1].lstrip()
    css = f"{before}\n{override}\n{after}"
else:
    css = f"{css.rstrip()}\n{override}\n"
css_path.write_text(css)

index = index_path.read_text()
index = index.replace(
    "--startup-background: transparent;",
    "--startup-background: linear-gradient(135deg, #12091f 0%, #2d1457 46%, #5b21b6 100%);",
)
index_path.write_text(index)
PY

if [[ ! -f "$ASAR_PATH.orig" ]]; then
  cp "$ASAR_PATH" "$ASAR_PATH.orig"
  echo "Saved backup: $ASAR_PATH.orig"
fi

NEW_ASAR="$WORK_DIR/app.asar"
npm exec --yes @electron/asar -- pack "$WORK_DIR/app" "$NEW_ASAR"
cp "$NEW_ASAR" "$ASAR_PATH"

if [[ -f "$INFO_PLIST" ]]; then
  HASH="$(shasum -a 256 "$ASAR_PATH" | awk '{print $1}')"
  /usr/libexec/PlistBuddy -c "Set :ElectronAsarIntegrity:Resources/app.asar:hash $HASH" "$INFO_PLIST" 2>/dev/null || true
fi

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true
fi

echo "Codex purple gradient patch applied to $APP_PATH"
