import QtQuick
import QtQuick.Layouts

// Live look settings (until the next config reload) and night light
ColumnLayout {
    id: tab

    spacing: 10

    onVisibleChanged: if (visible) HyprSettings.refresh()

    // Label, stepped slider and value for an integer setting
    component Setting: RowLayout {
        id: setting

        property string label
        property string key
        property int to: 20

        Layout.fillWidth: true
        spacing: 12

        Text {
            Layout.preferredWidth: 90
            text: setting.label
            color: Theme.subtext1
            font.family: Theme.font
            font.pixelSize: 12
        }
        LevelSlider {
            Layout.fillWidth: true
            from: 0
            to: setting.to
            step: 1
            value: HyprSettings[setting.key]
            onMoved: v => HyprSettings.set(setting.key, Math.round(v))
        }
        Text {
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignRight
            text: HyprSettings[setting.key]
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    component SectionTitle: Text {
        Layout.topMargin: 4
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
    }

    RowLayout {
        Layout.fillWidth: true

        SectionTitle { text: "Windows" }
        Item { Layout.fillWidth: true }
        Text {
            text: Icons.refresh + "  Reset"
            color: resetMouse.containsMouse ? Theme.accent : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 12

            MouseArea {
                id: resetMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: HyprSettings.reset()
            }
        }
    }

    Setting { label: "Inner gaps"; key: "gapsIn"; to: 20 }
    Setting { label: "Outer gaps"; key: "gapsOut"; to: 40 }
    Setting { label: "Rounding"; key: "rounding"; to: 24 }
    Setting { label: "Border"; key: "border"; to: 6 }

    GridLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        columns: 3
        columnSpacing: 8

        Tile {
            Layout.fillWidth: true
            icon: Icons.sliders
            label: "Blur"
            active: HyprSettings.blur
            onClicked: HyprSettings.set("blur", !HyprSettings.blur)
        }
        Tile {
            Layout.fillWidth: true
            icon: Icons.apps
            label: "Shadows"
            active: HyprSettings.shadows
            onClicked: HyprSettings.set("shadows", !HyprSettings.shadows)
        }
        Tile {
            Layout.fillWidth: true
            icon: Icons.video
            label: "Animations"
            active: HyprSettings.animations
            onClicked: HyprSettings.set("animations", !HyprSettings.animations)
        }
    }

    // ---- Night light ----
    SectionTitle { text: "Night light" }

    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        IconButton {
            size: 30
            icon: Status.nightLight ? Icons.moon : Icons.sun
            iconColor: Status.nightLight ? Theme.peach : Theme.subtext1
            onClicked: Status.nightLight = !Status.nightLight
        }
        LevelSlider {
            Layout.fillWidth: true
            from: 2500
            to: 6500
            step: 250
            value: Status.nightTemperature
            dimmed: !Status.nightLight
            onMoved: v => Settings.values.nightTemperature = Math.round(v / 100) * 100
        }
        Text {
            Layout.preferredWidth: 48
            horizontalAlignment: Text.AlignRight
            text: Status.nightTemperature + "K"
            color: Theme.subtext1
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // Automatic schedule: on at the start time, off at the end time
    RowLayout {
        Layout.fillWidth: true
        spacing: 10

        Text {
            Layout.fillWidth: true
            text: "Automatically from"
            color: Settings.values.nightSchedule ? Theme.subtext1 : Theme.overlay0
            font.family: Theme.font
            font.pixelSize: 12
        }
        TimeField { key: "nightStart" }
        Text {
            text: "to"
            color: Settings.values.nightSchedule ? Theme.subtext1 : Theme.overlay0
            font.family: Theme.font
            font.pixelSize: 12
        }
        TimeField { key: "nightEnd" }
        Toggle {
            checked: Settings.values.nightSchedule
            onToggled: Settings.values.nightSchedule = !Settings.values.nightSchedule
        }
    }

    // HH:MM field bound to a Settings value; invalid input reverts
    component TimeField: Rectangle {
        id: field

        property string key

        implicitWidth: 58
        implicitHeight: 28
        radius: 8
        color: Theme.surface0
        border.width: input.activeFocus ? 1 : 0
        border.color: Theme.accent

        TextInput {
            id: input
            anchors.centerIn: parent
            text: Settings.values[field.key]
            color: Settings.values.nightSchedule ? Theme.text : Theme.overlay1
            font.family: Theme.font
            font.pixelSize: 12
            inputMask: "99:99"
            validator: RegularExpressionValidator { regularExpression: /([01]\d|2[0-3]):[0-5]\d/ }

            function save() {
                if (acceptableInput) Settings.values[field.key] = text;
                else text = Settings.values[field.key];
            }
            onEditingFinished: save()
        }
    }
}
