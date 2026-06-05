#!/usr/bin/env bash
set -euo pipefail

APP_PATH="${1:-/Applications/Codex.app}"
RESOURCES_DIR="$APP_PATH/Contents/Resources"
ASAR_PATH="$RESOURCES_DIR/app.asar"
INFO_PLIST="$APP_PATH/Contents/Info.plist"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/codex-win98.XXXXXX")"

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
MAIN_FILE="$(find "$WORK_DIR/app/.vite/build" -maxdepth 1 -type f -name 'main-*.js' | head -n 1)"

if [[ -z "$CSS_FILE" || ! -f "$CSS_FILE" ]]; then
  echo "Could not find webview/assets/app-main-*.css in app.asar." >&2
  exit 1
fi

if [[ ! -f "$INDEX_FILE" ]]; then
  echo "Could not find webview/index.html in app.asar." >&2
  exit 1
fi

if [[ -z "$MAIN_FILE" || ! -f "$MAIN_FILE" ]]; then
  echo "Could not find .vite/build/main-*.js in app.asar." >&2
  exit 1
fi

python3 - "$CSS_FILE" "$INDEX_FILE" "$MAIN_FILE" <<'PY'
import pathlib
import re
import sys

css_path = pathlib.Path(sys.argv[1])
index_path = pathlib.Path(sys.argv[2])
main_path = pathlib.Path(sys.argv[3])

markers = [
    ("/* codex-purple-gradient:start */", "/* codex-purple-gradient:end */"),
    ("/* codex-win98:start */", "/* codex-win98:end */"),
]

marker_start = "/* codex-win98:start */"
marker_end = "/* codex-win98:end */"

override = f"""
{marker_start}
:root {{
  --win98-desktop: #008080;
  --win98-face: #c0c0c0;
  --win98-face-light: #dfdfdf;
  --win98-highlight: #ffffff;
  --win98-light-shadow: #dfdfdf;
  --win98-shadow: #808080;
  --win98-dark-shadow: #000000;
  --win98-text: #000000;
  --win98-muted-text: #555555;
  --win98-title-a: #000080;
  --win98-title-b: #1084d0;
  --win98-inactive-title-a: #808080;
  --win98-inactive-title-b: #b5b5b5;
  --win98-link: #0000ee;
  --win98-focus: #000000;
  --win98-window-gap: 2px;
  --win98-caption-height: 18px;
  --win98-menu-height: 20px;
  --win98-control-size: 16px;
  --spacing-token-button-composer: 24px !important;
  --spacing-token-button-composer-sm: 21px !important;
  --spacing-token-button-composer-gap: 2px !important;
  --h-token-button-composer-gap: 2px !important;
  --font-sans: Tahoma, "MS Sans Serif", "Microsoft Sans Serif", Arial, sans-serif !important;
  --font-mono: "Lucida Console", "Courier New", monospace !important;
  --vscode-font-family: Tahoma, "MS Sans Serif", "Microsoft Sans Serif", Arial, sans-serif !important;
  --vscode-editor-font-family: "Lucida Console", "Courier New", monospace !important;
  --color-token-editor-foreground: var(--win98-text) !important;
  --color-token-foreground: var(--win98-text) !important;
  --color-token-description-foreground: var(--win98-muted-text) !important;
  --color-token-main-surface-primary: var(--win98-face) !important;
  --color-token-side-bar-background: var(--win98-face) !important;
  --color-token-bg-primary: var(--win98-face) !important;
  --color-token-dropdown-background: var(--win98-face) !important;
  --color-token-border-light: var(--win98-shadow) !important;
  --color-token-border-medium: var(--win98-shadow) !important;
  --color-token-border-heavy: var(--win98-dark-shadow) !important;
  --radius-xs-base: 0px !important;
  --radius-sm-base: 0px !important;
  --radius-md-base: 0px !important;
  --radius-lg-base: 0px !important;
  --radius-xl-base: 0px !important;
  --radius-2xl-base: 0px !important;
  --radius-3xl-base: 0px !important;
  --radius-4xl-base: 0px !important;
  --radius-2xs: 0px !important;
  --radius-xs: 0px !important;
  --radius-sm: 0px !important;
  --radius-md: 0px !important;
  --radius-lg: 0px !important;
  --radius-xl: 0px !important;
  --radius-2xl: 0px !important;
  --radius-3xl: 0px !important;
  --radius-4xl: 0px !important;
  --corner-radius-scale: 0 !important;
}}

html,
body,
#root {{
  background: var(--win98-desktop) !important;
  color: var(--win98-text) !important;
  font-family: Tahoma, "MS Sans Serif", "Microsoft Sans Serif", Arial, sans-serif !important;
  font-size: 12px !important;
  letter-spacing: 0 !important;
}}

* {{
  border-radius: 0 !important;
  corner-shape: initial !important;
  text-shadow: none !important;
  box-shadow: none !important;
  letter-spacing: 0 !important;
  scrollbar-color: var(--win98-shadow) var(--win98-face) !important;
}}

html,
body,
#root,
[data-codex-window-type="electron"],
[data-codex-window-type="electron"] body,
[data-codex-window-type="electron"] #root,
[class*="app-shell"],
[class*="app-shell"]::before,
[class*="app-shell"]::after,
[class*="left-panel"],
[class*="left-panel"]::before,
[class*="left-panel"]::after,
[class*="right-panel"],
[class*="right-panel"]::before,
[class*="right-panel"]::after,
.main-surface,
.main-surface::before,
.main-surface::after,
.browser-main-surface,
.browser-main-surface::before,
.browser-main-surface::after {{
  border-radius: 0 !important;
  clip-path: none !important;
  mask-image: none !important;
  -webkit-mask-image: none !important;
}}

::selection {{
  background: #000080 !important;
  color: #ffffff !important;
}}

a,
[role="link"] {{
  color: var(--win98-link) !important;
  text-decoration: underline !important;
}}

::-webkit-scrollbar {{
  width: 16px !important;
  height: 16px !important;
  background: var(--win98-face) !important;
}}

::-webkit-scrollbar-track {{
  background:
    linear-gradient(45deg, var(--win98-highlight) 25%, transparent 25%),
    linear-gradient(-45deg, var(--win98-highlight) 25%, transparent 25%),
    linear-gradient(45deg, transparent 75%, var(--win98-highlight) 75%),
    linear-gradient(-45deg, transparent 75%, var(--win98-highlight) 75%),
    var(--win98-face) !important;
  background-position: 0 0, 0 8px, 8px -8px, -8px 0 !important;
  background-size: 16px 16px !important;
}}

::-webkit-scrollbar-thumb {{
  background: var(--win98-face) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 1px solid var(--win98-dark-shadow) !important;
  box-shadow: inset -1px -1px 0 var(--win98-shadow), inset 1px 1px 0 var(--win98-light-shadow) !important;
}}

::-webkit-scrollbar-button {{
  width: 16px !important;
  height: 16px !important;
  display: block !important;
  background: var(--win98-face) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 1px solid var(--win98-dark-shadow) !important;
}}

.main-surface:where(:is([data-codex-window-type=browser],[data-codex-window-type=chrome-extension],[data-codex-window-type=electron]) .main-surface),
.browser-main-surface,
[class*="main-surface"],
[class*="panel"],
[class*="sidebar"],
[class*="thread"],
[class*="composer"],
[class*="card"],
[class*="dialog"],
[class*="popover"],
[class*="dropdown"],
[role="dialog"],
[role="menu"],
[role="listbox"] {{
  background-color: var(--win98-face) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 1px solid var(--win98-dark-shadow) !important;
  box-shadow: inset -1px -1px 0 var(--win98-shadow), inset 1px 1px 0 var(--win98-light-shadow) !important;
  backdrop-filter: none !important;
}}

.main-surface:where(:is([data-codex-window-type=browser],[data-codex-window-type=chrome-extension],[data-codex-window-type=electron]) .main-surface),
.browser-main-surface {{
  margin: 2px !important;
  padding: var(--win98-window-gap) !important;
}}

[data-codex-window-type="electron"] [class*="app-header"],
[class*="titlebar"] {{
  background: linear-gradient(90deg, var(--win98-title-a), var(--win98-title-b)) !important;
  color: #ffffff !important;
  border: 0 !important;
  min-height: var(--win98-caption-height) !important;
  height: var(--win98-caption-height) !important;
  padding: 1px 2px !important;
  font-weight: 700 !important;
  font-size: 11px !important;
  line-height: 16px !important;
  display: flex !important;
  align-items: center !important;
  gap: 2px !important;
}}

[data-codex-window-type="electron"] [class*="app-header"] *,
[class*="titlebar"] * {{
  color: inherit !important;
}}

[data-codex-window-type="electron"] [class*="app-header"] button,
[class*="titlebar"] button {{
  width: var(--win98-control-size) !important;
  height: 14px !important;
  min-width: var(--win98-control-size) !important;
  min-height: 14px !important;
  padding: 0 !important;
  margin: 0 1px !important;
  background: var(--win98-face) !important;
  color: var(--win98-text) !important;
  font-family: Marlett, "MS Sans Serif", Tahoma, sans-serif !important;
  font-size: 10px !important;
  line-height: 12px !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 1px solid var(--win98-dark-shadow) !important;
  box-shadow: inset -1px -1px 0 var(--win98-shadow), inset 1px 1px 0 var(--win98-light-shadow) !important;
}}

[role="menubar"],
[class*="menubar"],
[class*="menu-bar"],
[class*="toolbar"] {{
  min-height: var(--win98-menu-height) !important;
  background: var(--win98-face) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-shadow) !important;
  border-bottom: 1px solid var(--win98-shadow) !important;
  padding: 1px 2px !important;
  display: flex !important;
  align-items: center !important;
  gap: 2px !important;
}}

[role="menuitem"],
[class*="menu-item"] {{
  min-height: 18px !important;
  padding: 2px 8px !important;
  color: var(--win98-text) !important;
  background: transparent !important;
}}

[role="menuitem"]:hover,
[class*="menu-item"]:hover {{
  background: #000080 !important;
  color: #ffffff !important;
}}

[class*="sidebar"],
[class*="side-bar"],
[class*="thread-list"],
[class*="navigation"],
[class*="nav"] {{
  background-color: var(--win98-face) !important;
  color: var(--win98-text) !important;
}}

[class*="sidebar"] *,
[class*="side-bar"] *,
[class*="thread-list"] *,
[class*="navigation"] *,
[class*="nav"] * {{
  color: var(--win98-text) !important;
}}

button,
[role="button"],
input[type="button"],
input[type="submit"],
input[type="reset"],
[class*="button"] {{
  appearance: none !important;
  -webkit-appearance: none !important;
  background: var(--win98-face) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 1px solid var(--win98-dark-shadow) !important;
  box-shadow: inset -1px -1px 0 var(--win98-shadow), inset 1px 1px 0 var(--win98-light-shadow) !important;
  padding: 2px 8px 3px !important;
  min-height: 23px !important;
  min-width: 75px !important;
  font: 12px Tahoma, "MS Sans Serif", Arial, sans-serif !important;
  font-weight: 400 !important;
}}

button:active,
[role="button"]:active,
[class*="button"]:active {{
  border-top-color: var(--win98-dark-shadow) !important;
  border-left-color: var(--win98-dark-shadow) !important;
  border-right-color: var(--win98-highlight) !important;
  border-bottom-color: var(--win98-highlight) !important;
  box-shadow: inset -1px -1px 0 var(--win98-light-shadow), inset 1px 1px 0 var(--win98-shadow) !important;
  padding-top: 4px !important;
  padding-left: 9px !important;
  padding-right: 7px !important;
  padding-bottom: 2px !important;
}}

button:focus-visible,
[role="button"]:focus-visible,
input:focus,
textarea:focus,
[contenteditable="true"]:focus {{
  outline: 1px dotted var(--win98-focus) !important;
  outline-offset: -4px !important;
}}

input,
textarea,
select,
[contenteditable="true"],
[role="textbox"] {{
  background: #ffffff !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-shadow) !important;
  border-left: 1px solid var(--win98-shadow) !important;
  border-right: 1px solid var(--win98-highlight) !important;
  border-bottom: 1px solid var(--win98-highlight) !important;
  box-shadow: inset 1px 1px 0 var(--win98-dark-shadow), inset -1px -1px 0 var(--win98-light-shadow) !important;
  min-height: 21px !important;
  padding: 2px 4px !important;
  font: 12px Tahoma, "MS Sans Serif", Arial, sans-serif !important;
}}

pre,
code,
.vscode-markdown code,
.vscode-markdown pre,
[class*="terminal"],
[class*="xterm"] {{
  background: #000000 !important;
  color: #00ff00 !important;
  font-family: "Lucida Console", "Courier New", monospace !important;
  border-top: 1px solid var(--win98-shadow) !important;
  border-left: 1px solid var(--win98-shadow) !important;
  border-right: 1px solid var(--win98-highlight) !important;
  border-bottom: 1px solid var(--win98-highlight) !important;
  box-shadow: inset 1px 1px 0 var(--win98-dark-shadow), inset -1px -1px 0 var(--win98-light-shadow) !important;
}}

table,
[class*="table"],
[class*="list"],
[class*="row"] {{
  background-color: var(--win98-face) !important;
  color: var(--win98-text) !important;
}}

[class*="row"]:hover,
[class*="list"] [aria-selected="true"],
[role="option"][aria-selected="true"] {{
  background: #000080 !important;
  color: #ffffff !important;
}}

[class*="row"]:hover *,
[class*="list"] [aria-selected="true"] *,
[role="option"][aria-selected="true"] * {{
  color: #ffffff !important;
}}

[class*="tab"],
[role="tab"] {{
  background: var(--win98-face) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 0 !important;
  box-shadow: inset -1px 0 0 var(--win98-shadow), inset 1px 1px 0 var(--win98-light-shadow) !important;
  padding: 2px 8px 3px !important;
  min-height: 21px !important;
}}

[aria-selected="true"],
[data-selected="true"],
[data-state="active"] {{
  background: var(--win98-face-light) !important;
  color: var(--win98-text) !important;
}}

hr,
[class*="divider"],
[class*="separator"] {{
  border: 0 !important;
  border-top: 1px solid var(--win98-shadow) !important;
  border-bottom: 1px solid var(--win98-highlight) !important;
  height: 2px !important;
  background: transparent !important;
}}

[class*="badge"],
[class*="pill"],
[class*="tag"] {{
  background: var(--win98-face-light) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-shadow) !important;
  border-bottom: 1px solid var(--win98-shadow) !important;
}}

[class*="toast"],
[class*="alert"] {{
  background: var(--win98-face) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-highlight) !important;
  border-left: 1px solid var(--win98-highlight) !important;
  border-right: 1px solid var(--win98-dark-shadow) !important;
  border-bottom: 1px solid var(--win98-dark-shadow) !important;
  box-shadow: inset -1px -1px 0 var(--win98-shadow), inset 1px 1px 0 var(--win98-light-shadow) !important;
}}

[class*="icon"],
[aria-hidden="true"] svg {{
  color: var(--win98-text) !important;
  stroke-width: 1.5 !important;
}}

[class*="checkbox"],
input[type="checkbox"],
[role="checkbox"] {{
  width: 13px !important;
  height: 13px !important;
  min-width: 13px !important;
  min-height: 13px !important;
  background: #ffffff !important;
  border-top: 1px solid var(--win98-shadow) !important;
  border-left: 1px solid var(--win98-shadow) !important;
  border-right: 1px solid var(--win98-highlight) !important;
  border-bottom: 1px solid var(--win98-highlight) !important;
  box-shadow: inset 1px 1px 0 var(--win98-dark-shadow), inset -1px -1px 0 var(--win98-light-shadow) !important;
}}

[class*="status"],
[class*="footer"] {{
  min-height: 20px !important;
  background: var(--win98-face) !important;
  color: var(--win98-text) !important;
  border-top: 1px solid var(--win98-shadow) !important;
  border-left: 1px solid var(--win98-shadow) !important;
  border-right: 1px solid var(--win98-highlight) !important;
  border-bottom: 1px solid var(--win98-highlight) !important;
  padding: 2px 4px !important;
}}

.size-token-button-composer,
.h-token-button-composer,
.h-token-button-composer-sm,
.w-token-button-composer-sm,
button.size-token-button-composer,
button.h-token-button-composer,
button.h-token-button-composer-sm,
button.w-token-button-composer-sm,
[role="button"].size-token-button-composer,
[role="button"].h-token-button-composer,
[role="button"].h-token-button-composer-sm,
[role="button"].w-token-button-composer-sm {{
  width: var(--spacing-token-button-composer-sm) !important;
  min-width: var(--spacing-token-button-composer-sm) !important;
  max-width: var(--spacing-token-button-composer-sm) !important;
  height: var(--spacing-token-button-composer-sm) !important;
  min-height: var(--spacing-token-button-composer-sm) !important;
  max-height: var(--spacing-token-button-composer-sm) !important;
  padding: 1px !important;
  flex: 0 0 auto !important;
  aspect-ratio: auto !important;
  overflow: hidden !important;
}}

.size-token-button-composer svg,
.h-token-button-composer svg,
.h-token-button-composer-sm svg,
.w-token-button-composer-sm svg {{
  width: 12px !important;
  height: 12px !important;
  min-width: 12px !important;
  min-height: 12px !important;
}}

.main-surface [class*="thread-content-max-width"]:has([contenteditable="true"]),
.main-surface [class*="thread-content-max-width"]:has([role="textbox"]),
.browser-main-surface [class*="thread-content-max-width"]:has([contenteditable="true"]),
.browser-main-surface [class*="thread-content-max-width"]:has([role="textbox"]),
[class*="max-w-3xl"]:has([contenteditable="true"]),
[class*="max-w-3xl"]:has([role="textbox"]) {{
  width: 100% !important;
  max-width: none !important;
  min-width: 0 !important;
}}

.main-surface :is(.sticky, .fixed, .absolute):has([contenteditable="true"]),
.main-surface :is(.sticky, .fixed, .absolute):has([role="textbox"]),
.browser-main-surface :is(.sticky, .fixed, .absolute):has([contenteditable="true"]),
.browser-main-surface :is(.sticky, .fixed, .absolute):has([role="textbox"]) {{
  width: 100% !important;
  max-width: none !important;
  min-width: 0 !important;
}}

.main-surface :has(> [data-above-composer-portal]),
.browser-main-surface :has(> [data-above-composer-portal]) {{
  width: 100% !important;
  max-width: none !important;
  min-width: 0 !important;
  flex: 1 1 auto !important;
}}

[data-above-composer-portal],
[data-above-composer-queue-portal] {{
  width: 100% !important;
  max-width: none !important;
}}

svg,
img {{
  image-rendering: pixelated;
}}

[class*="shadow"],
[class*="blur"],
[style*="backdrop-filter"] {{
  box-shadow: none !important;
  backdrop-filter: none !important;
}}
{marker_end}
""".strip()


def strip_marked_blocks(text: str) -> str:
    for start, end in markers:
        text = re.sub(
            re.escape(start) + r".*?" + re.escape(end) + r"\s*",
            "",
            text,
            flags=re.S,
        )
    return text.rstrip()


css = strip_marked_blocks(css_path.read_text())
css_path.write_text(f"{css}\n{override}\n")

index = index_path.read_text()
index = re.sub(
    r"--startup-background:\s*[^;]+;",
    "--startup-background: #008080;",
    index,
)
index = re.sub(
    r"--startup-logo-base:\s*[^;]+;",
    "--startup-logo-base: #ffffff;",
    index,
)
index_path.write_text(index)

main = main_path.read_text()

def replace_once(text, old, new, label):
    old_patterns = old if isinstance(old, tuple) else (old,)
    for pattern in old_patterns:
        if pattern in text:
            return text.replace(pattern, new, 1)
    if new in text:
        return text
    raise SystemExit(f"Could not patch Electron main bundle for {label}; expected pattern was not found.")


main_replacements = [
    (
        "function L2(e,t){return t||A2(e)?null:`menu`}",
        "function L2(e,t){return null}",
        "macOS vibrancy selector",
    ),
    (
        (
            "let{backgroundColor:o,backgroundMaterial:s}=I2({platform:process.platform,appearance:t,opaqueWindowsEnabled:i,prefersDarkColors:a.nativeTheme.shouldUseDarkColors});e.setBackgroundColor(o),s!=null&&e.setBackgroundMaterial(s),process.platform===`darwin`&&e.setVibrancy(L2(t,i))",
            "let{backgroundColor:o,backgroundMaterial:s}=I2({platform:process.platform,appearance:t,opaqueWindowsEnabled:i,prefersDarkColors:a.nativeTheme.shouldUseDarkColors});o=process.platform===`darwin`?`#c0c0c0`:o,s=null,e.setBackgroundColor(o),s!=null&&e.setBackgroundMaterial(s),process.platform===`darwin`&&e.setVibrancy(null)",
        ),
        "let{backgroundColor:o,backgroundMaterial:s}=I2({platform:process.platform,appearance:t,opaqueWindowsEnabled:i,prefersDarkColors:a.nativeTheme.shouldUseDarkColors});o=process.platform===`darwin`?`#c0c0c0`:o,s=null,e.setBackgroundColor(o),s!=null&&e.setBackgroundMaterial(s),process.platform===`darwin`&&(e.setVibrancy(null),e.setWindowButtonVisibility&&e.setWindowButtonVisibility(!1))",
        "window backdrop",
    ),
    (
        "function R2({alwaysOnTop:e,hasShadow:t=!0,platform:n,resizable:r,thickFrame:i,transparent:a=!0}){return{frame:!1,transparent:a,hasShadow:t,resizable:r,minimizable:!1,maximizable:!1,fullscreenable:!1,skipTaskbar:!0,...e?{alwaysOnTop:!0}:{},...n===`win32`?{accentColor:!1,roundedCorners:!1,...i==null?{}:{thickFrame:i}}:{},...n===`darwin`?{type:`panel`}:{}}}",
        "function R2({alwaysOnTop:e,hasShadow:t=!0,platform:n,resizable:r,thickFrame:i,transparent:a=!0}){return{frame:!1,transparent:n===`darwin`?!1:a,backgroundColor:n===`darwin`?`#c0c0c0`:void 0,hasShadow:t,resizable:r,minimizable:!1,maximizable:!1,fullscreenable:!1,skipTaskbar:!0,...e?{alwaysOnTop:!0}:{},...n===`win32`?{accentColor:!1,roundedCorners:!1,...i==null?{}:{thickFrame:i}}:{},...n===`darwin`?{type:`panel`}:{}}}",
        "frameless panel opacity",
    ),
    (
        (
            "case`primary`:return n===`darwin`?t?{titleBarStyle:`hiddenInset`,trafficLightPosition:y2(r)}:{vibrancy:`menu`,titleBarStyle:`hiddenInset`,trafficLightPosition:y2(r)}:n===`win32`?{titleBarStyle:`hidden`,titleBarOverlay:b2(r)}:{titleBarStyle:`default`};",
            "case`primary`:return n===`darwin`?{titleBarStyle:`default`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0}:n===`win32`?{titleBarStyle:`hidden`,titleBarOverlay:b2(r)}:{titleBarStyle:`default`};",
            "case`primary`:return n===`darwin`?{frame:!1,titleBarStyle:`hidden`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0,trafficLightPosition:y2(r)}:n===`win32`?{titleBarStyle:`hidden`,titleBarOverlay:b2(r)}:{titleBarStyle:`default`};",
        ),
        "case`primary`:return n===`darwin`?{frame:!1,titleBarStyle:`hidden`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0,trafficLightPosition:{x:-100,y:-100}}:n===`win32`?{titleBarStyle:`hidden`,titleBarOverlay:b2(r)}:{titleBarStyle:`default`};",
        "primary window chrome",
    ),
    (
        (
            "case`secondary`:return n===`darwin`?t?{titleBarStyle:`default`}:{vibrancy:`menu`,titleBarStyle:`default`}:{titleBarStyle:`default`};",
            "case`secondary`:return n===`darwin`?{titleBarStyle:`default`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0}:{titleBarStyle:`default`};",
        ),
        "case`secondary`:return n===`darwin`?{frame:!1,titleBarStyle:`hidden`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0}:{titleBarStyle:`default`};",
        "secondary window chrome",
    ),
    (
        (
            "case`hud`:return n===`darwin`?t?{titleBarStyle:`hiddenInset`,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0,trafficLightPosition:{x:10,y:10}}:{vibrancy:`menu`,titleBarStyle:`hiddenInset`,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0,trafficLightPosition:{x:10,y:10}}:{titleBarStyle:`default`,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0}",
            "case`hud`:return n===`darwin`?{titleBarStyle:`default`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0}:{titleBarStyle:`default`,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0}",
            "case`hud`:return n===`darwin`?{frame:!1,titleBarStyle:`hidden`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0,trafficLightPosition:{x:10,y:10}}:{titleBarStyle:`default`,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0}",
        ),
        "case`hud`:return n===`darwin`?{frame:!1,titleBarStyle:`hidden`,backgroundColor:`#c0c0c0`,transparent:!1,hasShadow:!0,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0,trafficLightPosition:{x:-100,y:-100}}:{titleBarStyle:`default`,minimizable:!1,maximizable:!1,fullscreenable:!1,alwaysOnTop:!0}",
        "hud window chrome",
    ),
]

for old, new, label in main_replacements:
    main = replace_once(main, old, new, label)

main_path.write_text(main)
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

if [[ "${CODEX_SKIP_CODESIGN:-0}" != "1" ]] && command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_PATH" >/dev/null 2>&1 || true
fi

echo "Codex Windows 98 patch applied to $APP_PATH"
