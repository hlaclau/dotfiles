import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Quickshell.Networking

// Ethernet status, Wi-Fi networks and Bluetooth devices
ColumnLayout {
    id: tab

    spacing: 8

    readonly property var wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    readonly property var wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var adapter: Bluetooth.defaultAdapter

    // Connected first, then saved, then by signal; hidden networks have no name
    readonly property var networks: (wifi?.networks.values ?? [])
        .filter(n => n.name)
        .sort((a, b) => (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    // Connected, then paired, then the rest; skip unnamed devices
    readonly property var devices: (adapter?.devices.values ?? [])
        .filter(d => d.paired || d.connected || d.deviceName)
        .sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired) || a.name.localeCompare(b.name))

    // Network whose row is expanded (actions / password)
    property var selected: null

    // Only scan while the tab is open
    onVisibleChanged: {
        if (wifi) wifi.scannerEnabled = visible && Networking.wifiEnabled;
        if (!visible) {
            selected = null;
            if (adapter?.discovering) adapter.discovering = false;
        }
    }

    component SectionTitle: Text {
        color: Theme.text
        font.family: Theme.font
        font.pixelSize: 13
        font.bold: true
    }

    component Hint: Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        color: Theme.overlay0
        font.family: Theme.font
        font.pixelSize: 12
    }

    component Action: Rectangle {
        id: action

        property string label
        property color tint: Theme.text
        signal clicked

        implicitWidth: actionText.implicitWidth + 22
        implicitHeight: 28
        radius: 14
        color: actionMouse.containsMouse ? Theme.surface2 : Theme.surface1

        Text {
            id: actionText
            anchors.centerIn: parent
            text: action.label
            color: action.tint
            font.family: Theme.font
            font.pixelSize: 11
        }

        MouseArea {
            id: actionMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: action.clicked()
        }
    }

    // ---- Ethernet ----
    RowLayout {
        Layout.fillWidth: true
        visible: tab.wired !== null
        spacing: 10

        Text {
            text: Icons.ethernet
            color: tab.wired?.connected ? Theme.accent : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 14
        }
        Text {
            Layout.fillWidth: true
            text: tab.wired?.connected
                ? "Ethernet · " + (tab.wired.linkSpeed >= 1000 ? tab.wired.linkSpeed / 1000 + " Gb/s" : tab.wired.linkSpeed + " Mb/s")
                : "Ethernet · not connected"
            color: Theme.subtext1
            font.family: Theme.font
            font.pixelSize: 12
        }
    }

    // ---- Wi-Fi ----
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 6

        SectionTitle { text: "Wi-Fi" }
        Item { Layout.fillWidth: true }
        Toggle {
            checked: Networking.wifiEnabled
            onToggled: {
                Networking.wifiEnabled = !Networking.wifiEnabled;
                if (tab.wifi) tab.wifi.scannerEnabled = Networking.wifiEnabled;
            }
        }
    }

    Hint {
        visible: !tab.wifi
        text: "No Wi-Fi adapter"
    }
    Hint {
        visible: tab.wifi !== null && Networking.wifiEnabled && tab.networks.length === 0
        text: "Scanning…"
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(wifiList.implicitHeight, 230)
        visible: Networking.wifiEnabled && tab.networks.length > 0
        contentHeight: wifiList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: wifiList
            width: parent.width
            spacing: 2

            Repeater {
                model: tab.networks

                Rectangle {
                    id: net

                    required property var modelData
                    readonly property bool open: modelData.security === WifiSecurityType.Open || modelData.security === WifiSecurityType.Owe
                    readonly property bool expanded: tab.selected === modelData
                    readonly property bool needsPassword: !modelData.known && !open
                    property string error: ""

                    Layout.fillWidth: true
                    implicitHeight: netColumn.implicitHeight + 16
                    radius: 10
                    color: modelData.connected ? Qt.alpha(Theme.accent, 0.18)
                        : (expanded || netMouse.containsMouse ? Theme.surface0 : "transparent")

                    Connections {
                        target: net.modelData
                        function onConnectionFailed(reason) {
                            net.error = reason === ConnectionFailReason.NoSecrets ? "Wrong password" : "Couldn't connect";
                            tab.selected = net.modelData;
                        }
                        function onConnectedChanged() {
                            if (net.modelData.connected) {
                                net.error = "";
                                if (tab.selected === net.modelData) tab.selected = null;
                            }
                        }
                    }

                    MouseArea {
                        id: netMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            net.error = "";
                            tab.selected = net.expanded ? null : net.modelData;
                            if (tab.selected && net.needsPassword) password.forceActiveFocus();
                        }
                    }

                    ColumnLayout {
                        id: netColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 8
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text {
                                text: Icons.wifi
                                // Brighter with a stronger signal
                                color: net.modelData.signalStrength > 0.6 ? Theme.accent
                                    : net.modelData.signalStrength > 0.3 ? Theme.subtext0 : Theme.overlay0
                                font.family: Theme.iconFont
                                font.pixelSize: 13
                            }
                            Text {
                                Layout.fillWidth: true
                                text: net.modelData.name
                                color: net.modelData.connected ? Theme.text : Theme.subtext1
                                font.family: Theme.font
                                font.pixelSize: 12
                                font.bold: net.modelData.connected
                                elide: Text.ElideRight
                            }
                            Text {
                                text: net.modelData.stateChanging ? "…"
                                    : net.modelData.connected ? "Connected"
                                    : net.modelData.known ? "Saved" : ""
                                visible: text !== ""
                                color: Theme.overlay1
                                font.family: Theme.font
                                font.pixelSize: 11
                            }
                            Text {
                                visible: !net.open
                                text: Icons.lock
                                color: Theme.overlay0
                                font.family: Theme.iconFont
                                font.pixelSize: 10
                            }
                        }

                        // Password field for new secured networks
                        Rectangle {
                            Layout.fillWidth: true
                            visible: net.expanded && net.needsPassword
                            implicitHeight: 32
                            radius: 8
                            color: Theme.mantle
                            border.width: 1
                            border.color: net.error ? Theme.red : (password.activeFocus ? Theme.accent : Theme.surface1)

                            TextInput {
                                id: password
                                anchors.fill: parent
                                anchors.leftMargin: 10
                                anchors.rightMargin: 10
                                verticalAlignment: TextInput.AlignVCenter
                                echoMode: TextInput.Password
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 12
                                clip: true
                                onAccepted: if (text) net.modelData.connectWithPsk(text)

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: !password.text
                                    text: "Password"
                                    color: Theme.overlay0
                                    font: password.font
                                }
                            }
                        }

                        Text {
                            visible: net.expanded && net.error !== ""
                            text: net.error
                            color: Theme.red
                            font.family: Theme.font
                            font.pixelSize: 11
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            visible: net.expanded
                            spacing: 6

                            Item { Layout.fillWidth: true }
                            Action {
                                visible: net.modelData.known
                                label: "Forget"
                                tint: Theme.red
                                onClicked: {
                                    net.modelData.forget();
                                    tab.selected = null;
                                }
                            }
                            Action {
                                label: net.modelData.connected ? "Disconnect" : "Connect"
                                onClicked: {
                                    if (net.modelData.connected) net.modelData.disconnect();
                                    else if (net.needsPassword) {
                                        if (password.text) net.modelData.connectWithPsk(password.text);
                                        else password.forceActiveFocus();
                                    } else net.modelData.connect();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ---- Bluetooth ----
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 10
        spacing: 10

        SectionTitle { text: "Bluetooth" }
        Item { Layout.fillWidth: true }
        Text {
            visible: tab.adapter?.enabled ?? false
            text: tab.adapter?.discovering ? "Stop" : Icons.refresh + "  Scan"
            color: scanMouse.containsMouse ? Theme.accent : Theme.overlay1
            font.family: Theme.iconFont
            font.pixelSize: 12

            MouseArea {
                id: scanMouse
                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: tab.adapter.discovering = !tab.adapter.discovering
            }
        }
        Toggle {
            checked: tab.adapter?.enabled ?? false
            onToggled: if (tab.adapter) tab.adapter.enabled = !tab.adapter.enabled
        }
    }

    Hint {
        visible: !tab.adapter
        text: "No Bluetooth adapter"
    }
    Hint {
        visible: (tab.adapter?.enabled ?? false) && tab.devices.length === 0
        text: tab.adapter?.discovering ? "Searching for devices…" : "No devices. Press Scan to find some"
    }

    Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(btList.implicitHeight, 230)
        visible: (tab.adapter?.enabled ?? false) && tab.devices.length > 0
        contentHeight: btList.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: btList
            width: parent.width
            spacing: 2

            Repeater {
                model: tab.devices

                Rectangle {
                    id: dev

                    required property var modelData
                    readonly property bool busy: modelData.pairing
                        || modelData.state === BluetoothDeviceState.Connecting
                        || modelData.state === BluetoothDeviceState.Disconnecting
                    readonly property string glyph: {
                        const icon = modelData.icon;
                        if (icon.includes("audio") || icon.includes("headset") || icon.includes("headphone")) return Icons.headphones;
                        if (icon.includes("keyboard")) return Icons.keyboard;
                        if (icon.includes("mouse")) return Icons.mouse;
                        if (icon.includes("phone")) return Icons.mobile;
                        if (icon.includes("gaming") || icon.includes("joystick")) return Icons.gamepad;
                        if (icon.includes("computer")) return Icons.desktop;
                        return Icons.bluetooth;
                    }

                    Layout.fillWidth: true
                    implicitHeight: 40
                    radius: 10
                    color: modelData.connected ? Qt.alpha(Theme.accent, 0.18) : (devMouse.containsMouse ? Theme.surface0 : "transparent")

                    MouseArea {
                        id: devMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const d = dev.modelData;
                            if (dev.busy) return;
                            if (d.connected) d.disconnect();
                            else if (d.paired) d.connect();
                            else {
                                // Trust it so it reconnects on its own next time
                                d.trusted = true;
                                d.pair();
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 10

                        Text {
                            text: dev.glyph
                            color: dev.modelData.connected ? Theme.accent : Theme.subtext0
                            font.family: Theme.iconFont
                            font.pixelSize: 13
                        }
                        Text {
                            Layout.fillWidth: true
                            text: dev.modelData.name || dev.modelData.address
                            color: dev.modelData.connected ? Theme.text : Theme.subtext1
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.bold: dev.modelData.connected
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: dev.modelData.batteryAvailable
                            text: Icons.battery + " " + Math.round(dev.modelData.battery * 100) + "%"
                            color: Theme.subtext0
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }
                        Text {
                            text: dev.modelData.pairing ? "Pairing…"
                                : dev.busy ? "…"
                                : dev.modelData.connected ? "Connected"
                                : dev.modelData.paired ? "Paired" : "Pair"
                            color: !dev.modelData.paired && !dev.busy ? Theme.accent : Theme.overlay1
                            font.family: Theme.font
                            font.pixelSize: 11
                        }
                        Text {
                            visible: dev.modelData.paired && (devMouse.containsMouse || forgetMouse.containsMouse)
                            text: Icons.close
                            color: forgetMouse.containsMouse ? Theme.red : Theme.overlay1
                            font.family: Theme.iconFont
                            font.pixelSize: 12

                            MouseArea {
                                id: forgetMouse
                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: dev.modelData.forget()
                            }
                        }
                    }
                }
            }
        }
    }
}
