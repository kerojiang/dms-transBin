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
    property bool isEmpty: trashFileCount === 0
    property string imageBase: Qt.resolvedUrl("./images/")

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
            "Note: Auto-clean checks and deletes files older than the specified days every 5 seconds.": "说明：自动清理会每5秒定时检查并清理超过指定天数的文件。",
            "1 day": "1天",
            "3 days": "3天",
            "7 days": "7天",
            "15 days": "15天",
            " days": "天"
        }
    })
    property string currentLang: "en"

    // 从 pluginData 读取设置（框架自动绑定）
    property bool autoCleanEnabled: pluginData.autoCleanEnabled ?? true
    property int autoCleanDays: parseInt(pluginData.autoCleanDays) ?? 1

    property int tempTrashCount: 0

    Component.onCompleted: {
        var sysLocale = Qt.locale().name
        var lang = sysLocale.split("_")[0]
        if (lang === "zh") {
            root.currentLang = "zh"
        }
        Qt.callLater(root.updateTrashCount)
    }

    function updateTrashCount() {
        countProcess.running = true
    }

    Process {
        id: countProcess
        command: ["sh", "-c", "gio trash --list 2>/dev/null | wc -l"]
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                root.trashFileCount = parseInt(line.trim()) || 0
            }
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
        Quickshell.execDetached(["thunar", "trash://"])
    }

    function emptyTrash() {
        root.trashFileCount = 0
        if (root.closePopout) root.closePopout()

        var notifyTitle = root.tr("Trash Emptied")
        var notifyBody = root.tr("All files in the trash have been permanently deleted.")

        emptyProcess.command = ["sh", "-c", "gio trash --empty 2>/dev/null && notify-send '" + notifyTitle + "' '" + notifyBody + "' --icon=user-trash-full --app-name=DankMaterialShell"]
        emptyProcess.running = true
    }

    Process {
        id: emptyProcess
        running: false
    }

    function performAutoClean() {
        if (!root.autoCleanEnabled) return
        var days = root.autoCleanDays
        var homeTrash = Quickshell.env("HOME") + "/.local/share/Trash"
        cleanProcess.command = ["sh", "-c",
            "now=$(date +%s); " +
            "days=" + days + "; " +
            "for trashDir in ~/.local/share/Trash/files /run/media/*/.Trash-$(id -u)/files; do " +
            "  [ -d \"$trashDir\" ] || continue; " +
            "  infoDir=$(echo \"$trashDir\" | sed 's|/files|/info|'); " +
            "  [ -d \"$infoDir\" ] || continue; " +
            "  find \"$infoDir\" -mindepth 1 -maxdepth 1 -name '*.trashinfo' -print0 2>/dev/null | " +
            "  while IFS= read -r -d '' infoFile; do " +
            "    deletionDate=$(grep '^DeletionDate=' \"$infoFile\" | cut -d'=' -f2); " +
            "    [ -z \"$deletionDate\" ] && continue; " +
            "    deletionEpoch=$(date -d \"${deletionDate/T/ }\" +%s 2>/dev/null); " +
            "    [ -z \"$deletionEpoch\" ] && continue; " +
            "    ageDays=$(( (now - deletionEpoch) / 86400 )); " +
            "    if [ \"$ageDays\" -ge \"$days\" ]; then " +
            "      fileName=$(basename \"$infoFile\" .trashinfo); " +
            "      rm -rf \"$trashDir/$fileName\" 2>/dev/null; " +
            "      rm -f \"$infoFile\" 2>/dev/null; " +
            "    fi; " +
            "  done; " +
            "done"
        ]
        cleanProcess.running = true
    }

    Process {
        id: cleanProcess
        running: false
    }

    Timer {
        id: autoCleanTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: {
            if (root.autoCleanEnabled && !cleanProcess.running) {
                root.performAutoClean()
            }
        }
    }

    Timer {
        id: pollingTimer
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.updateTrashCount()
    }

    // 水平 pill
    horizontalBarPill: Component {
        Image {
            source: root.trashFileCount === 0 ? root.imageBase + "bin-empty.png" : root.imageBase + "bin-full.png"
            sourceSize.width: Theme.iconSize
            sourceSize.height: Theme.iconSize
            width: Theme.iconSize
            height: Theme.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // 垂直 pill
    verticalBarPill: Component {
        Image {
            source: root.trashFileCount === 0 ? root.imageBase + "bin-empty.png" : root.imageBase + "bin-full.png"
            sourceSize.width: Theme.iconSize
            sourceSize.height: Theme.iconSize
            width: Theme.iconSize
            height: Theme.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
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
    popoutHeight: 280

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
                    text: root.tr("Note: Auto-clean checks and deletes files older than the specified days every 5 seconds.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
