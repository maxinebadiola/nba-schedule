#!/usr/bin/env bash
set -euo pipefail

WIDGET_ID="org.kde.plasma.nba-schedule"
ENV_FILE="$(dirname "$0")/.env"

# Load .env — parse manually so stray lines don't abort the script
if [[ -f "$ENV_FILE" ]]; then
    NBA_API_KEY=$(grep -E '^NBA_API_KEY=' "$ENV_FILE" | head -1 | cut -d= -f2- | tr -d '\r\n')
fi

# Install / upgrade the package
echo "Installing $WIDGET_ID..."
if kpackagetool6 --type Plasma/Applet --list 2>/dev/null | grep -q "$WIDGET_ID"; then
    kpackagetool6 --type Plasma/Applet --upgrade ./package
else
    kpackagetool6 --type Plasma/Applet --install ./package
fi

# Pre-load the API key into the widget's KConfig if we have one
if [[ -n "${NBA_API_KEY:-}" ]]; then
    echo "Writing API key to widget config..."
    kwriteconfig6 \
        --file "$HOME/.config/${WIDGET_ID}rc" \
        --group General \
        --key apiKey \
        "$NBA_API_KEY"

    # plasmawindowed stores applet config in its own rc file under [Applets][N]
    # groups, so mirror the key there for standalone test runs.
    WINDOWED_RC="$HOME/.config/plasmawindowedrc"
    if [[ -f "$WINDOWED_RC" ]]; then
        while IFS= read -r applet_id; do
            [[ -z "$applet_id" ]] && continue
            kwriteconfig6 \
                --file "$WINDOWED_RC" \
                --group Applets \
                --group "$applet_id" \
                --group Configuration \
                --group General \
                --key apiKey \
                "$NBA_API_KEY"
        done < <(
            awk -v widget_id="$WIDGET_ID" '
                match($0, /^\[Applets\]\[([0-9]+)\]$/, m) { current = m[1] }
                $0 == "plugin=" widget_id && current != "" { print current }
            ' "$WINDOWED_RC" | sort -u
        )
    fi

    echo "API key written."
else
    echo "No NBA_API_KEY in .env — enter it manually via the widget config UI."
fi

echo ""
echo "Done. Test with:"
echo "  plasmawindowed $WIDGET_ID"
echo ""
echo "Or restart Plasma to pick up the update:"
echo "  systemctl --user restart plasma-plasmashell.service"
