pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property string filePath: `${Directories.state}/user/kanban.json`
    readonly property string defaultBoardId: "kanban"
    property var boards: [makeDefaultBoard([])]
    property string activeBoardId: defaultBoardId
    readonly property var activeBoard: boards.find(board => board.id === activeBoardId) || boards[0]
    readonly property var tasks: activeBoard.tasks
    readonly property bool isDefaultBoard: activeBoardId === defaultBoardId
    property bool ready: false
    property string error: ""

    function makeDefaultBoard(tasks) {
        return { id: defaultBoardId, name: "Kanban", columns: ["To Do", "In Progress", "Done"], tasks: tasks };
    }

    function newId() {
        return Date.now().toString(36) + Math.random().toString(36).slice(2);
    }

    function persist() {
        store.setText(JSON.stringify({ version: 2, activeBoardId: activeBoardId, boards: boards }));
    }

    function updateBoard(board) {
        boards = boards.map(item => item.id === board.id ? board : item);
        persist();
    }

    function nameAvailable(name, exceptId) {
        name = name.trim();
        return name !== "" && !boards.some(board => board.id !== exceptId
            && board.name.toLowerCase() === name.toLowerCase());
    }

    function createBoard(name) {
        if (!ready || !nameAvailable(name, "")) return false;
        const board = { id: newId(), name: name.trim(), columns: ["To Do", "In Progress", "Done"], tasks: [] };
        boards = boards.concat([board]);
        activeBoardId = board.id;
        persist();
        return true;
    }

    function switchBoard(id) {
        if (!ready || !boards.some(board => board.id === id)) return false;
        activeBoardId = id;
        persist();
        return true;
    }

    function renameBoard(id, name) {
        const board = boards.find(board => board.id === id);
        if (!ready || id === defaultBoardId || !board || !nameAvailable(name, id)) return false;
        updateBoard(Object.assign({}, board, { name: name.trim() }));
        return true;
    }

    function deleteBoard(id) {
        if (!ready || id === defaultBoardId || !boards.some(board => board.id === id)) return false;
        if (activeBoardId === id) activeBoardId = defaultBoardId;
        boards = boards.filter(board => board.id !== id);
        persist();
        return true;
    }

    function renameColumn(index, name) {
        name = name.trim();
        if (!ready || isDefaultBoard || name === "" || !Number.isInteger(index)
            || index < 0 || index >= activeBoard.columns.length) return false;
        const columns = activeBoard.columns.slice();
        columns[index] = name;
        updateBoard(Object.assign({}, activeBoard, { columns: columns }));
        return true;
    }

    function saveTask(id, title, description, column) {
        title = title.trim();
        if (!ready || title === "" || !Number.isInteger(column)
            || column < 0 || column >= activeBoard.columns.length) return false;
        const next = tasks.slice();
        if (id === "") {
            id = newId();
            next.push({ id: id, title: title, description: description.trim(), column: column });
        } else {
            const index = next.findIndex(task => task.id === id);
            if (index < 0) return false;
            next[index] = { id: id, title: title, description: description.trim(), column: column };
        }
        updateBoard(Object.assign({}, activeBoard, { tasks: next }));
        return true;
    }

    function moveTask(id, column) {
        const task = tasks.find(task => task.id === id);
        if (!ready || !task || task.column === column || !Number.isInteger(column)
            || column < 0 || column >= activeBoard.columns.length) return false;
        // Appending places moved tasks last in their destination column.
        const next = tasks.filter(task => task.id !== id);
        next.push(Object.assign({}, task, { column: column }));
        updateBoard(Object.assign({}, activeBoard, { tasks: next }));
        return true;
    }

    function deleteTask(id) {
        if (!ready) return;
        updateBoard(Object.assign({}, activeBoard, { tasks: tasks.filter(task => task.id !== id) }));
    }

    function validTasks(tasks, columnCount) {
        const ids = new Set();
        return Array.isArray(tasks) && tasks.every(task => {
            if (!task || typeof task.id !== "string" || task.id === "" || ids.has(task.id)
                || typeof task.title !== "string" || task.title.trim() === ""
                || typeof task.description !== "string" || !Number.isInteger(task.column)
                || task.column < 0 || task.column >= columnCount) return false;
            ids.add(task.id);
            return true;
        });
    }

    FileView {
        id: store
        path: root.filePath
        atomicWrites: true
        onPathChanged: root.ready = false
        onLoaded: {
            try {
                const data = JSON.parse(text());
                const legacy = Array.isArray(data);
                const next = legacy ? { version: 2, activeBoardId: root.defaultBoardId,
                    boards: [root.makeDefaultBoard(data)] } : data;
                const ids = new Set();
                if (!next || next.version !== 2 || !Array.isArray(next.boards) || next.boards.length === 0
                    || !next.boards.every(board => {
                    if (!board || typeof board.id !== "string" || board.id === "" || ids.has(board.id)
                        || typeof board.name !== "string" || board.name.trim() === ""
                        || !Array.isArray(board.columns) || board.columns.length !== 3
                        || !board.columns.every(name => typeof name === "string" && name.trim() !== "")
                        || !root.validTasks(board.tasks, board.columns.length)) return false;
                    ids.add(board.id);
                    return true;
                })) throw new Error("Invalid board data");
                const defaultBoard = next.boards.find(board => board.id === root.defaultBoardId);
                if (!defaultBoard || defaultBoard.name !== "Kanban"
                    || JSON.stringify(defaultBoard.columns) !== JSON.stringify(root.makeDefaultBoard([]).columns)
                    || !ids.has(next.activeBoardId)) throw new Error("Invalid default or active board");
                root.boards = next.boards;
                root.activeBoardId = next.activeBoardId;
                root.error = "";
                root.ready = true;
                if (legacy) root.persist();
            } catch (error) {
                root.ready = false;
                root.error = Translation.tr("Could not read Kanban data. Check the local state file.");
            }
        }
        onLoadFailed: error => {
            root.ready = error === FileViewError.FileNotFound;
            if (root.ready) {
                root.boards = [root.makeDefaultBoard([])];
                root.activeBoardId = root.defaultBoardId;
                root.error = "";
            } else root.error = Translation.tr("Could not load Kanban data.");
        }
        onSaveFailed: error => root.error = Translation.tr("Could not save Kanban tasks. Check disk space and permissions.")
        onSaved: root.error = ""
    }
}
