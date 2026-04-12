# 回收站 (Trash Bin)

Monitor and manage your system trash directly from your status bar.



<img width="392" height="426" alt="3" src="https://github.com/user-attachments/assets/b06f39ed-669f-4505-8c91-ec49f7e658d1" />

## Features

- **Real-time Monitoring**: Poll-based updates for instant trash status changes.
- **Trash Status Display**: Shows whether the trash is empty or contains files with dynamic icons.
- **Quick Access**: Left-click to open the trash in your file manager (Thunar).
- **Empty Trash**: One-click button to permanently delete all files in the trash.
- **Auto-Clean**: Configure automatic cleanup rules to delete files older than a specified number of days.
- **Editing Mode**: Customize clean-up intervals (1, 3, 7, or 15 days) via settings popout.
- **Multi-language Support**: Built-in Chinese (zh) and English (en) translations.

## Requirements

- **System Package**: `thunar` (or another file manager supporting `trash://` protocol) for opening the trash.
- **notify-send**: For desktop notifications when trash is emptied.
- **DankMaterialShell**: The plugin runs within the DankMaterialShell environment.

## Configuration

1. Go to **Plugin Settings**.
2. Enable **Auto-Clean** if you want automatic cleanup of old files.
3. Select the **Clean-up Days** interval (1, 3, 7, or 15 days).
4. Settings are saved automatically and persisted across sessions.

## Usage

- **Left-click**: Open the trash in your file manager.
- **Right-click**: Open the settings popout to configure auto-clean options and empty the trash.
- **Status Bar Icon**: Dynamically changes between empty and full icons based on trash content.

## Permissions

- `settings_read` / `settings_write`: For storing auto-clean preferences.
- `process`: For executing shell commands (trash count, auto-clean, empty trash).
- `network`: Required by the plugin system.

## Technical Details

- **Polling Interval**: 2 seconds for trash status updates.
- **Auto-Clean Mechanism**: Reads `.trashinfo` files, calculates age based on `DeletionDate`, and removes files older than the configured interval.
- **Trash Path**: `~/.local/share/Trash/files` (FreeDesktop.org Trash specification).

## Feedback & Contributions

Suggestions for improvements and feature requests are always welcome.
If you have ideas, encounter issues, or want to see new features, feel free to open an issue or submit a pull request.
