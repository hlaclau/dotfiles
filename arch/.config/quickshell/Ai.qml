pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Chat state for the AI panel. One conversation at a time, answered by one of
// three backends:
//   claude  Claude Code in print mode, resumed by session id between turns
//   codex   `codex exec` in a read-only sandbox, resumed by thread id
//   ollama  a local model over the HTTP API; the history is sent every turn
// Agents (agents.json next to this file) are named system prompts.
// Switching backend or agent starts a new chat.
//
// Chats are saved to ai-chats.json in quickshell's state dir as they go: the
// last one comes back after a restart, and any older one can be reopened from
// the history and continued (Claude and Codex resume their session).
Singleton {
    id: root

    readonly property var backends: ["claude", "codex", "ollama"]
    readonly property string backend: Settings.values.aiBackend
    readonly property var agents: {
        try {
            const list = JSON.parse(agentsFile.text());
            if (Array.isArray(list) && list.length) return list;
        } catch (e) {}
        return [{ name: "Chat", icon: "", prompt: "" }];
    }
    readonly property var agent: agents.find(a => a.name === Settings.values.aiAgent) ?? agents[0]

    // { role: "user" | "assistant", text, status (what's happening now), error }
    readonly property alias messages: model
    readonly property bool busy: proc.running
    // Claude session / Codex thread to resume; "" for a fresh chat
    property string sessionId: ""

    property var ollamaModels: []
    property bool ollamaUp: false
    readonly property string ollamaModel: ollamaModels.includes(Settings.values.aiOllamaModel)
        ? Settings.values.aiOllamaModel : (ollamaModels[0] ?? "")

    ListModel { id: model }

    // ---- Saved chats ----
    // [{ id, title, backend, agent, sessionId, updated, messages: [{ role, text, error }] }], newest first
    readonly property var chats: history.chats
    // Id of the chat on screen; "" until its first message
    property string chatId: ""
    readonly property int maxChats: 100

    FileView {
        path: Quickshell.statePath("ai-chats.json")
        blockLoading: true
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: history
            property var chats: []
            // Chat open when quickshell last stopped
            property string current: ""
        }
    }

    Component.onCompleted: if (history.current) openChat(history.current)

    function save() {
        if (model.count === 0) return;
        if (!chatId) chatId = Date.now().toString(36);
        const messages = [];
        for (let i = 0; i < model.count; i++) {
            const m = model.get(i);
            messages.push({ role: m.role, text: m.text, error: m.error });
        }
        const first = messages.find(m => m.role === "user")?.text ?? "";
        const chat = {
            id: chatId,
            title: first.split("\n")[0].slice(0, 80),
            backend, agent: agent.name, sessionId,
            updated: Date.now(),
            messages
        };
        history.chats = [chat, ...history.chats.filter(c => c.id !== chatId)].slice(0, maxChats);
        history.current = chatId;
    }

    function openChat(id) {
        const chat = history.chats.find(c => c.id === id);
        if (!chat) return;
        stop();
        model.clear();
        for (const m of chat.messages) model.append({ role: m.role, text: m.text, status: "", error: m.error ?? "" });
        // Set the backend and agent directly: their setters would start a new chat
        if (backends.includes(chat.backend)) Settings.values.aiBackend = chat.backend;
        Settings.values.aiAgent = chat.agent;
        sessionId = chat.sessionId ?? "";
        chatId = chat.id;
        history.current = chat.id;
    }

    function deleteChat(id) {
        history.chats = history.chats.filter(c => c.id !== id);
        if (id === chatId) newChat();
    }

    FileView {
        id: agentsFile
        path: Quickshell.shellPath("agents.json")
        watchChanges: true
        onFileChanged: reload()
    }

    function setBackend(name) {
        if (name === backend) return;
        Settings.values.aiBackend = name;
        newChat();
    }

    function setAgent(name) {
        if (name === agent.name) return;
        Settings.values.aiAgent = name;
        newChat();
    }

    function setOllamaModel(name) {
        Settings.values.aiOllamaModel = name;
    }

    function newChat() {
        stop();
        model.clear();
        sessionId = "";
        chatId = "";
        history.current = "";
    }

    function stop() {
        if (proc.running) {
            stopped = true;
            proc.running = false;
        }
    }

    function refreshOllama() {
        tags.running = true;
    }

    function send(text) {
        text = text.trim();
        if (!text || proc.running) return;

        const first = model.count === 0;
        model.append({ role: "user", text, status: "", error: "" });

        let command;
        if (backend === "claude") {
            command = ["claude", "-p", "--output-format", "stream-json", "--verbose",
                "--include-partial-messages", "--strict-mcp-config"];
            if (sessionId) command.push("--resume", sessionId);
            if (agent.prompt) command.push("--append-system-prompt", agent.prompt);
            command.push("--", text);
        } else if (backend === "codex") {
            command = ["codex", "exec"];
            if (sessionId) command.push("resume");
            command.push("--json", "--skip-git-repo-check", "-c", 'sandbox_mode="read-only"', "--");
            if (sessionId) command.push(sessionId);
            // No system prompt flag: the agent prompt leads the first message
            command.push(first && agent.prompt ? `${agent.prompt}\n\n${text}` : text);
        } else {
            if (!ollamaModel) {
                model.append({ role: "assistant", text: "", status: "",
                    error: ollamaUp ? "No models installed. Run `ollama pull <model>`, e.g. `ollama pull llama3.2`."
                        : "Ollama isn't running. Start it with `systemctl enable --now ollama`." });
                return;
            }
            const history = [];
            if (agent.prompt) history.push({ role: "system", content: agent.prompt });
            for (let i = 0; i < model.count; i++) {
                const m = model.get(i);
                if (!m.error && m.text) history.push({ role: m.role, content: m.text });
            }
            command = ["curl", "-sS", "-N", "http://127.0.0.1:11434/api/chat",
                "-d", JSON.stringify({ model: ollamaModel, messages: history, stream: true })];
        }

        model.append({ role: "assistant", text: "", status: "Thinking…", error: "" });
        save();
        stopped = false;
        gotOutput = false;
        lastMessageId = "";
        // Codex reads a piped stdin until EOF, so give every backend /dev/null
        proc.command = ["sh", "-c", 'exec "$@" < /dev/null', "sh", ...command];
        proc.running = true;
    }

    // ---- Streaming into the last message ----

    property bool stopped: false
    property bool gotOutput: false
    // Claude: id of the API message being streamed, to space out separate ones
    property string lastMessageId: ""

    function current() {
        return model.count - 1;
    }

    function appendText(chunk, separate) {
        const i = current();
        let text = model.get(i).text;
        if (separate && text) text += "\n\n";
        model.setProperty(i, "text", text + chunk);
        model.setProperty(i, "status", "");
        gotOutput = true;
    }

    function setStatus(status) {
        model.setProperty(current(), "status", status);
    }

    function setError(error) {
        model.setProperty(current(), "error", error);
        model.setProperty(current(), "status", "");
        gotOutput = true;
    }

    function parseClaude(ev) {
        if (ev.type === "system" && ev.subtype === "init") {
            sessionId = ev.session_id;
        } else if (ev.type === "stream_event") {
            const e = ev.event;
            if (e.type === "message_start") {
                if (lastMessageId && e.message.id !== lastMessageId) pendingBreak = true;
                lastMessageId = e.message.id;
            } else if (e.type === "content_block_start" && e.content_block.type === "tool_use") {
                setStatus(`Using ${e.content_block.name}…`);
                pendingBreak = true;
            } else if (e.type === "content_block_delta" && e.delta.type === "text_delta") {
                appendText(e.delta.text, pendingBreak);
                pendingBreak = false;
            }
        } else if (ev.type === "result") {
            if (ev.session_id) sessionId = ev.session_id;
            if (ev.is_error) setError(ev.result || ev.subtype || "Claude Code failed");
        }
    }
    property bool pendingBreak: false

    function parseCodex(ev) {
        if (ev.type === "thread.started") {
            sessionId = ev.thread_id;
        } else if (ev.type === "item.started" && ev.item.type === "command_execution") {
            setStatus(`Running ${ev.item.command}…`);
        } else if (ev.type === "item.completed" && ev.item.type === "agent_message") {
            appendText(ev.item.text, true);
        } else if (ev.type === "turn.failed") {
            setError(ev.error?.message ?? "Codex failed");
        } else if (ev.type === "error") {
            setError(ev.message ?? "Codex failed");
        }
    }

    function parseOllama(ev) {
        if (ev.error) setError(ev.error);
        else if (ev.message?.content) appendText(ev.message.content, false);
    }

    Process {
        id: proc

        workingDirectory: Quickshell.env("HOME")

        stdout: SplitParser {
            onRead: line => {
                let ev;
                try {
                    ev = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (root.backend === "claude") root.parseClaude(ev);
                else if (root.backend === "codex") root.parseCodex(ev);
                else root.parseOllama(ev);
            }
        }
        stderr: StdioCollector { id: errors }

        onExited: code => {
            const i = root.current();
            model.setProperty(i, "status", "");
            Qt.callLater(root.save);
            if (root.stopped) {
                model.setProperty(i, "error", "Stopped");
            } else if (!root.gotOutput) {
                const tail = errors.text.trim().split("\n").slice(-6).join("\n");
                const hint = root.backend === "ollama" && code === 7
                    ? "Ollama isn't running. Start it with `systemctl enable --now ollama`." : "";
                model.setProperty(i, "error", hint || tail || `Exited with code ${code} and no answer`);
            }
        }
    }

    // Installed Ollama models, refreshed whenever the panel opens
    Process {
        id: tags
        command: ["curl", "-sS", "--max-time", "2", "http://127.0.0.1:11434/api/tags"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.ollamaModels = JSON.parse(this.text).models.map(m => m.name);
                    root.ollamaUp = true;
                } catch (e) {
                    root.ollamaModels = [];
                    root.ollamaUp = false;
                }
            }
        }
    }
}
