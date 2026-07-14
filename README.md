# Trash Bin

Monitor and manage your system trash directly from your status bar.

<img width="392" height="426" alt="Screenshot" src="https://github.com/user-attachments/assets/b06f39ed-669f-4505-8c91-ec49f7e658d1" />

## Features

- **Real-time Monitoring**: Poll-based updates every 5 seconds for instant trash status detection.
- **Trash Status Display**: Dynamic icon colors (primary when full, outline when empty).
- **Sound Feedback**: Plays a sound effect when a file is moved to the trash.
- **Quick Access**: Left-click to open the trash in your file manager.
- **Empty Trash**: One-click button to permanently delete all files.
- **Auto-Clean**: Configurable automatic cleanup (hourly) — deletes files older than 1, 3, 7, or 15 days.
- **External Drive Support**: Detects and manages trash directories on external mounts (`/mnt`, `/media`, `/run/media`).
- **Multi-language Support**: English and Chinese (zh).

## Requirements

- **DankMaterialShell**: The plugin runs within the DankMaterialShell environment.
- **gio**: For trash operations (list, empty, open).
- **paplay**: For sound playback (optional, part of PulseAudio).
- **notify-send** or **dms notify**: For desktop notifications when trash is emptied.

## Configuration

1. Go to **Plugin Settings**.
2. Enable **Auto-Clean** if you want automatic cleanup of old files.
3. Select the **Clean-up Days** interval (1, 3, 7, or 15 days).
4. Settings are saved automatically and persisted across sessions.

## Usage

- **Left-click**: Open the trash in your file manager.
- **Right-click**: Open the settings popout to configure auto-clean options and empty the trash.
- **Status Bar Icon**: Changes color between empty (dimmed) and full (accent) states.

## Permissions

- `settings_read` / `settings_write`: For storing auto-clean preferences.
- `process`: For executing shell commands (trash count, auto-clean, empty trash).

## Technical Details

- **Polling Interval**: 5 seconds for trash status updates.
- **Auto-Clean Interval**: Every hour, with `timeout` (300s) and `ionice` (idle) safeguards.
- **Auto-Clean Mechanism**: Reads `.trashinfo` files, calculates age based on `DeletionDate`, and removes files older than the configured interval.
- **Trash Paths**: `~/.local/share/Trash` and external mount points (`.Trash-$UID`).
- **Sound Files**: `~/.local/share/sounds/harmony2/stereo/file-trash.ogg` (deletion) and `trash-empty.ogg` (empty).

## Changelog

- **v1.3.1**: Fix auto-clean default inconsistency, add process onExited handlers, remove unnecessary permissions, clean up redundant code.
- **v1.3.0**: Add auto-clean feature with configurable time options.
- **v1.2.0**: Remove trash-cli dependency, use native Linux commands.
- **v1.1.0**: Initial release.

## License

MIT License
