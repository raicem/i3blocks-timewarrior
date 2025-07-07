#!/bin/bash

# timewarrior-suspend-handler.sh
# Automatically pause timewarrior when system suspends/hibernates/shuts down

# Function to pause timewarrior
pause_timewarrior() {
    # Check if there's an active task
    if timew export 2>/dev/null | jq -e '.[] | select(has("end") | not)' >/dev/null 2>&1; then
        # Get current task info before pausing
        current_tags=$(timew export 2>/dev/null | jq -r '.[] | select(has("end") | not) | .tags // [] | join(" ")')
        
        # Pause the task
        timew stop >/dev/null 2>&1
        
        # Store the paused task info
        echo "$current_tags" > /tmp/timewarrior_paused_task
        
        # Log the action
        echo "$(date): Paused timewarrior task: $current_tags" >> "$HOME/.timewarrior-suspend.log"
    fi
}

case "$1" in
    pre)
        # Before suspend/hibernate/poweroff
        pause_timewarrior
        # Fork to background to satisfy systemd Type=forking
        exit 0
        ;;
    post)
        # After resume - restart the paused task
        if [ -f /tmp/timewarrior_paused_task ]; then
            tags=$(cat /tmp/timewarrior_paused_task)
            if [ -n "$tags" ]; then
                timew start $tags >/dev/null 2>&1
                echo "$(date): Resumed timewarrior task: $tags" >> "$HOME/.timewarrior-suspend.log"
            fi
            rm -f /tmp/timewarrior_paused_task
        fi
        echo "$(date): System resumed" >> "$HOME/.timewarrior-suspend.log"
        ;;
esac