import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "trashBin"

    // 多语言翻译
    property var translations: ({
        "zh": {
            "Trash Auto-Clean Settings": "回收站自动清理设置",
            "Configure rules for automatically cleaning up old files in the trash.": "配置自动清理回收站中旧文件的规则",
            "Enable Auto-Clean": "启用自动清理",
            "Automatically clean up old files in the trash on a regular basis.": "定期自动清理回收站中的旧文件",
            "Clean-up Days": "清理天数",
            "Delete files older than the specified number of days.": "清理超过指定天数的文件",
            "Note: Auto-clean checks and deletes files older than the specified days every 2 seconds.": "说明：自动清理会每2秒定时检查并清理超过指定天数的文件。",
            "1 day": "1天",
            "3 days": "3天",
            "7 days": "7天",
            "15 days": "15天"
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
    }

    function tr(text) {
        if (root.currentLang === "en") return text
        var dict = root.translations[root.currentLang]
        if (!dict) return text
        return dict[text] || text
    }

    // 标题
    StyledText {
        width: parent.width
        text: root.tr("Trash Auto-Clean Settings")
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: root.tr("Configure rules for automatically cleaning up old files in the trash.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    // 自动清理开关
    ToggleSetting {
        settingKey: "autoCleanEnabled"
        label: root.tr("Enable Auto-Clean")
        description: root.tr("Automatically clean up old files in the trash on a regular basis.")
        defaultValue: false
    }

    // 清理天数选项
    SelectionSetting {
        id: cleanDaysSetting
        settingKey: "autoCleanDays"
        label: root.tr("Clean-up Days")
        description: root.tr("Delete files older than the specified number of days.")
        defaultValue: root.tr("7 days")
        options: [root.tr("1 day"), root.tr("3 days"), root.tr("7 days"), root.tr("15 days")]
    }

    // 说明信息
    StyledText {
        width: parent.width
        text: root.tr("Note: Auto-clean checks and deletes files older than the specified days each time the trash status is updated.")
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }
}
