#!/bin/bash

# timewarrior-i3blocks.sh
# A script to show current timewarrior task in i3blocks
# Left click pauses/resumes the current timer

# Function to convert ISO timestamp to epoch
iso_to_epoch() {
    date -d "$1" +%s 2>/dev/null || echo 0
}

# Function to format duration as HH:MM:SS
format_duration() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(((seconds % 3600) / 60))
    local secs=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $secs
}

# Handle click events
case $BLOCK_BUTTON in
    1) # Left click - pause/resume timer
        if timew export | jq -e '.[] | select(has("end") | not)' >/dev/null 2>&1; then
            # Timer is active, get the current task info and pause it
            current_tags=$(timew export | jq -r '.[] | select(has("end") | not) | .tags // [] | join(" ")')
            timew stop >/dev/null 2>&1
            # Store the paused task tags for display
            echo "$current_tags" > /tmp/timewarrior_paused_task
        else
            # No active timer, try to resume the last task
            timew continue >/dev/null 2>&1
            # Clean up the paused task file
            rm -f /tmp/timewarrior_paused_task
        fi
        ;;
esac

# Get current timewarrior data
timew_data=$(timew export 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$timew_data" ]; then
    echo "No timewarrior"
    exit 0
fi

# Find active task (one without "end" field)
active_task=$(echo "$timew_data" | jq -r '.[] | select(has("end") | not)')

# Function to check and send idle notification
check_idle_notification() {
    local idle_file="/tmp/timewarrior_idle_start"
    local current_time=$(date +%s)
    
    if [ -z "$active_task" ] && [ ! -f /tmp/timewarrior_paused_task ]; then
        # No active task and no paused task - truly idle
        if [ ! -f "$idle_file" ]; then
            # Start tracking idle time
            echo "$current_time" > "$idle_file"
        else
            # Check if we've been idle for more than 60 seconds
            local idle_start=$(cat "$idle_file" 2>/dev/null || echo "$current_time")
            local idle_duration=$((current_time - idle_start))
            
            if [ "$idle_duration" -gt 600 ]; then
                # Send notification and reset timer
                notify-send "⏱️ Timewarrior Reminder" "You haven't been tracking time for a while. What are you working on?" --urgency=low --app-name="timewarrior" 2>/dev/null
                echo "$current_time" > "$idle_file"
            fi
        fi
    else
        # Active or paused task - reset idle timer
        rm -f "$idle_file"
    fi
}

# Check for idle notification (but don't output anything from this)
check_idle_notification >/dev/null 2>&1

if [ -z "$active_task" ]; then
    # No active task, check if we have a paused task stored
    if [ -f /tmp/timewarrior_paused_task ]; then
        paused_tags=$(cat /tmp/timewarrior_paused_task)
        if [ -n "$paused_tags" ]; then
            task_name="$paused_tags"
            # Calculate total time for paused task
            total_paused_duration=$(echo "$timew_data" | jq -r --arg task_tags "$paused_tags" '
                map(select(has("end") and (.tags // [] | join(" ") == $task_tags))) | 
                map((.end | strptime("%Y%m%dT%H%M%SZ") | mktime) - (.start | strptime("%Y%m%dT%H%M%SZ") | mktime)) | 
                add // 0
            ')
            duration_str=$(format_duration $total_paused_duration)
            echo "⏸️ $task_name ($duration_str)"
        else
            echo "⏸️ Working (paused)"
        fi
    else
        # No stored paused task - truly idle
        echo "No active task"
    fi
    exit 0
fi

# Extract task information
start_time=$(echo "$active_task" | jq -r '.start')
tags=$(echo "$active_task" | jq -r '.tags // [] | join(" ")')

# Convert timewarrior timestamp format (20250707T142832Z) to standard ISO format
start_iso=$(echo "$start_time" | sed 's/\([0-9]\{8\}\)T\([0-9]\{6\}\)Z/\1T\2Z/' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)T\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)Z/\1-\2-\3T\4:\5:\6Z/')

# Calculate total duration for this task (including previous sessions)
current_session_start=$(iso_to_epoch "$start_iso")
current_epoch=$(date +%s)
current_session_duration=$((current_epoch - current_session_start))

# Get total duration for all completed sessions of this task
if [ -n "$tags" ]; then
    task_name="$tags"
    # Calculate total time from all previous sessions with the same tags
    total_previous_duration=$(echo "$timew_data" | jq -r --arg task_tags "$tags" '
        map(select(has("end") and (.tags // [] | join(" ") == $task_tags))) | 
        map((.end | strptime("%Y%m%dT%H%M%SZ") | mktime) - (.start | strptime("%Y%m%dT%H%M%SZ") | mktime)) | 
        add // 0
    ')
else
    task_name="Working"
    total_previous_duration=0
fi

total_duration=$((total_previous_duration + current_session_duration))
duration_str=$(format_duration $total_duration)

echo "⏱️ $task_name ($duration_str)"