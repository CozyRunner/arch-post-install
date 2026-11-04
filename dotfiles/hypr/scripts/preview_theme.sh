#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════╗
# ║              Theme Preview CLI                               ║
# ║   Generate an HTML preview of any color scheme + mode        ║
# ╚══════════════════════════════════════════════════════════════╝
#
# Usage:
#   preview_theme.sh                          # preview current theme
#   preview_theme.sh glassmorphism dark       # preview specific scheme+mode
#   preview_theme.sh --list                   # list available schemes
#   preview_theme.sh --compare dark           # side-by-side all schemes
#
# Opens a self-contained HTML file in the default browser showing
# color swatches for SwayNC, Waybar, and accent colors.

set -euo pipefail

# ── Config ────────────────────────────────────────────────────
SWAYNC_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/swaync"
WAYBAR_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/waybar"
PREVIEW_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/theme-preview"
mkdir -p "$PREVIEW_DIR"

ALL_SCHEMES=(glassmorphism catppuccin tokyonight gruvbox everforest nord rose-pine)

# ── Parse CSS color definitions ───────────────────────────────
# Extract @define-color values from a CSS file into an associative array
# Usage: parse_colors <file>  → prints "name=value" lines
parse_colors() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    grep '@define-color' "$file" | sed -E 's/.*@define-color\s+([a-zA-Z0-9_-]+)\s+(.*);/\1=\2/' | sed 's/\s*$//'
}

# ── List available schemes ────────────────────────────────────
do_list() {
    echo "Available color schemes:"
    for s in "${ALL_SCHEMES[@]}"; do
        local dark_ok="✗" light_ok="✗"
        [[ -f "$SWAYNC_DIR/colors-${s}-dark.css" ]] && dark_ok="✓"
        [[ -f "$SWAYNC_DIR/colors-${s}-light.css" ]] && light_ok="✓"
        printf "  %-16s  dark:%s  light:%s\n" "$s" "$dark_ok" "$light_ok"
    done
}

# ── Generate a single scheme card (HTML fragment) ─────────────
generate_card() {
    local scheme="$1" mode="$2"
    local swaync_file="$SWAYNC_DIR/colors-${scheme}-${mode}.css"
    local waybar_file="$WAYBAR_DIR/colors-${scheme}-${mode}.css"

    # Fallback
    [[ ! -f "$swaync_file" ]] && swaync_file="$SWAYNC_DIR/colors-${mode}.css"
    [[ ! -f "$waybar_file" ]] && waybar_file="$WAYBAR_DIR/colors-${mode}.css"

    local title="${scheme^} (${mode})"

    # Parse SwayNC colors
    local -A colors=()
    if [[ -f "$swaync_file" ]]; then
        while IFS='=' read -r name value; do
            colors["$name"]="$value"
        done < <(parse_colors "$swaync_file")
    fi

    # Parse Waybar colors for extras
    local -A wb_colors=()
    if [[ -f "$waybar_file" ]]; then
        while IFS='=' read -r name value; do
            wb_colors["$name"]="$value"
        done < <(parse_colors "$waybar_file")
    fi

    local bg="${colors[cc-bg]:-#1e1e2e}"
    local text="${colors[text-color]:-#cdd6f4}"
    local accent_blue="${colors[accent-blue]:-#89b4fa}"
    local accent_cyan="${colors[accent-cyan]:-#94e2d5}"
    local accent_purple="${colors[accent-purple]:-#cba6f7}"
    local accent_green="${colors[accent-green]:-#a6e3a1}"
    local accent_red="${colors[accent-red]:-#f38ba8}"
    local accent_orange="${colors[accent-orange]:-#fab387}"
    local notif_bg="${colors[notif-bg]:-#313244}"
    local widget_bg="${colors[widget-bg]:-#45475a}"
    local border="${colors[notif-border]:-#585b70}"
    local text_muted="${colors[text-muted]:-#a6adc8}"
    local wb_bar="${wb_colors[bg-bar]:-$bg}"
    local wb_module="${wb_colors[bg-module]:-$widget_bg}"

    cat <<HTML
    <div class="card" style="background:${bg}; color:${text}; border:1px solid ${border};">
      <h2>${title}</h2>

      <div class="section-label">Accent Colors</div>
      <div class="swatches">
        <div class="swatch" style="background:${accent_blue};" title="accent-blue"><span>Blue</span></div>
        <div class="swatch" style="background:${accent_cyan};" title="accent-cyan"><span>Cyan</span></div>
        <div class="swatch" style="background:${accent_purple};" title="accent-purple"><span>Purple</span></div>
        <div class="swatch" style="background:${accent_green};" title="accent-green"><span>Green</span></div>
        <div class="swatch" style="background:${accent_red};" title="accent-red"><span>Red</span></div>
        <div class="swatch" style="background:${accent_orange};" title="accent-orange"><span>Orange</span></div>
      </div>

      <div class="section-label">Surface Colors</div>
      <div class="surfaces">
        <div class="surface-row">
          <div class="surface-swatch" style="background:${bg};"><small>cc-bg</small></div>
          <div class="surface-swatch" style="background:${notif_bg};"><small>notif-bg</small></div>
          <div class="surface-swatch" style="background:${widget_bg};"><small>widget-bg</small></div>
        </div>
      </div>

      <div class="section-label">Waybar</div>
      <div class="surfaces">
        <div class="surface-row">
          <div class="surface-swatch" style="background:${wb_bar};"><small>bar</small></div>
          <div class="surface-swatch" style="background:${wb_module};"><small>module</small></div>
        </div>
      </div>

      <div class="section-label">Text</div>
      <div class="text-preview">
        <span style="color:${text};">Primary text</span>
        <span style="color:${text_muted};">Muted text</span>
      </div>
    </div>
HTML
}

# ── Generate full HTML page ───────────────────────────────────
generate_page() {
    local title="$1"
    shift
    # remaining args: pairs of "scheme mode"

    cat <<'HTML_HEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<style>
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
    background: #0a0a1a;
    color: #e2e8f0;
    padding: 2rem;
  }
  h1 {
    text-align: center;
    margin-bottom: 2rem;
    font-size: 1.6rem;
    font-weight: 600;
    letter-spacing: -0.02em;
  }
  .grid {
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(340px, 1fr));
    gap: 1.5rem;
    max-width: 1400px;
    margin: 0 auto;
  }
  .card {
    border-radius: 16px;
    padding: 1.5rem;
    backdrop-filter: blur(10px);
    transition: transform 0.2s;
  }
  .card:hover { transform: translateY(-2px); }
  .card h2 {
    font-size: 1.1rem;
    margin-bottom: 1rem;
    font-weight: 600;
    letter-spacing: -0.01em;
  }
  .section-label {
    font-size: 0.7rem;
    text-transform: uppercase;
    letter-spacing: 0.08em;
    opacity: 0.6;
    margin: 0.8rem 0 0.4rem;
  }
  .swatches {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
  }
  .swatch {
    width: 48px;
    height: 48px;
    border-radius: 10px;
    display: flex;
    align-items: flex-end;
    justify-content: center;
    padding-bottom: 4px;
    transition: transform 0.15s;
  }
  .swatch:hover { transform: scale(1.1); }
  .swatch span {
    font-size: 0.55rem;
    font-weight: 600;
    text-transform: uppercase;
    letter-spacing: 0.04em;
    color: rgba(0,0,0,0.6);
    text-shadow: 0 1px 2px rgba(255,255,255,0.3);
  }
  .surfaces { margin-bottom: 0.3rem; }
  .surface-row { display: flex; gap: 8px; }
  .surface-swatch {
    flex: 1;
    height: 36px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    border: 1px solid rgba(255,255,255,0.08);
  }
  .surface-swatch small {
    font-size: 0.6rem;
    opacity: 0.7;
  }
  .text-preview {
    display: flex;
    gap: 1.5rem;
    padding: 0.5rem 0;
    font-size: 0.85rem;
  }
  footer {
    text-align: center;
    margin-top: 2rem;
    font-size: 0.75rem;
    opacity: 0.4;
  }
</style>
HTML_HEAD

    echo "<title>${title}</title>"
    echo "</head><body>"
    echo "<h1>🎨 ${title}</h1>"
    echo '<div class="grid">'

    while [[ $# -ge 2 ]]; do
        generate_card "$1" "$2"
        shift 2
    done

    echo '</div>'
    echo "<footer>Generated by arch-post-install theme preview · $(date '+%Y-%m-%d %H:%M')</footer>"
    echo '</body></html>'
}

# ── Main ──────────────────────────────────────────────────────
case "${1:-}" in
    --list)
        do_list
        exit 0
        ;;
    --compare)
        MODE="${2:-dark}"
        OUTFILE="$PREVIEW_DIR/compare-${MODE}.html"
        args=()
        for s in "${ALL_SCHEMES[@]}"; do
            args+=("$s" "$MODE")
        done
        generate_page "Theme Comparison — ${MODE^} Mode" "${args[@]}" > "$OUTFILE"
        echo "Preview saved to: $OUTFILE"
        if command -v xdg-open &>/dev/null; then
            xdg-open "$OUTFILE" &>/dev/null &
        fi
        ;;
    "")
        # Preview current theme
        SCHEME=$(cat "$HOME/.cache/theme_scheme" 2>/dev/null || echo "glassmorphism")
        MODE=$(cat "$HOME/.cache/theme_mode" 2>/dev/null || echo "dark")
        OUTFILE="$PREVIEW_DIR/preview-${SCHEME}-${MODE}.html"
        generate_page "Theme Preview — ${SCHEME^} ${MODE^}" "$SCHEME" "$MODE" > "$OUTFILE"
        echo "Preview saved to: $OUTFILE"
        if command -v xdg-open &>/dev/null; then
            xdg-open "$OUTFILE" &>/dev/null &
        fi
        ;;
    *)
        SCHEME="$1"
        MODE="${2:-dark}"
        OUTFILE="$PREVIEW_DIR/preview-${SCHEME}-${MODE}.html"
        generate_page "Theme Preview — ${SCHEME^} ${MODE^}" "$SCHEME" "$MODE" > "$OUTFILE"
        echo "Preview saved to: $OUTFILE"
        if command -v xdg-open &>/dev/null; then
            xdg-open "$OUTFILE" &>/dev/null &
        fi
        ;;
esac

