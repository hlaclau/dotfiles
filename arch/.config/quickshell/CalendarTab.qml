import QtQuick
import QtQuick.Layouts

// Weather (current and the next days) above the month calendar
ColumnLayout {
    id: tab

    spacing: 14

    // ---- Weather ----
    ColumnLayout {
        Layout.fillWidth: true
        visible: Weather.ready
        spacing: 12

        RowLayout {
            spacing: 14

            Text {
                text: Weather.icon
                color: Theme.yellow
                font.family: Theme.iconFont
                font.pixelSize: 36
            }
            ColumnLayout {
                spacing: 0

                Text {
                    text: Weather.temp + "°C"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 24
                    font.bold: true
                }
                Text {
                    text: Weather.description + (Weather.area ? " · " + Weather.area : "")
                    color: Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }
            Item { Layout.fillWidth: true }
            ColumnLayout {
                spacing: 2

                Text {
                    Layout.alignment: Qt.AlignRight
                    text: "Feels like " + Weather.feelsLike + "°"
                    color: Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 11
                }
                Text {
                    Layout.alignment: Qt.AlignRight
                    text: "Humidity " + Weather.humidity + "%"
                    color: Theme.subtext0
                    font.family: Theme.font
                    font.pixelSize: 11
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 0

            Repeater {
                model: Weather.days

                ColumnLayout {
                    id: day

                    required property var modelData
                    required property int index

                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: day.index === 0 ? "Today" : Qt.formatDate(new Date(day.modelData.date + "T12:00"), "ddd")
                        color: Theme.subtext0
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: Weather.iconFor(day.modelData.code, false)
                        color: Theme.yellow
                        font.family: Theme.iconFont
                        font.pixelSize: 20
                    }
                    Text {
                        Layout.alignment: Qt.AlignHCenter
                        text: day.modelData.max + "° / " + day.modelData.min + "°"
                        color: Theme.text
                        font.family: Theme.font
                        font.pixelSize: 11
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: 1
        color: Theme.surface0
        visible: Weather.ready
    }

    // ---- Calendar ----
    Calendar {
        Layout.alignment: Qt.AlignHCenter
    }
}
