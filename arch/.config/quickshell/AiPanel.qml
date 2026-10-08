import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// AI chat docked to the right edge of the screen it was opened on (state lives
// in Ai). It stays open while you click and type in other windows: click back
// into it to type. Pick a backend and an agent up top, Enter sends, Shift + Enter
// adds a line, Escape closes. Answers render as Markdown and can be selected or
// copied. The clock button lists saved chats to reopen and continue.
PanelWindow {
    id: panel

    required property var modelData
    required property bool open
    signal closeRequested

    screen: modelData

    readonly property bool focusedScreen: Hyprland.focusedMonitor?.name === modelData.name
    // Pinned to the screen that had focus when it opened, so it doesn't jump
    // or vanish when focus moves to the other monitor
    property bool here: false
    onOpenChanged: if (open) here = focusedScreen
    readonly property bool shown: open && here

    property bool showHistory: false

    visible: shown
    color: "transparent"
    implicitWidth: 460 + 2 * 12

    anchors {
        top: true
        bottom: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ai"
    // On demand: typing goes here after a click into the panel, and other
    // windows stay usable while it's open
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

    onShownChanged: {
        if (shown) {
            showHistory = false;
            if (Ai.backend === "ollama") Ai.refreshOllama();
            input.forceActiveFocus();
            list.positionViewAtEnd();
        }
    }

    // "5m ago", "3h ago", "2d ago", then the date
    function ago(ms) {
        const m = Math.floor((Date.now() - ms) / 60000);
        if (m < 1) return "just now";
        if (m < 60) return m + "m ago";
        if (m < 24 * 60) return Math.floor(m / 60) + "h ago";
        if (m < 7 * 24 * 60) return Math.floor(m / 1440) + "d ago";
        return Qt.formatDate(new Date(ms), "d MMM");
    }

    function submit() {
        if (Ai.busy) return;
        Ai.send(input.text);
        input.text = "";
    }

    // Small selectable pill for backends, agents and models
    component Chip: Rectangle {
        id: chip

        property string label
        property string icon
        property bool selected: false
        signal clicked

        implicitWidth: row.implicitWidth + 20
        implicitHeight: 28
        radius: 14
        color: selected ? Theme.accent : (chipMouse.containsMouse ? Theme.surface1 : Theme.surface0)

        Behavior on color { ColorAnimation { duration: 120 } }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Text {
                visible: chip.icon !== ""
                anchors.verticalCenter: parent.verticalCenter
                text: chip.icon
                color: chip.selected ? Theme.crust : Theme.subtext1
                font.family: Theme.iconFont
                font.pixelSize: 11
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.selected ? Theme.crust : Theme.subtext1
                font.family: Theme.font
                font.pixelSize: 12
                font.bold: chip.selected
            }
        }

        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        // Start below the bar
        anchors.topMargin: Theme.barHeight + 8
        radius: 20
        color: Theme.base
        border.width: 1
        border.color: Theme.surface1

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 12

            // ---- Header ----
            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Text {
                    text: Icons.robot
                    color: Theme.accent
                    font.family: Theme.iconFont
                    font.pixelSize: 20
                }
                Text {
                    Layout.fillWidth: true
                    text: "Assistant"
                    color: Theme.text
                    font.family: Theme.font
                    font.pixelSize: 16
                    font.bold: true
                }
                IconButton {
                    icon: Icons.clock
                    iconColor: panel.showHistory ? Theme.crust : Theme.text
                    color: panel.showHistory ? Theme.accent : Theme.surface0
                    onClicked: panel.showHistory = !panel.showHistory
                }
                IconButton {
                    icon: Icons.plus
                    onClicked: {
                        Ai.newChat();
                        panel.showHistory = false;
                        input.forceActiveFocus();
                    }
                }
                IconButton {
                    icon: Icons.close
                    onClicked: panel.closeRequested()
                }
            }

            // ---- Backend, agent and model ----
            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Ai.backends

                    Chip {
                        required property string modelData
                        label: modelData
                        selected: Ai.backend === modelData
                        onClicked: {
                            Ai.setBackend(modelData);
                            if (modelData === "ollama") Ai.refreshOllama();
                        }
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                spacing: 6

                Repeater {
                    model: Ai.agents

                    Chip {
                        required property var modelData
                        label: modelData.name
                        icon: modelData.icon ?? ""
                        selected: Ai.agent.name === modelData.name
                        onClicked: Ai.setAgent(modelData.name)
                    }
                }
            }

            Flow {
                Layout.fillWidth: true
                visible: Ai.backend === "ollama"
                spacing: 6

                Repeater {
                    model: Ai.ollamaModels

                    Chip {
                        required property string modelData
                        label: modelData
                        selected: Ai.ollamaModel === modelData
                        onClicked: Ai.setOllamaModel(modelData)
                    }
                }

                Text {
                    visible: Ai.ollamaModels.length === 0
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: Ai.ollamaUp ? "No models installed: ollama pull llama3.2"
                        : "Ollama isn't running: systemctl enable --now ollama"
                    color: Theme.peach
                    font.family: Theme.font
                    font.pixelSize: 12
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                color: Theme.surface0
            }

            // ---- Conversation ----
            ListView {
                id: list

                // Follow new text unless the user scrolled up to read
                property bool stick: true

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: !panel.showHistory
                clip: true
                spacing: 14
                model: Ai.messages
                boundsBehavior: Flickable.StopAtBounds

                onMovementEnded: stick = atYEnd
                onContentHeightChanged: if (stick) positionViewAtEnd()
                onCountChanged: {
                    stick = true;
                    positionViewAtEnd();
                }

                delegate: Item {
                    id: message

                    required property string role
                    required property string text
                    required property string status
                    required property string error

                    readonly property bool mine: role === "user"

                    width: list.width
                    implicitHeight: mine ? bubble.height : answer.implicitHeight

                    // User message: right-aligned bubble
                    Rectangle {
                        id: bubble
                        visible: message.mine
                        anchors.right: parent.right
                        width: Math.min(parent.width * 0.85, question.implicitWidth + 24)
                        height: question.implicitHeight + 16
                        radius: 14
                        color: Theme.surface0

                        TextEdit {
                            id: question
                            anchors.fill: parent
                            anchors.margins: 8
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            text: message.text
                            color: Theme.text
                            selectionColor: Theme.surface2
                            font.family: Theme.font
                            font.pixelSize: 13
                        }
                    }

                    // Assistant answer: full-width Markdown, status and error below
                    ColumnLayout {
                        id: answer
                        visible: !message.mine
                        width: parent.width
                        spacing: 6

                        TextEdit {
                            Layout.fillWidth: true
                            visible: message.text !== ""
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.MarkdownText
                            text: message.text
                            color: Theme.text
                            selectionColor: Theme.surface2
                            font.family: Theme.font
                            font.pixelSize: 13
                            onLinkActivated: link => Qt.openUrlExternally(link)
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: message.status !== ""
                            text: message.status
                            color: Theme.overlay1
                            font.family: Theme.font
                            font.pixelSize: 12
                            font.italic: true
                            elide: Text.ElideRight

                            SequentialAnimation on opacity {
                                running: message.status !== ""
                                loops: Animation.Infinite
                                NumberAnimation { to: 0.4; duration: 600 }
                                NumberAnimation { to: 1; duration: 600 }
                            }
                        }

                        Text {
                            Layout.fillWidth: true
                            visible: message.error !== ""
                            wrapMode: Text.Wrap
                            text: message.error
                            color: message.error === "Stopped" ? Theme.overlay1 : Theme.red
                            font.family: Theme.font
                            font.pixelSize: 12
                        }

                        IconButton {
                            visible: message.text !== "" && message.status === ""
                            size: 26
                            icon: Icons.copy
                            iconColor: Theme.subtext0
                            onClicked: Quickshell.execDetached(["wl-copy", message.text])
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    width: parent.width - 40
                    visible: list.count === 0
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.Wrap
                    text: `${Ai.agent.name} · ${Ai.backend}\nAsk anything`
                    color: Theme.overlay0
                    font.family: Theme.font
                    font.pixelSize: 13
                    lineHeight: 1.4
                }
            }

            // ---- Saved chats ----
            ListView {
                id: chatList

                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: panel.showHistory
                clip: true
                spacing: 4
                model: Ai.chats
                boundsBehavior: Flickable.StopAtBounds

                delegate: Rectangle {
                    id: chat

                    required property var modelData
                    readonly property bool current: modelData.id === Ai.chatId

                    width: chatList.width
                    implicitHeight: 52
                    radius: 12
                    color: current ? Qt.alpha(Theme.accent, 0.15) : (chatMouse.containsMouse ? Theme.surface0 : "transparent")

                    MouseArea {
                        id: chatMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Ai.openChat(chat.modelData.id);
                            panel.showHistory = false;
                            input.forceActiveFocus();
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            Text {
                                Layout.fillWidth: true
                                text: chat.modelData.title || "Untitled"
                                color: Theme.text
                                font.family: Theme.font
                                font.pixelSize: 13
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: `${chat.modelData.backend} · ${chat.modelData.agent} · ${Math.ceil(chat.modelData.messages.length / 2)} msg · ${panel.ago(chat.modelData.updated)}`
                                color: Theme.overlay1
                                font.family: Theme.font
                                font.pixelSize: 11
                                elide: Text.ElideRight
                            }
                        }
                        IconButton {
                            size: 28
                            icon: Icons.trash
                            iconColor: Theme.overlay1
                            opacity: chatMouse.containsMouse || hovered ? 1 : 0
                            readonly property bool hovered: trashHover.hovered
                            HoverHandler { id: trashHover }
                            onClicked: Ai.deleteChat(chat.modelData.id)
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: chatList.count === 0
                    text: "No saved chats yet"
                    color: Theme.overlay0
                    font.family: Theme.font
                    font.pixelSize: 13
                }
            }

            // ---- Input ----
            Rectangle {
                Layout.fillWidth: true
                visible: !panel.showHistory
                implicitHeight: Math.min(input.implicitHeight, 160) + 20
                radius: 14
                color: Theme.surface0
                border.width: input.activeFocus ? 1 : 0
                border.color: Theme.accent

                Flickable {
                    id: inputScroll
                    anchors.left: parent.left
                    anchors.right: sendButton.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    anchors.leftMargin: 14
                    contentHeight: input.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    TextEdit {
                        id: input
                        width: inputScroll.width
                        wrapMode: TextEdit.Wrap
                        color: Theme.text
                        selectionColor: Theme.surface2
                        font.family: Theme.font
                        font.pixelSize: 13

                        // Keep the cursor in view while typing long messages
                        onCursorRectangleChanged: {
                            const r = cursorRectangle;
                            if (r.y < inputScroll.contentY) inputScroll.contentY = r.y;
                            else if (r.y + r.height > inputScroll.contentY + inputScroll.height)
                                inputScroll.contentY = r.y + r.height - inputScroll.height;
                        }

                        Keys.onEscapePressed: panel.closeRequested()
                        Keys.onReturnPressed: event => {
                            if (event.modifiers & Qt.ShiftModifier) event.accepted = false;
                            else panel.submit();
                        }
                        Keys.onEnterPressed: event => {
                            if (event.modifiers & Qt.ShiftModifier) event.accepted = false;
                            else panel.submit();
                        }

                        Text {
                            visible: !input.text
                            text: `Message ${Ai.agent.name}…`
                            color: Theme.overlay0
                            font: input.font
                        }
                    }
                }

                IconButton {
                    id: sendButton
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    size: 30
                    icon: Ai.busy ? Icons.stop : Icons.send
                    iconColor: Ai.busy ? Theme.red : Theme.accent
                    onClicked: Ai.busy ? Ai.stop() : panel.submit()
                }
            }
        }
    }
}
