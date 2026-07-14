import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int trashFileCount: 0

    // 多语言翻译
    property var translations: ({
        "zh": {
            "Trash Emptied": "回收站已清空",
            "All files in the trash have been permanently deleted.": "回收站中的所有文件已被永久删除。",
            "Trash Auto-Clean Settings": "回收站自动清理设置",
            "Enable Auto-Clean": "启用自动清理",
            "Clean-up Days": "清理天数",
            "Delete files older than specified days": "清理超过指定天数的文件",
            "Empty Trash": "清空回收站",
            "Note: Auto-clean checks and deletes files older than the specified days every hour.": "说明：自动清理会每小时检查并清理超过指定天数的文件。",
            "1 day": "1天",
            "3 days": "3天",
            "7 days": "7天",
            "15 days": "15天",
            " days": "天"
        }
    })
    property string currentLang: "en"

    // 从 pluginData 读取设置（框架自动绑定）
    property bool autoCleanEnabled: pluginData.autoCleanEnabled ?? false
    property int autoCleanDays: typeof pluginData.autoCleanDays === 'number'
        ? pluginData.autoCleanDays
        : parseInt(pluginData.autoCleanDays) || 7

    // 共享的回收站文件计数 shell 命令
    function trashCountCommand() {
        return [
            "sh", "-c",
            "{ " +
            "  [ -d \"$HOME/.local/share/Trash/files\" ] && ls -1A \"$HOME/.local/share/Trash/files\" 2>/dev/null; " +
            "  for mp in /home /mnt /media /run/media; do " +
            "    [ -d \"$mp\" ] || continue; " +
            "    find \"$mp\" -xdev -maxdepth 4 -type d -name \".Trash-$(id -u)\" -print0 2>/dev/null | " +
            "    while IFS= read -r -d '' td; do " +
            "      [ -d \"$td/files\" ] && ls -1A \"$td/files\" 2>/dev/null; " +
            "    done; " +
            "  done; " +
            "} | wc -l"
        ]
    }

    Component.onCompleted: {
        console.info("[TrashBin] ===== Component.onCompleted =====")
        var sysLocale = Qt.locale().name
        var lang = sysLocale.split("_")[0]
        if (lang === "zh") {
            root.currentLang = "zh"
        }
        console.info("[TrashBin] Locale:", sysLocale, "Lang:", root.currentLang)
        Qt.callLater(root.updateTrashCount)
    }

    function updateTrashCount() {
        console.info("[TrashBin] [UPDATE] ===== 开始更新计数 =====")
        if (countProcess.running) {
            console.info("[TrashBin] [UPDATE] countProcess 已在运行，跳过")
            return
        }
        console.info("[TrashBin] [UPDATE] 启动 countProcess")
        countProcess.running = true
    }

    Process {
        id: countProcess
        command: root.trashCountCommand()
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                console.info("[TrashBin] [COUNT] 原始输出:", line)
                var count = parseInt(line.trim()) || 0
                console.info("[TrashBin] [COUNT] 解析后的计数:", count)
                root.trashFileCount = count
                root.lastFileCount = count
            }
        }

        onExited: function(exitCode, exitStatus) {
            console.info("[TrashBin] [COUNT] 进程退出，退出码:", exitCode, "状态:", exitStatus)
        }
    }

    function tr(text) {
        if (root.currentLang === "en") return text
        var dict = root.translations[root.currentLang]
        if (!dict) return text
        return dict[text] || text
    }

    // 打开回收站
    function openTrash() {
        Quickshell.execDetached(["sh", "-c", "gio open trash://"])
    }

    function emptyTrash() {
        if (emptyProcess.running) {
            console.info("[TrashBin] [EMPTY] 清空操作正在进行中，跳过")
            return
        }
        if (root.closePopout) root.closePopout()

        var notifyTitle = root.tr("Trash Emptied")
        var notifyBody = root.tr("All files in the trash have been permanently deleted.")

        emptyProcess.command = ["sh", "-c", "gio trash --empty 2>/dev/null && dms notify \"" + notifyTitle + "\" \"" + notifyBody + "\" --icon=user-trash-full"]
        emptyProcess.running = true
    }

    Process {
        id: emptyProcess
        running: false

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                root.trashFileCount = 0
                root.playSound(Quickshell.env("HOME") + "/.local/share/sounds/harmony2/stereo/trash-empty.ogg")
            }
        }
    }

    function performAutoClean() {
        if (!root.autoCleanEnabled) return
        if (cleanProcess.running) {
            console.info("[TrashBin] [AUTOCLEAN] 上一次清理未完成，跳过本次触发")
            return
        }
        var days = root.autoCleanDays
        console.info("[TrashBin] [AUTOCLEAN] 启动自动清理，天数:", days)
        cleanProcess.command = ["timeout", "300", "ionice", "-c", "3", "sh", "-c",
            "now=$(date +%s); " +
            "today=$(date -d \"$(date +%Y-%m-%d)\" +%s); " +
            "days=" + days + "; " +
            "clean_one_dir() { " +
            "  trashDir=\"$1/files\"; infoDir=\"$1/info\"; " +
            "  [ -d \"$trashDir\" ] || return 0; " +
            "  [ -d \"$infoDir\" ] || return 0; " +
            "  find \"$infoDir\" -mindepth 1 -maxdepth 1 -name '*.trashinfo' -print0 2>/dev/null | " +
            "  while IFS= read -r -d '' infoFile; do " +
            "    deletionDate=$(grep '^DeletionDate=' \"$infoFile\" | cut -d'=' -f2); " +
            "    [ -z \"$deletionDate\" ] && continue; " +
            "    deletionDateOnly=$(echo \"$deletionDate\" | cut -d'T' -f1); " +
            "    deletionEpoch=$(date -d \"$deletionDateOnly\" +%s 2>/dev/null); " +
            "    [ -z \"$deletionEpoch\" ] && continue; " +
            "    ageDays=$(( (today - deletionEpoch) / 86400 )); " +
            "    if [ \"$ageDays\" -ge \"$days\" ]; then " +
            "      fileName=$(basename \"$infoFile\" .trashinfo); " +
            "      rm -rf -- \"$trashDir/$fileName\" 2>/dev/null; " +
            "      rm -f \"$infoFile\" 2>/dev/null; " +
            "    fi; " +
            "  done; " +
            "}; " +
            "# Main trash " +
            "clean_one_dir \"$HOME/.local/share/Trash\"; " +
            "# External drives " +
            "for mp in /home /mnt /media /run/media; do " +
            "  [ -d \"$mp\" ] || continue; " +
            "  find \"$mp\" -xdev -maxdepth 4 -type d -name \".Trash-$(id -u)\" -print0 2>/dev/null | " +
            "  while IFS= read -r -d '' td; do " +
            "    clean_one_dir \"$td\"; " +
            "  done; " +
            "done"
        ]
        cleanProcess.running = true
    }

    Process {
        id: cleanProcess
        running: false

        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0) {
                console.info("[TrashBin] [AUTOCLEAN] 自动清理完成")
            } else {
                console.warn("[TrashBin] [AUTOCLEAN] 自动清理失败，退出码:", exitCode)
            }
        }
    }

    property int lastFileCount: -1

    // 播放音效（文件不存在则跳过）
    function playSound(soundFile) {
        Quickshell.execDetached(["sh", "-c", "[ -f \"" + soundFile + "\" ] && paplay \"" + soundFile + "\""])
    }

    // 轮询回收站目录变化（每 5 秒）
    Timer {
        id: pollTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: {
            if (pollProcess.running) return
            pollProcess.running = true
        }
    }

    // 自动清理定时器（每小时）
    Timer {
        id: autoCleanTimer
        interval: 3600000
        repeat: true
        running: true
        onTriggered: {
            console.info("[TrashBin] [AUTOCLEAN] 定时触发自动清理")
            root.performAutoClean()
        }
    }

    Process {
        id: pollProcess
        command: root.trashCountCommand()
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                var currentCount = parseInt(line.trim()) || 0
                if (root.lastFileCount === -1) {
                    root.lastFileCount = currentCount
                    return
                }
                if (currentCount !== root.lastFileCount) {
                    console.info("[TrashBin] [POLL] ===== 检测到文件数量变化 =====")
                    console.info("[TrashBin] [POLL] 之前:", root.lastFileCount, "现在:", currentCount)

                    if (currentCount > root.lastFileCount) {
                        root.playSound(Quickshell.env("HOME") + "/.local/share/sounds/harmony2/stereo/file-trash.ogg")
                    }

                    root.trashFileCount = currentCount
                    root.lastFileCount = currentCount
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                console.warn("[TrashBin] [POLL] 轮询进程异常退出，退出码:", exitCode)
            }
        }
    }

    // 水平 pill
    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            DankIcon {
                name: "delete"
                size: Theme.iconSize
                color: root.trashFileCount > 0 ? Theme.primary : Theme.outline
            }
        }
    }

    // 垂直 pill
    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            DankIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: "delete"
                size: Theme.iconSize
                color: root.trashFileCount > 0 ? Theme.primary : Theme.outline
            }
        }
    }

    // 左键点击打开回收站
    pillClickAction: function() {
        openTrash()
    }

    // 右键点击弹出设置 Popout
    pillRightClickAction: function() {
        var saved = root.pillClickAction
        root.pillClickAction = null
        root.triggerPopout()
        root.pillClickAction = saved
    }

    // 设置 Popout
    popoutWidth: 350
    popoutHeight: 320

    popoutContent: Component {
        PopoutComponent {
            headerText: root.tr("Trash Auto-Clean Settings")
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                DankDropdown {
                    width: parent.width
                    text: root.tr("Clean-up Days")
                    description: root.tr("Delete files older than specified days")
                    currentValue: root.autoCleanDays + root.tr(" days", "time unit")
                    options: [root.tr("1 day"), root.tr("3 days"), root.tr("7 days"), root.tr("15 days")]
                    onValueChanged: function(newValue) {
                        var m = {}
                        m[root.tr("1 day")] = 1
                        m[root.tr("3 days")] = 3
                        m[root.tr("7 days")] = 7
                        m[root.tr("15 days")] = 15
                        root.autoCleanDays = m[newValue] || 7
                        if (pluginService) {
                            pluginService.savePluginData(pluginId, "autoCleanDays", root.autoCleanDays)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceContainerHigh
                }

                Rectangle {
                    width: parent.width
                    height: 50
                    color: "transparent"

                    StyledText {
                        anchors.left: parent.left
                        anchors.leftMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.tr("Enable Auto-Clean")
                        font.pixelSize: Theme.fontSizeMedium
                        color: Theme.surfaceText
                    }

                    DankToggle {
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingS
                        anchors.verticalCenter: parent.verticalCenter
                        checked: root.autoCleanEnabled
                        onToggled: function(isChecked) {
                            root.autoCleanEnabled = isChecked
                            if (pluginService) {
                                pluginService.savePluginData(pluginId, "autoCleanEnabled", isChecked)
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceContainerHigh
                }

                DankButton {
                    width: parent.width
                    text: root.tr("Empty Trash")
                    enabled: root.trashFileCount > 0
                    onClicked: root.emptyTrash()
                }

                StyledText {
                    width: parent.width
                    text: root.tr("Note: Auto-clean checks and deletes files older than the specified days every hour.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}