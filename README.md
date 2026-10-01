# Trash Bin

Monitor and manage your system trash directly from your status bar.

<img width="392" height="426" alt="Screenshot" src="https://github.com/user-attachments/assets/b06f39ed-669f-4505-8c91-ec49f7e658d1" />

## Features

- **Real-time Monitoring**: Event-driven updates via DMS `TrashService` — no polling, no shell process churn.
- **Trash Status Display**: Dynamic icon colors (primary when full, outline when empty).
- **Sound Feedback**: Plays a sound effect when a file is moved to the trash.
- **Quick Access**: Left-click to open the trash in your file manager.
- **Empty Trash**: One-click button to permanently delete all files.
- **Auto-Clean**: Configurable automatic cleanup (hourly) — deletes files older than 1, 3, 7, or 15 days.
- **External Drive Support**: Counts and manages trash directories on external mounts (`/home`, `/mnt`, `/media`, `/run/media`, `.Trash-$UID`).
- **Multi-language Support**: English and Chinese (zh).

## Requirements

- **DankMaterialShell**: The plugin runs within the DankMaterialShell environment and reuses its built-in `TrashService` for counting, opening, and emptying the trash (internal `dms trash count` / `dms trash empty` / `xdg-open`).
- **paplay**: For sound playback (optional, part of PulseAudio; listed in `dependencies`).

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

- **Count Updates**: Bound to DMS `TrashService.count` (backed by a `FolderListModel` watcher on the main trash plus `dms trash count`, which covers external `.Trash-$UID` directories). The count is re-calibrated on plugin load and after each auto-clean run. No background polling.
- **Auto-Clean Interval**: Every hour, with `timeout` (300s) and `ionice` (idle) safeguards.
- **Auto-Clean Mechanism**: Reads `.trashinfo` files, calculates age based on `DeletionDate`, and removes files older than the configured interval.
- **Trash Paths**: `~/.local/share/Trash` and external mount points (`.Trash-$UID`).
- **Sound Files**: `~/.local/share/sounds/harmony2/stereo/file-trash.ogg` (deletion) and `trash-empty.ogg` (empty).

## Changelog

- **v1.4.0**: Replace the 5-second shell polling with DMS `TrashService` event-driven counting; reuse `TrashService` for open/empty (drops the `gio` dependency); declare `dependencies: ["paplay"]`; fix auto-clean no-op (single-line script let a `#` comment swallow the cleanup calls, so hourly cleanups exited 0 without deleting anything).
- **v1.3.1**: Fix auto-clean default inconsistency, add process onExited handlers, remove unnecessary permissions, clean up redundant code.
- **v1.3.0**: Add auto-clean feature with configurable time options.
- **v1.2.0**: Remove trash-cli dependency, use native Linux commands.
- **v1.1.0**: Initial release.

## License

MIT License
