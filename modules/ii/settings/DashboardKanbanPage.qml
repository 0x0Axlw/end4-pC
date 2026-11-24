import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root

    required property Item pager
    property int staggerMs: 45
    property bool editing: false
    property string editingId: ""
    property int editingColumn: 0
    property string boardAction: ""
    property int renamingColumn: -1
    property bool dragging: false
    property var draggedTask: null
    readonly property bool typing: editing || boardAction !== "" || renamingColumn >= 0 || dragging
    readonly property var columnNames: Kanban.isDefaultBoard
        ? [Translation.tr("To Do"), Translation.tr("In Progress"), Translation.tr("Done")]
        : Kanban.activeBoard.columns

    function manageBoard(action) {
        closeEditor();
        renamingColumn = -1;
        boardAction = action;
        boardNameInput.text = action === "rename" ? Kanban.activeBoard.name : "";
        if (action !== "delete") boardNameInput.forceActiveFocus();
    }

    function submitBoard() {
        let saved = false;
        if (boardAction === "create") saved = Kanban.createBoard(boardNameInput.text);
        else if (boardAction === "rename") saved = Kanban.renameBoard(Kanban.activeBoardId, boardNameInput.text);
        else if (boardAction === "delete") saved = Kanban.deleteBoard(Kanban.activeBoardId);
        if (saved) {
            boardAction = "";
            pager.forceActiveFocus();
        }
    }

    function cancelDrag() {
        dragPreview.Drag.cancel();
        dragging = false;
        draggedTask = null;
    }

    Keys.onEscapePressed: root.cancelDrag()

    Connections {
        target: Kanban
        function onActiveBoardIdChanged() {
            root.closeEditor();
            root.boardAction = "";
            root.renamingColumn = -1;
            root.cancelDrag();
        }
    }

    function editTask(task, column) {
        boardAction = "";
        renamingColumn = -1;
        editingId = task ? task.id : "";
        editingColumn = column;
        titleInput.text = task ? task.title : "";
        descriptionInput.text = task ? task.description : "";
        editing = true;
        titleInput.forceActiveFocus();
    }

    function closeEditor() {
        editing = false;
        pager.forceActiveFocus();
    }

    function submit() {
        if (Kanban.saveTask(editingId, titleInput.text, descriptionInput.text, editingColumn)) closeEditor();
    }

    component ActionButton: RippleButton {
        id: action
        property string symbol
        property string label
        implicitWidth: 32
        implicitHeight: 32
        buttonRadius: 16
        Accessible.name: label
        ToolTip.visible: hovered
        ToolTip.text: label
        contentItem: MaterialSymbol {
            text: action.symbol
            iconSize: 18
            color: Appearance.colors.colOnLayer1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            StyledComboBox {
                objectName: "kanbanBoardSelector"
                Layout.fillWidth: false
                Layout.preferredWidth: 220
                model: Kanban.boards
                textRole: "name"
                currentIndex: Kanban.boards.findIndex(board => board.id === Kanban.activeBoardId)
                enabled: Kanban.ready && !root.dragging
                buttonIcon: "view_kanban"
                Accessible.name: Translation.tr("Board")
                onActivated: index => Kanban.switchBoard(Kanban.boards[index].id)
            }
            ActionButton {
                symbol: "add"
                label: Translation.tr("New board")
                enabled: Kanban.ready && !root.dragging
                onClicked: root.manageBoard("create")
            }
            ActionButton {
                symbol: "edit"
                label: Translation.tr("Rename board")
                enabled: Kanban.ready && !Kanban.isDefaultBoard && !root.dragging
                onClicked: root.manageBoard("rename")
            }
            ActionButton {
                symbol: "delete"
                label: Translation.tr("Delete board")
                enabled: Kanban.ready && !Kanban.isDefaultBoard && !root.dragging
                onClicked: root.manageBoard("delete")
            }
            Item { Layout.fillWidth: true }
            RippleButton {
                implicitWidth: 112
                implicitHeight: 38
                buttonRadius: 19
                enabled: Kanban.ready
                toggled: true
                onClicked: root.editTask(null, 0)
                contentItem: StyledText {
                    text: Translation.tr("New task")
                    color: Appearance.colors.colOnPrimary
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: root.boardAction !== ""
            spacing: 8
            Keys.onEscapePressed: root.boardAction = ""
            MaterialTextField {
                id: boardNameInput
                objectName: "kanbanBoardName"
                Layout.fillWidth: true
                visible: root.boardAction !== "delete"
                placeholderText: root.boardAction === "rename" ? Translation.tr("Rename board") : Translation.tr("New board")
                maximumLength: 80
                onAccepted: root.submitBoard()
            }
            StyledText {
                Layout.fillWidth: true
                visible: root.boardAction === "delete"
                text: Translation.tr("Delete this board and all its tasks?")
                wrapMode: Text.Wrap
            }
            ActionButton {
                symbol: "close"
                label: Translation.tr("Cancel")
                onClicked: root.boardAction = ""
            }
            ActionButton {
                symbol: root.boardAction === "delete" ? "delete" : "check"
                label: root.boardAction === "delete" ? Translation.tr("Delete board") : Translation.tr("Save")
                enabled: Kanban.ready && (root.boardAction === "delete" || Kanban.nameAvailable(boardNameInput.text,
                    root.boardAction === "rename" ? Kanban.activeBoardId : ""))
                onClicked: root.submitBoard()
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: Kanban.error !== ""
            text: Kanban.error
            color: Appearance.colors.colError
            wrapMode: Text.Wrap
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: editor.implicitHeight + 24
            visible: root.editing
            radius: Appearance.rounding.large
            color: Appearance.colors.colLayer1

            ColumnLayout {
                id: editor
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8
                Keys.onEscapePressed: root.closeEditor()
                Keys.onPressed: event => {
                    if ((event.modifiers & Qt.ControlModifier) && event.key === Qt.Key_Return) {
                        root.submit();
                        event.accepted = true;
                    }
                }
                MaterialTextField {
                    id: titleInput
                    Layout.fillWidth: true
                    placeholderText: Translation.tr("Task title")
                    maximumLength: 200
                    onAccepted: root.submit()
                }
                ScrollView {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    contentWidth: availableWidth
                    StyledTextArea {
                        id: descriptionInput
                        placeholderText: Translation.tr("Description (optional)")
                        wrapMode: TextEdit.Wrap
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    StyledText {
                        Layout.fillWidth: true
                        text: root.columnNames[root.editingColumn]
                        color: Appearance.colors.colSubtext
                    }
                    RippleButton {
                        implicitWidth: 80
                        implicitHeight: 32
                        buttonRadius: 16
                        onClicked: root.closeEditor()
                        contentItem: StyledText {
                            text: Translation.tr("Cancel")
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                    RippleButton {
                        implicitWidth: 80
                        implicitHeight: 32
                        buttonRadius: 16
                        enabled: Kanban.ready && titleInput.text.trim() !== ""
                        toggled: true
                        onClicked: root.submit()
                        contentItem: StyledText {
                            text: Translation.tr("Save")
                            color: Appearance.colors.colOnPrimary
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 12

            Repeater {
                model: root.columnNames.length
                delegate: DashboardCard {
                    id: columnCard
                    required property int index
                    objectName: "kanbanColumn" + index
                    readonly property var columnTasks: Kanban.tasks.filter(task => task.column === index)
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    pager: root.pager
                    animIndex: index
                    staggerMs: root.staggerMs
                    border.width: columnDrop.containsDrag ? 2 : 0
                    border.color: Appearance.colors.colPrimary

                    DropArea {
                        id: columnDrop
                        anchors.fill: parent
                        keys: ["end4-kanban-task"]
                        onEntered: event => {
                            event.accepted = Kanban.ready && event.source.boardId === Kanban.activeBoardId
                                && event.source.sourceColumn !== columnCard.index;
                        }
                        onDropped: event => {
                            if (!Kanban.ready || event.source.boardId !== Kanban.activeBoardId) return;
                            const taskId = event.source.taskId;
                            const boardId = event.source.boardId;
                            const column = columnCard.index;
                            event.accept(Qt.MoveAction);
                            // Let the source finish releasing before its delegate is removed.
                            Qt.callLater(() => {
                                if (Kanban.activeBoardId === boardId) Kanban.moveTask(taskId, column);
                            });
                        }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            StyledText {
                                Layout.maximumWidth: columnCard.width - 110
                                text: root.columnNames[columnCard.index]
                                font.weight: Font.Medium
                                elide: Text.ElideRight
                                visible: root.renamingColumn !== columnCard.index
                                MouseArea {
                                    anchors.fill: parent
                                    enabled: Kanban.ready && !Kanban.isDefaultBoard
                                    cursorShape: enabled ? Qt.IBeamCursor : Qt.ArrowCursor
                                    onClicked: {
                                        root.renamingColumn = columnCard.index;
                                        columnTitle.text = root.columnNames[columnCard.index];
                                        columnTitle.forceActiveFocus();
                                        columnTitle.selectAll();
                                    }
                                }
                            }
                            TextField {
                                id: columnTitle
                                objectName: "kanbanColumnTitle" + columnCard.index
                                Layout.fillWidth: true
                                visible: root.renamingColumn === columnCard.index
                                font.family: Appearance.font.family.main
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnLayer1
                                selectionColor: Appearance.colors.colSecondaryContainer
                                selectedTextColor: Appearance.colors.colOnSecondaryContainer
                                maximumLength: 60
                                padding: 0
                                background: Rectangle {
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Appearance.colors.colPrimary
                                    radius: Appearance.rounding.small
                                }
                                Accessible.name: Translation.tr("Column title")
                                onEditingFinished: {
                                    if (root.renamingColumn !== columnCard.index) return;
                                    Kanban.renameColumn(columnCard.index, text);
                                    root.renamingColumn = -1;
                                }
                                Keys.onEscapePressed: {
                                    root.renamingColumn = -1;
                                    root.pager.forceActiveFocus();
                                }
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: columnCard.columnTasks.length
                                color: Appearance.colors.colSubtext
                            }
                            ActionButton {
                                symbol: "add"
                                label: Translation.tr("New task")
                                enabled: Kanban.ready
                                onClicked: root.editTask(null, columnCard.index)
                            }
                        }
                        ScrollView {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            contentWidth: availableWidth
                            clip: true

                            ColumnLayout {
                                width: parent.width
                                spacing: 8
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: columnCard.columnTasks.length === 0
                                    text: Translation.tr("No tasks yet")
                                    color: Appearance.colors.colSubtext
                                    horizontalAlignment: Text.AlignHCenter
                                    topPadding: 24
                                }
                                Repeater {
                                    model: columnCard.columnTasks
                                    delegate: Rectangle {
                                        id: taskCard
                                        required property var modelData
                                        objectName: "kanbanTask-" + modelData.id
                                        Layout.fillWidth: true
                                        implicitHeight: taskContent.implicitHeight + 24
                                        radius: Appearance.rounding.normal
                                        color: Appearance.colors.colSurfaceContainerHigh
                                        opacity: root.dragging && root.draggedTask?.id === modelData.id ? 0.4 : 1
                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.bottomMargin: 44
                                            enabled: Kanban.ready
                                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                            preventStealing: true
                                            drag.target: dragPreview
                                            onPressed: mouse => {
                                                root.forceActiveFocus();
                                                root.draggedTask = taskCard.modelData;
                                                dragPreview.boardId = Kanban.activeBoardId;
                                                dragPreview.taskId = taskCard.modelData.id;
                                                dragPreview.sourceColumn = columnCard.index;
                                                const point = mapToItem(root, mouse.x, mouse.y);
                                                dragPreview.x = point.x - mouse.x;
                                                dragPreview.y = point.y - mouse.y;
                                                dragPreview.width = taskCard.width;
                                                dragPreview.height = Math.min(taskCard.height, 120);
                                                dragPreview.Drag.hotSpot = Qt.point(mouse.x, mouse.y);
                                            }
                                            onPositionChanged: {
                                                if (drag.active && root.draggedTask) root.dragging = true;
                                            }
                                            onReleased: {
                                                if (root.dragging) dragPreview.Drag.drop();
                                                root.dragging = false;
                                                root.draggedTask = null;
                                            }
                                            onCanceled: root.cancelDrag()
                                        }
                                        ColumnLayout {
                                            id: taskContent
                                            anchors.fill: parent
                                            anchors.margins: 12
                                            spacing: 4
                                            StyledText {
                                                Layout.fillWidth: true
                                                text: taskCard.modelData.title
                                                textFormat: Text.PlainText
                                                wrapMode: Text.Wrap
                                                font.weight: Font.Medium
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                visible: text !== ""
                                                text: taskCard.modelData.description
                                                textFormat: Text.PlainText
                                                wrapMode: Text.Wrap
                                                color: Appearance.colors.colSubtext
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                            }
                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 0
                                                ActionButton {
                                                    symbol: "arrow_back"
                                                    label: columnCard.index > 0 ? root.columnNames[columnCard.index - 1] : ""
                                                    enabled: columnCard.index > 0
                                                    onClicked: Kanban.moveTask(taskCard.modelData.id, columnCard.index - 1)
                                                }
                                                ActionButton {
                                                    symbol: "arrow_forward"
                                                    label: columnCard.index < root.columnNames.length - 1 ? root.columnNames[columnCard.index + 1] : ""
                                                    enabled: columnCard.index < root.columnNames.length - 1
                                                    onClicked: Kanban.moveTask(taskCard.modelData.id, columnCard.index + 1)
                                                }
                                                Item { Layout.fillWidth: true }
                                                ActionButton {
                                                    symbol: "edit"
                                                    label: Translation.tr("Edit")
                                                    onClicked: root.editTask(taskCard.modelData, columnCard.index)
                                                }
                                                ActionButton {
                                                    symbol: "delete"
                                                    label: Translation.tr("Delete")
                                                    onClicked: {
                                                        if (root.editingId === taskCard.modelData.id) root.closeEditor();
                                                        Kanban.deleteTask(taskCard.modelData.id);
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: dragPreview
        objectName: "kanbanDragPreview"
        property string boardId: ""
        property string taskId: ""
        property int sourceColumn: -1
        z: 100
        visible: root.dragging
        opacity: 0.9
        radius: Appearance.rounding.normal
        color: Appearance.colors.colPrimaryContainer
        border.width: 1
        border.color: Appearance.colors.colPrimary
        Drag.active: root.dragging
        Drag.source: dragPreview
        Drag.keys: ["end4-kanban-task"]
        Drag.supportedActions: Qt.MoveAction
        Drag.proposedAction: Qt.MoveAction
        StyledText {
            anchors.fill: parent
            anchors.margins: 12
            text: root.draggedTask?.title ?? ""
            textFormat: Text.PlainText
            color: Appearance.colors.colOnPrimaryContainer
            wrapMode: Text.Wrap
            elide: Text.ElideRight
            font.weight: Font.Medium
        }
    }
}
