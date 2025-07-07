# Timewarrior i3blocks Integration

## Prerequisites

- [Timewarrior](https://timewarrior.net/) installed
- i3blocks installed 
- jq (for JSON parsing)

## Installation

### 1. Clone/Download the repository

```bash
git clone https://github.com/yourusername/timewarrior-i3blocks.git
cd timewarrior-i3blocks
```

### 2. Make scripts executable

```bash
chmod +x timewarrior-i3blocks.sh
chmod +x timewarrior-suspend-handler.sh
```

### 3. Install the systemd service (auto-pause on suspend/hibernate)

```bash
# Create user systemd directory if it doesn't exist
mkdir -p ~/.config/systemd/user

# Copy the service file to user systemd directory
cp timewarrior-suspend.service ~/.config/systemd/user/

# Edit the service file to update the path to your installation
# Update the ExecStart line to point to your timewarrior-suspend-handler.sh location
sed -i "s|/home/raicem/projects/timewarrior-i3blocks/|$(pwd)/|g" ~/.config/systemd/user/timewarrior-suspend.service

# Enable and start the service for your user
systemctl --user enable timewarrior-suspend.service
systemctl --user start timewarrior-suspend.service

# Check status
systemctl --user status timewarrior-suspend.service
```

### 4. Configure i3blocks

Add this block to your i3blocks configuration (usually `~/.config/i3blocks/config`):

```
[timewarrior]
command=/path/to/timewarrior-i3blocks/timewarrior-i3blocks.sh
interval=1
signal=10
```

Replace `/path/to/timewarrior-i3blocks/` with the actual path to your installation.

Then restart i3blocks:
```bash
killall i3blocks && i3blocks &
```

## Features

- **Click to pause/resume**: Left-click the status bar item to pause/resume timers
- **Idle notifications**: Reminds you after 10 minutes of inactivity
- **Auto-pause**: Automatically pauses tasks when system suspends/hibernates/shuts down
- **Status icons**: ⏱️ for active tasks, ⏸️ for paused tasks

## Logs

System suspend/resume events are logged to `~/.timewarrior-suspend.log`
