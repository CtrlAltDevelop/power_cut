#!/bin/bash
# power-cut-menu.command
# Double-click this file in Finder to set up, pause, or remove the power-cut
# reminders without typing anything.

cd "$(dirname "$0")" || exit 1
INSTALLER="./install-mac-reminders.sh"

[ -f "$INSTALLER" ] || {
    echo "Cannot find install-mac-reminders.sh next to this file."
    echo "Keep both files in the same folder."
    read -r -p "Press Return to close. "
    exit 1
}

while true; do
    clear
    echo "================================================"
    echo "  Power Cut Reminders"
    echo "================================================"
    echo
    bash "$INSTALLER" status
    echo
    echo "  1)  Set up / update reminders (10:00 and 12:00)"
    echo "  2)  Set up with my own times"
    echo "  3)  Show a test pop-up now"
    echo "  4)  Pause the reminders (keeps the setup)"
    echo "  5)  Resume the reminders"
    echo "  6)  Remove the reminders completely"
    echo "  q)  Quit"
    echo
    read -r -p "Choose: " choice
    echo

    case "$choice" in
        1) bash "$INSTALLER" 10:00 12:00 ;;
        2)
            read -r -p "Times, 24-hour, separated by spaces (e.g. 10:00 12:00): " -a times
            read -r -p "How many minutes of warning [2]: " lead
            [ -n "$lead" ] || lead=2
            if [ "${#times[@]}" -eq 0 ]; then
                echo "No times entered."
            else
                bash "$INSTALLER" --lead "$lead" "${times[@]}"
            fi ;;
        3) bash "$INSTALLER" test ;;
        4) bash "$INSTALLER" disable ;;
        5) bash "$INSTALLER" enable ;;
        6)
            read -r -p "Really remove all power-cut reminders? [y/N]: " yes
            case "$yes" in
                [yY]*) bash "$INSTALLER" uninstall ;;
                *)     echo "Cancelled — nothing was changed." ;;
            esac ;;
        q|Q) exit 0 ;;
        *) echo "Please choose 1-6 or q." ;;
    esac

    echo
    read -r -p "Press Return to go back to the menu. "
done
