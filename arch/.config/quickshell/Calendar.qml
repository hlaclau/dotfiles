import QtQuick
import QtQuick.Layouts

// Month grid starting on Monday, today highlighted. Arrows (or scrolling)
// change the month; clicking the title goes back to this month.
ColumnLayout {
    id: cal

    property date today: new Date()
    // First day of the month shown
    property date month: new Date(today.getFullYear(), today.getMonth(), 1)

    // 6 weeks x 7 days, Monday first, padded with the neighbouring months
    readonly property var cells: {
        const first = new Date(month.getFullYear(), month.getMonth(), 1);
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === month.getMonth(),
                isToday: d.toDateString() === today.toDateString(),
                weekend: d.getDay() === 0 || d.getDay() === 6
            });
        }
        return out;
    }

    function shift(n) {
        month = new Date(month.getFullYear(), month.getMonth() + n, 1);
    }

    spacing: 8

    RowLayout {
        Layout.fillWidth: true

        Text {
            Layout.fillWidth: true
            text: Qt.formatDate(cal.month, "MMMM yyyy")
            color: Theme.text
            font.family: Theme.font
            font.pixelSize: 13
            font.bold: true

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: cal.month = new Date(cal.today.getFullYear(), cal.today.getMonth(), 1)
            }
        }
        IconButton {
            size: 24
            icon: Icons.chevronLeft
            onClicked: cal.shift(-1)
        }
        IconButton {
            size: 24
            icon: Icons.chevronRight
            onClicked: cal.shift(1)
        }
    }

    GridLayout {
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

            Text {
                required property string modelData
                Layout.preferredWidth: 32
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                color: Theme.overlay0
                font.family: Theme.font
                font.pixelSize: 11
            }
        }

        Repeater {
            model: cal.cells

            Rectangle {
                required property var modelData

                Layout.preferredWidth: 32
                Layout.preferredHeight: 28
                radius: 8
                color: modelData.isToday ? Theme.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.day
                    color: parent.modelData.isToday ? Theme.crust
                        : (!parent.modelData.inMonth ? Theme.surface2
                        : (parent.modelData.weekend ? Theme.subtext0 : Theme.text))
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.bold: parent.modelData.isToday
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => cal.shift(e.angleDelta.y > 0 ? -1 : 1)
    }
}
