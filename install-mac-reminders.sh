#!/bin/bash
# install-mac-reminders.sh
# Automatic pop-up warning on macOS a few minutes before each scheduled power event.
#
# Install with the office defaults (10:00 and 12:00, warn 2 minutes before):
#   bash install-mac-reminders.sh
#
# Install with your own times (24-hour clock, any number of them):
#   bash install-mac-reminders.sh 10:00 12:00 16:30
#
# Change how early the warning appears:
#   bash install-mac-reminders.sh --lead 5 10:00 12:00
#
# Show what is installed:   bash install-mac-reminders.sh status
# Test a warning now:       bash install-mac-reminders.sh test
#
# Cancel temporarily:       bash install-mac-reminders.sh disable
# Switch back on:           bash install-mac-reminders.sh enable
# Remove completely:        bash install-mac-reminders.sh uninstall
#
# Installing once is enough: the reminders live in ~/Library/LaunchAgents and
# come back by themselves after every shutdown, reboot, and login.

set -euo pipefail

AGENT_DIR="$HOME/Library/LaunchAgents"
LABEL_PREFIX="local.powercut"
UID_NUM="$(id -u)"

DEFAULT_TIMES=(10:00 12:00)
LEAD=2
GENERATOR_SECONDS=20

die () { echo "Error: $*" >&2; exit 1; }

# --- helpers -----------------------------------------------------------------

# "10:00" -> 600 (minutes since midnight); rejects anything else
to_minutes () {
    local t="$1"
    [[ "$t" =~ ^([0-9]{1,2}):([0-5][0-9])$ ]] || die "bad time '$t' — use 24-hour HH:MM, e.g. 09:30 or 16:00"
    local h=$((10#${BASH_REMATCH[1]})) m=$((10#${BASH_REMATCH[2]}))
    (( h <= 23 )) || die "bad time '$t' — hour must be 00-23"
    echo $(( h * 60 + m ))
}

# 600 -> "10:00 AM"
to_clock () {
    local h=$(( $1 / 60 )) m=$(( $1 % 60 )) ampm=AM
    (( h >= 12 )) && ampm=PM
    local h12=$(( h % 12 )); (( h12 == 0 )) && h12=12
    printf '%d:%02d %s' "$h12" "$m" "$ampm"
}

escape_xml () { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

installed_labels () {
    /bin/ls "$AGENT_DIR" 2>/dev/null \
        | sed -n "s/^\(${LABEL_PREFIX}\.[^.]*\)\.plist$/\1/p" || true
}

remove_all () {
    local found=0 label
    while read -r label; do
        [ -n "$label" ] || continue
        found=1
        launchctl bootout "gui/${UID_NUM}/${label}" 2>/dev/null || true
        # Clear any leftover "disable" flag, or a later reinstall stays silent.
        launchctl enable "gui/${UID_NUM}/${label}" 2>/dev/null || true
        rm -f "$AGENT_DIR/${label}.plist"
        echo "  removed: ${label}"
    done < <(installed_labels)
    [ "$found" = 1 ] || echo "  nothing to remove"
}

# --- the warning itself ------------------------------------------------------

# Prints the shell command that shows the pop-up. $1 = event time in minutes.
warning_command () {
    local event_min="$1"
    local clock; clock="$(to_clock "$event_min")"
    local body="Power switch-over at ${clock} — about ${GENERATOR_SECONDS} seconds without power.

1. Save all your work now
2. Quit anything mid-task (copies, exports, builds, updates)
3. Shut down the Mac if it is a desktop without a UPS"

    # POWERCUT_FORCE=1 skips the freshness check (used by "test").
    # Without it, a warning that launchd held back while the Mac was off or
    # asleep is dropped instead of popping up hours late for a cut that has
    # already happened.
    cat <<CMD
now=\$(( 10#\$(/bin/date +%H) * 60 + 10#\$(/bin/date +%M) ))
left=\$(( ${event_min} - now ))
if [ "\${POWERCUT_FORCE:-0}" != "1" ] && { [ "\$left" -lt -1 ] || [ "\$left" -gt $(( LEAD + 3 )) ]; }; then
    exit 0
fi
for i in 1 2 3; do /usr/bin/afplay /System/Library/Sounds/Sosumi.aiff; done &
/usr/bin/osascript -e 'display alert "POWER CUT in ${LEAD} min (${clock})" message "${body}" as critical giving up after 120' >/dev/null 2>&1 || \
/usr/bin/osascript -e 'display notification "${body}" with title "POWER CUT in ${LEAD} min (${clock})" sound name "Sosumi"'
wait
CMD
}

make_agent () {
    local index="$1" event_min="$2"
    local warn_min=$(( event_min - LEAD ))
    (( warn_min >= 0 )) || die "$(to_clock "$event_min") minus ${LEAD} min falls before midnight — pick a later time or a smaller --lead"

    local label="${LABEL_PREFIX}.t${index}"
    local plist="$AGENT_DIR/${label}.plist"
    local hour=$(( warn_min / 60 )) minute=$(( warn_min % 60 ))
    local cmd_xml; cmd_xml="$(warning_command "$event_min" | escape_xml)"

    local cal=""
    for wd in 1 2 3 4 5; do
        cal+="        <dict><key>Weekday</key><integer>${wd}</integer><key>Hour</key><integer>${hour}</integer><key>Minute</key><integer>${minute}</integer></dict>"$'\n'
    done

    cat > "$plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${label}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>${cmd_xml}</string>
    </array>
    <key>StartCalendarInterval</key>
    <array>
${cal}    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>ProcessType</key>
    <string>Interactive</string>
</dict>
</plist>
PLIST

    launchctl bootout "gui/${UID_NUM}/${label}" 2>/dev/null || true
    launchctl bootstrap "gui/${UID_NUM}" "$plist"
    printf '  installed: %-24s warns at %s for the %s event (Mon-Fri)\n' \
        "$label" "$(to_clock "$warn_min")" "$(to_clock "$event_min")"
}

# --- arguments ---------------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || die "this installer is for macOS only"

ACTION=install
TIMES=()

while [ $# -gt 0 ]; do
    case "$1" in
        install|uninstall|status|test|disable|enable) ACTION="$1"; shift ;;
        --lead)
            [ $# -ge 2 ] || die "--lead needs a number of minutes"
            [[ "$2" =~ ^[0-9]+$ ]] && (( $2 >= 1 && $2 <= 120 )) || die "--lead must be 1-120 minutes"
            LEAD="$2"; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        -*) die "unknown option '$1'" ;;
        *) TIMES+=("$1"); shift ;;
    esac
done

case "$ACTION" in
    disable)
        # "launchctl disable" is remembered across reboots, so the reminders
        # stay off until "enable" — the plists are left in place.
        found=0
        while read -r label; do
            [ -n "$label" ] || continue
            found=1
            launchctl disable "gui/${UID_NUM}/${label}" 2>/dev/null || true
            launchctl bootout "gui/${UID_NUM}/${label}" 2>/dev/null || true
            echo "  paused: ${label}"
        done < <(installed_labels)
        if [ "$found" = 1 ]; then
            echo "Reminders are off (including after a reboot)."
            echo "Turn them back on with:  bash $0 enable"
        else
            echo "  nothing installed to pause"
        fi
        exit 0 ;;
    enable)
        found=0
        while read -r label; do
            [ -n "$label" ] || continue
            found=1
            launchctl enable "gui/${UID_NUM}/${label}" 2>/dev/null || true
            launchctl bootout "gui/${UID_NUM}/${label}" 2>/dev/null || true
            launchctl bootstrap "gui/${UID_NUM}" "$AGENT_DIR/${label}.plist"
            echo "  resumed: ${label}"
        done < <(installed_labels)
        [ "$found" = 1 ] || echo "  nothing installed — run the installer first"
        exit 0 ;;
    uninstall)
        echo "Removing power-cut reminders..."
        remove_all
        echo "Done."
        exit 0 ;;
    status)
        found=0
        while read -r label; do
            [ -n "$label" ] || continue
            found=1
            plist="$AGENT_DIR/${label}.plist"
            h=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:0:Hour" "$plist" 2>/dev/null || echo "?")
            m=$(/usr/libexec/PlistBuddy -c "Print :StartCalendarInterval:0:Minute" "$plist" 2>/dev/null || echo "?")
            if launchctl print-disabled "gui/${UID_NUM}" 2>/dev/null | grep -q "\"${label}\" => \(disabled\|true\)"; then
                state="PAUSED"
            elif launchctl print "gui/${UID_NUM}/${label}" >/dev/null 2>&1; then
                state="active"
            else
                state="NOT loaded"
            fi
            printf '  %-24s warns %02d:%02d Mon-Fri  (%s)\n' "$label" "$h" "$m" "$state"
        done < <(installed_labels)
        [ "$found" = 1 ] || echo "  no reminders installed"
        exit 0 ;;
esac

[ "${#TIMES[@]}" -gt 0 ] || TIMES=("${DEFAULT_TIMES[@]}")

MINUTES=()
for t in "${TIMES[@]}"; do MINUTES+=("$(to_minutes "$t")"); done

if [ "$ACTION" = "test" ]; then
    echo "Showing a test warning for the ${TIMES[0]} event..."
    POWERCUT_FORCE=1 bash -c "$(warning_command "${MINUTES[0]}")"
    exit 0
fi

mkdir -p "$AGENT_DIR"
echo "Installing power-cut reminders (${LEAD} min before each event)..."
remove_all >/dev/null
i=0
for min in "${MINUTES[@]}"; do
    make_agent "$i" "$min"
    i=$(( i + 1 ))
done

echo
echo "Test the pop-up right now with:"
echo "  bash $0 test ${TIMES[0]}"
echo "The first time, macOS may ask permission for the alert — click Allow."
echo
echo "This is a one-time setup: the reminders survive shutdowns and reboots."
echo "  pause:   bash $0 disable"
echo "  resume:  bash $0 enable"
echo "  remove:  bash $0 uninstall"
