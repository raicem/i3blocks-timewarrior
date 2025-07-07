# Timewarrior i3blocks Integration

A comprehensive integration between [Timewarrior](https://timewarrior.net/) and i3blocks that provides a clickable time tracker in your i3 status bar with automatic pause/resume functionality.

## Features

- **Click to pause/resume**: Left-click the status bar item to pause/resume timers
- **Idle notifications**: Reminds you after 10 minutes of inactivity
- **Auto-pause**: Automatically pauses tasks when system suspends/hibernates/shuts down
- **Status icons**: ⏱️ for active tasks, ⏸️ for paused tasks

## Screenshots

The status bar shows:
- Active timer: `⏱️ work project 01:23:45`
- Paused timer: `⏸️ work project 01:23:45`

## Prerequisites

- [Timewarrior](https://timewarrior.net/) installed
- i3blocks installed 
- jq (for JSON parsing)

## Installation

See [INSTALL.md](INSTALL.md) for detailed installation instructions.

## Quick Start

1. Clone the repository
2. Make scripts executable
3. Install the systemd service for auto-pause
4. Add the block to your i3blocks config
5. Restart i3blocks

## Usage

- **Start tracking**: Use timewarrior normally (`timew start "task name"`)
- **Pause/Resume**: Left-click the status bar item
- **View logs**: Check `~/.timewarrior-suspend.log` for suspend/resume events