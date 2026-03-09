/* GOD — text is the interface */

const socket = io();

let state = {
    bpm: 120, bar_count: 1, playing: false,
    current_bar: 1, loop_progress: 0, pass_number: 0,
    god_state: "idle", metronome_enabled: true,
    metronome_sound: "soft_click", patterns: [],
};

const transport = document.getElementById("transport");
const loopBar = document.getElementById("loop-bar");
const beatMarkers = document.getElementById("beat-markers");
const barIndicator = document.getElementById("bar-indicator");
const passCounter = document.getElementById("pass-counter");
const patternsList = document.getElementById("patterns-list");

socket.on("state", (s) => { state = s; render(); });

function render() {
    renderTransport();
    renderLoop();
    renderPatterns();
}

function renderTransport() {
    const playing = state.playing;
    const godState = state.god_state;
    const metroOn = state.metronome_enabled;

    const items = [
        {
            text: `${playing ? "■ stop" : "▶ play"}`,
            action: "toggle_play",
            cls: playing ? "active playing" : "",
        },
        {
            text: `bpm ${state.bpm}`,
            action: null,
            cls: "",
        },
        {
            text: `${state.bar_count} bar${state.bar_count > 1 ? "s" : ""}`,
            action: null,
            cls: "",
        },
        {
            text: `metro ${metroOn ? "on" : "off"}`,
            action: "toggle_metronome",
            cls: metroOn ? "active" : "",
        },
        {
            text: `god ${godState === "idle" ? "◇" : godState === "armed" ? "◈" : "◆"}`,
            action: "god_toggle",
            cls: godState === "armed" ? "god-armed" : godState === "recording" ? "god-recording" : "",
        },
    ];

    transport.innerHTML = items.map((item) => {
        const click = item.action ? `data-action="${item.action}"` : "";
        const cursor = item.action ? 'style="cursor:pointer"' : "";
        return `<span class="t-item ${item.cls}" ${click} ${cursor}>${item.text}</span>`;
    }).join("");
}

function renderLoop() {
    loopBar.style.width = (state.loop_progress * 100) + "%";

    const totalBeats = state.bar_count * 4;
    if (beatMarkers.children.length !== totalBeats) {
        beatMarkers.innerHTML = "";
        for (let i = 0; i < totalBeats; i++) {
            const m = document.createElement("div");
            m.className = "beat-marker";
            beatMarkers.appendChild(m);
        }
    }

    barIndicator.textContent = `bar ${state.current_bar}/${state.bar_count}`;

    const max = 20;
    const count = state.pass_number;
    passCounter.innerHTML = "";
    const shown = Math.min(count, max);
    for (let i = 0; i < shown; i++) {
        const d = document.createElement("div");
        d.className = "pass-dot";
        passCounter.appendChild(d);
    }
    if (count > max) {
        const o = document.createElement("span");
        o.className = "pass-overflow";
        o.textContent = `+${count - max}`;
        passCounter.appendChild(o);
    }
}

function renderPatterns() {
    const patterns = state.patterns;

    if (patterns.length === 0) {
        patternsList.innerHTML = '<div class="empty-state">press space to begin</div>';
        return;
    }

    const stateSymbols = {
        playing: "▶",
        muted: "■",
        recording: "●",
        empty: "○",
    };

    if (patternsList.children.length !== patterns.length || patternsList.querySelector(".empty-state")) {
        patternsList.innerHTML = "";
        patterns.forEach(() => {
            const row = document.createElement("div");
            row.className = "pattern-row";
            row.innerHTML = `<span class="pattern-active-marker"></span><span class="pattern-state-symbol"></span><span class="pattern-name"></span><span class="pattern-events"></span><span class="pattern-volume-text"></span>`;
            patternsList.appendChild(row);
        });
    }

    const rows = patternsList.querySelectorAll(".pattern-row");
    patterns.forEach((p, i) => {
        if (!rows[i]) return;
        const row = rows[i];
        row.className = `pattern-row ${p.state}`;
        if (p.active) row.classList.add("active");

        row.querySelector(".pattern-active-marker").textContent = p.active ? "→" : " ";
        row.querySelector(".pattern-state-symbol").textContent = stateSymbols[p.state] || "○";
        row.querySelector(".pattern-name").textContent = p.name;
        row.querySelector(".pattern-events").textContent = p.event_count > 0 ? `${p.event_count}ev` : "";
        row.querySelector(".pattern-volume-text").textContent = `${Math.round(p.volume * 100)}%`;
    });

    patternsList.scrollTop = patternsList.scrollHeight;
}

// Click actions on transport text
document.addEventListener("click", (e) => {
    const item = e.target.closest("[data-action]");
    if (item) socket.emit("action", { action: item.dataset.action });
});

// Keyboard
document.addEventListener("keydown", (e) => {
    const key = e.key.toLowerCase();
    switch (key) {
        case " ":
            e.preventDefault();
            socket.emit("action", { action: "toggle_play" });
            break;
        case "g":
            socket.emit("action", { action: "god_toggle" });
            break;
        case "u":
            socket.emit("action", { action: "undo" });
            break;
        case "r":
            socket.emit("action", { action: "redo" });
            break;
        case "m":
            socket.emit("action", { action: "toggle_metronome" });
            break;
        case "arrowup":
            e.preventDefault();
            socket.emit("action", { action: "bpm_up" });
            break;
        case "arrowdown":
            e.preventDefault();
            socket.emit("action", { action: "bpm_down" });
            break;
        case "1":
            socket.emit("action", { action: "set_bars", value: 1 });
            break;
        case "2":
            socket.emit("action", { action: "set_bars", value: 2 });
            break;
        case "4":
            socket.emit("action", { action: "set_bars", value: 4 });
            break;
        case "escape":
            socket.emit("action", { action: "stop_all" });
            break;
    }
});

render();
