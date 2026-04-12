import QtQuick
import QtQuick.Controls
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property int trashFileCount: 0
    property bool isEmpty: trashFileCount === 0
    property string trashDir: Quickshell.env("HOME") + "/.local/share/Trash/files"
    property var trashDirs: [Quickshell.env("HOME") + "/.local/share/Trash/files"]
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
            "Note: Auto-clean checks and deletes files older than the specified days every 2 seconds.": "说明：自动清理会每2秒定时检查并清理超过指定天数的文件。",
            "1 day": "1天",
            "3 days": "3天",
            "7 days": "7天",
            "15 days": "15天",
            " days": "天"
        }
    })
    property string currentLang: "en"

    Component.onCompleted: {
        // 获取系统语言
        var sysLocale = Qt.locale().name
        var lang = sysLocale.split("_")[0]
        if (lang === "zh") {
            root.currentLang = "zh"
        }
        root.loadSettings()
        root.initTrashDirs()
        root.updateTrashCount()
    }

    // 初始化所有磁盘的回收站目录
    function initTrashDirs() {
        var mountCmd = "findmnt -rn -o TARGET 2>/dev/null | while read mount; do if [ -d \"$mount/.Trash-$UID/files\" ]; then echo \"$mount/.Trash-$UID/files\"; fi; done"
        Proc.runCommand(null, ["sh", "-c", mountCmd], function(output, exitCode) {
            if (exitCode === 0 && output) {
                var dirs = [Quickshell.env("HOME") + "/.local/share/Trash/files"]
                var lines = output.trim().split("\n")
                for (var i = 0; i < lines.length; i++) {
                    var line = lines[i].trim()
                    if (line && dirs.indexOf(line) === -1) {
                        dirs.push(line)
                    }
                }
                root.trashDirs = dirs
                // 重新统计
                root.updateTrashCount()
            }
        }, 0)
    }

    function tr(text) {
        if (root.currentLang === "en") return text
        var dict = root.translations[root.currentLang]
        if (!dict) return text
        return dict[text] || text
    }

    // 自动清理设置
    property bool autoCleanEnabled: false
    property int autoCleanDays: 7

    // 更新回收站文件数量（统计所有磁盘）
    function updateTrashCount() {
        var totalCount = 0
        var checkedCount = 0
        
        for (var i = 0; i < root.trashDirs.length; i++) {
            (function(trashDir) {
                Proc.runCommand(null, ["sh", "-c", "ls -1 '" + trashDir + "' 2>/dev/null | wc -l"], function(output, exitCode) {
                    if (exitCode === 0 && output) {
                        var count = parseInt(output.trim()) || 0
                        totalCount += count
                    }
                    checkedCount++
                    
                    // 所有目录检查完成后更新总数
                    if (checkedCount === root.trashDirs.length) {
                        root.trashFileCount = totalCount
                        
                        if (root.autoCleanEnabled && totalCount > 0) {
                            performAutoClean()
                        }
                    }
                }, 0)
            })(root.trashDirs[i])
        }
    }

    // 加载设置
    function loadSettings() {
        if (typeof PluginService !== "undefined") {
            root.autoCleanEnabled = PluginService.loadPluginData("trashBin", "autoCleanEnabled", false)
            root.autoCleanDays = PluginService.loadPluginData("trashBin", "autoCleanDays", 7)
        }
    }

    // 保存设置
    function saveSetting(key, value) {
        if (typeof PluginService !== "undefined") {
            PluginService.savePluginData("trashBin", key, value)
        }
    }

    // 执行自动清理（所有磁盘）
    function performAutoClean() {
        if (!root.autoCleanEnabled || root.trashFileCount === 0) return

        for (var i = 0; i < root.trashDirs.length; i++) {
            (function(filesDir) {
                var infoDir = filesDir.replace('/files', '/info')
                var cleanCmd =
                    "infoDir='" + infoDir + "'; " +
                    "filesDir='" + filesDir + "'; " +
                    "now=$(date +%s); " +
                    "days=" + root.autoCleanDays + "; " +
                    "for infoFile in \"$infoDir\"/*.trashinfo; do " +
                    "  [ -f \"$infoFile\" ] || continue; " +
                    "  deletionDate=$(grep '^DeletionDate=' \"$infoFile\" | cut -d'=' -f2); " +
                    "  [ -z \"$deletionDate\" ] && continue; " +
                    "  deletionEpoch=$(date -d \"${deletionDate/T/ }\" +%s 2>/dev/null); " +
                    "  [ -z \"$deletionEpoch\" ] && continue; " +
                    "  ageDays=$(( (now - deletionEpoch) / 86400 )); " +
                    "  if [ \"$ageDays\" -ge \"$days\" ]; then " +
                    "    fileName=$(basename \"$infoFile\" .trashinfo); " +
                    "    rm -rf \"$filesDir/$fileName\" 2>/dev/null; " +
                    "    rm -f \"$infoFile\" 2>/dev/null; " +
                    "  fi; " +
                    "done"

                Proc.runCommand(null, ["sh", "-c", cleanCmd], function(output, exitCode) {
                    if (exitCode === 0) {
                        root.updateTrashCount()
                    }
                }, 10000)
            })(root.trashDirs[i])
        }
    }

    // 打开回收站
    function openTrash() {
        Quickshell.execDetached(["thunar", "trash://"])
    }

    // 清空回收站（所有磁盘）
    function emptyTrash() {
        // 立即更新 UI
        root.trashFileCount = 0
        if (root.closePopout) root.closePopout()

        // 后台执行删除，删除所有磁盘的 files 和 info 目录下的所有文件和文件夹
        var notifyTitle = root.tr("Trash Emptied")
        var notifyBody = root.tr("All files in the trash have been permanently deleted.")
        
        var cleanCmd = ""
        for (var i = 0; i < root.trashDirs.length; i++) {
            var filesDir = root.trashDirs[i]
            var infoDir = filesDir.replace('/files', '/info')
            cleanCmd += "rm -rf '" + filesDir + "'/* 2>/dev/null; rm -rf '" + infoDir + "'/* 2>/dev/null; "
        }
        cleanCmd += "notify-send '" + notifyTitle + "' '" + notifyBody + "' --icon=user-trash-full --app-name=DankMaterialShell"
        
        Proc.runCommand(null, ["sh", "-c", cleanCmd], function(output, exitCode) {
            // 删除完成后不需要额外操作，通知已由命令发送
        }, 0)
    }

    // 定时轮询
    Timer {
        id: pollingTimer
        interval: 2000
        repeat: true
        running: true
        onTriggered: root.updateTrashCount()
    }

    // 水平 pill
    horizontalBarPill: Component {
        Image {
            source: root.trashFileCount === 0 ? root.imageBase + "bin-empty.png" : root.imageBase + "bin-full.png"
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // 垂直 pill
    verticalBarPill: Component {
        Image {
            source: root.trashFileCount === 0 ? root.imageBase + "bin-empty.png" : root.imageBase + "bin-full.png"
            sourceSize.width: root.iconSize
            sourceSize.height: root.iconSize
            width: root.iconSize
            height: root.iconSize
            fillMode: Image.PreserveAspectFit
            smooth: true
        }
    }

    // 左键点击打开回收站
    pillClickAction: function() {
        openTrash()
    }

    // 右键点击弹出设置 Popout
    // 注意：需要临时清空 pillClickAction，因为 triggerPopout() 内部会优先调用它
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

                // 清理天数选择（移到顶部以确保下拉菜单有足够空间）
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
                        root.saveSetting("autoCleanDays", root.autoCleanDays)
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceContainerHigh
                }

                // 自动清理开关
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
                            root.saveSetting("autoCleanEnabled", isChecked)
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.surfaceContainerHigh
                }

                // 清空回收站按钮
                DankButton {
                    width: parent.width
                    text: root.tr("Empty Trash")
                    enabled: root.trashFileCount > 0
                    onClicked: root.emptyTrash()
                }

                StyledText {
                    width: parent.width
                    text: root.tr("Note: Auto-clean checks and deletes files older than the specified days every 2 seconds.")
                    font.pixelSize: Theme.fontSizeSmall
                    color: Theme.surfaceVariantText
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
