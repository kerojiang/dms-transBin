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

    // 计数直接绑定 DMS TrashService（FolderListModel watcher + dms trash count，含外部 .Trash-$UID）
    readonly property int trashFileCount: TrashService.count

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

    Component.onCompleted: {
        console.info("[TrashBin] ===== Component.onCompleted =====")
        var sysLocale = Qt.locale().name
        var lang = sysLocale.split("_")[0]
        if (lang === "zh") {
            root.currentLang = "zh"
        }
        console.info("[TrashBin] Locale:", sysLocale, "Lang:", root.currentLang)
        // 加载时校准计数（单次 dms trash count，覆盖外部 .Trash-$UID；主 trash 后续由 FolderListModel 事件驱动）
        TrashService.refreshCount()
    }

    function tr(text) {
        if (root.currentLang === "en") return text
        var dict = root.translations[root.currentLang]
        if (!dict) return text
        return dict[text] || text
    }

    // 打开回收站（复用 DMS TrashService：xdg-open/用户在设置中选择的文件管理器）
    function openTrash() {
        TrashService.openTrash()
    }

    // 清空回收站（复用 DMS TrashService：dms trash empty，失败时由 service 弹出错误 Toast）
    function emptyTrash() {
        if (root.emptyingTrash) {
            console.info("[TrashBin] [EMPTY] 清空操作正在进行中，跳过")
            return
        }
        if (root.trashFileCount === 0) return
        if (root.closePopout) root.closePopout()

        root.emptyingTrash = true
        emptyConfirmTimer.restart()
        TrashService.emptyTrash()
    }

    // 清空结果等待超时兜底：清空失败时复位标记（失败提示由 ToastService 负责）
    Timer {
        id: emptyConfirmTimer
        interval: 15000
        onTriggered: root.emptyingTrash = false
    }

    // 监听 TrashService 计数变化：新增文件播放音效，清空成功后发通知并播放音效
    Connections {
        target: TrashService

        function onCountChanged() {
            var current = TrashService.count
            console.info("[TrashBin] [COUNT] 计数更新:", current)
            if (root.emptyingTrash && current === 0) {
                root.emptyingTrash = false
                emptyConfirmTimer.stop()
                root.playSound(Quickshell.env("HOME") + "/.local/share/sounds/harmony2/stereo/trash-empty.ogg")
                Quickshell.execDetached(["dms", "notify",
                    root.tr("Trash Emptied"),
                    root.tr("All files in the trash have been permanently deleted."),
                    "--icon=user-trash-full"])
            } else if (!root.emptyingTrash && root.lastFileCount !== -1 && current > root.lastFileCount) {
                root.playSound(Quickshell.env("HOME") + "/.local/share/sounds/harmony2/stereo/file-trash.ogg")
            }
            root.lastFileCount = current
        }
    }

    // 清空回收站进行中标记
    property bool emptyingTrash: false

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
            "};\n" +
            "# Main trash\n" +
            "clean_one_dir \"$HOME/.local/share/Trash\";\n" +
            "# External drives\n" +
            "for mp in /home /mnt /media /run/media; do " +
            "  [ -d \"$mp\" ] || continue; " +
            "  find \"$mp\" -maxdepth 4 -type d -name \".Trash-$(id -u)\" -print0 2>/dev/null | " +
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
            // 自动清理可能只删除外部盘 .Trash-$UID 中的项目，主动刷新 TrashService 计数
            TrashService.refreshCount()
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