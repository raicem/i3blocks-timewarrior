#!/bin/bash

# timewarrior-i3blocks.sh
# A script to show current timewarrior task in i3blocks
# Left click pauses/resumes the current timer

# Load configuration
load_config() {
    # Set default values
    IDLE_NOTIFICATION_INTERVAL=600  # 10 minutes default
    LONG_TASK_NOTIFICATION_INTERVAL=3600  # 60 minutes default
    
    # XDG config directory
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/timewarrior-i3blocks"
    local config_file="$config_dir/config"
    
    if [ -f "$config_file" ]; then
        # Source the config file safely
        while IFS='=' read -r key value; do
            # Skip empty lines and comments
            [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
            
            # Remove leading/trailing whitespace and quotes
            key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//;s/^["'"'"']//;s/["'"'"']$//')
            
            case "$key" in
                "idle_notification_interval")
                    IDLE_NOTIFICATION_INTERVAL="$value"
                    ;;
                "long_task_notification_interval")
                    LONG_TASK_NOTIFICATION_INTERVAL="$value"
                    ;;
            esac
        done < "$config_file"
    fi
}

# Load configuration at startup
load_config

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
            
            if [ "$idle_duration" -gt "$IDLE_NOTIFICATION_INTERVAL" ]; then
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

# Function to check for long task duration and send notification
check_long_task_notification() {
    local long_task_file="/tmp/timewarrior_long_task_notified"
    local current_time=$(date +%s)
    
    if [ -n "$active_task" ]; then
        # We have an active task, check its duration
        local start_time=$(echo "$active_task" | jq -r '.start')
        local start_iso=$(echo "$start_time" | sed 's/\([0-9]\{8\}\)T\([0-9]\{6\}\)Z/\1T\2Z/' | sed 's/\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)T\([0-9]\{2\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)Z/\1-\2-\3T\4:\5:\6Z/')
        local task_start=$(iso_to_epoch "$start_iso")
        local task_duration=$((current_time - task_start))
        
        # Check if task has been running for more than the configured long task interval
        if [ "$task_duration" -gt "$LONG_TASK_NOTIFICATION_INTERVAL" ]; then
            # Check if we've already notified for this task session
            if [ ! -f "$long_task_file" ] || [ "$(cat "$long_task_file" 2>/dev/null)" != "$task_start" ]; then
                # Get task name for notification
                local tags=$(echo "$active_task" | jq -r '.tags // [] | join(" ")')
                local task_name="${tags:-Working}"
                
                # Send notification
                local minutes=$((LONG_TASK_NOTIFICATION_INTERVAL / 60))
                notify-send "⏱️ Long Task Alert" "You've been working on '$task_name' for over $minutes minutes. Consider taking a break!" --urgency=normal --app-name="timewarrior" 2>/dev/null
                
                # Mark this task session as notified
                echo "$task_start" > "$long_task_file"
            fi
        fi
    else
        # No active task - clean up notification file
        rm -f "$long_task_file"
    fi
}

# Check for idle notification (but don't output anything from this)
check_idle_notification >/dev/null 2>&1

# Check for long task notification (but don't output anything from this)
check_long_task_notification >/dev/null 2>&1

if [ -z "$active_task" ]; then
    # No active task, check if we have a paused task stored
    if [ -f /tmp/timewarrior_paused_task ]; then
        paused_tags=$(cat /tmp/timewarrior_paused_task)
        if [ -n "$paused_tags" ]; then
            task_name="$paused_tags"
            echo "⏸️ $task_name (paused)"
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

# Calculate current session duration only
current_session_start=$(iso_to_epoch "$start_iso")
current_epoch=$(date +%s)
current_session_duration=$((current_epoch - current_session_start))

# Set task name
if [ -n "$tags" ]; then
    task_name="$tags"
else
    task_name="Working"
fi

duration_str=$(format_duration $current_session_duration)

echo "⏱️ $task_name ($duration_str)"