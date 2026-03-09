/* GOD — Genesis On Disk — Frontend */

const socket = io();

// State
let state = {
    bpm: 120,
    bar_count: 1,
    playing: false,
    current_bar: 1,
    loop_progress: 0,
    pass_number: 0,
    god_state: "idle",
    metronome_enabled: true,
    metronome_sound: "soft_click",
    patterns: [],
};

// DOM refs
const bpmDisplay = document.getElementById("bpm");
const playBtn = document.getElementById("play-btn");
const playIcon = document.getElementById("play-icon");
const stopIcon = document.getElementById("stop-icon");
const godBtn = document.getElementById("god-btn");
const godIcon = document.getElementById("god-icon");
const metroBtn = document.getElementById("metro-btn");
const metroIndicator = document.getElementById("metro-indicator");
const metroSound = document.getElementById("metro-sound");
const loopBar = document.getElementById("loop-bar");
const beatMarkers = document.getElementById("beat-markers");
const barIndicator = document.getElementById("bar-indicator");
const passCounter = document.getElementById("pass-counter");
const patternsList = document.getElementById("patterns-list");
const connectionDot = document.getElementById("connection-dot");

// Connection
socket.on("connect", () => {
    connectionDot.classList.add("connected");
    connectionDot.querySelector(".status-text").textContent = "ONLINE";
});

socket.on("disconnect", () => {
    connectionDot.classList.remove("connected");
    connectionDot.querySelector(".status-text").textContent = "OFFLINE";
});

// State updates
socket.on("state", (newState) => {
    state = newState;
    render();
});

// Render
function render() {
    // BPM
    bpmDisplay.textContent = state.bpm;

    // Bar selector
    document.querySelectorAll(".bar-btn").forEach((btn) => {
        btn.classList.toggle("active", parseInt(btn.dataset.bars) === state.bar_count);
    });

    // Play button
    playBtn.classList.toggle("playing", state.playing);
    playIcon.classList.toggle("hidden", state.playing);
    stopIcon.classList.toggle("hidden", !state.playing);

    // GOD button
    godBtn.classList.remove("armed", "recording");
    if (state.god_state === "armed") {
        godBtn.classList.add("armed");
        godIcon.textContent = "◈";
    } else if (state.god_state === "recording") {
        godBtn.classList.add("recording");
        godIcon.textContent = "◆";
    } else {
        godIcon.textContent = "◇";
    }

    // Metronome
    metroBtn.classList.toggle("on", state.metronome_enabled);
    metroSound.textContent = state.metronome_sound.replace("_", " ");

    // Loop bar
    loopBar.style.width = (state.loop_progress * 100) + "%";
    loopBar.classList.toggle("playing", state.playing);

    // Beat markers
    const totalBeats = state.bar_count * 4;
    if (beatMarkers.children.length !== totalBeats) {
        beatMarkers.innerHTML = "";
        for (let i = 0; i < totalBeats; i++) {
            const marker = document.createElement("div");
            marker.className = "beat-marker" + (i % 4 === 0 ? " downbeat" : "");
            beatMarkers.appendChild(marker);
        }
    }

    // Bar indicator
    barIndicator.textContent = `BAR ${state.current_bar}/${state.bar_count}`;

    // Pass counter
    renderPassCounter();

    // Patterns
    renderPatterns();
}

function renderPassCounter() {
    const maxDots = 20;
    const count = state.pass_number;

    passCounter.innerHTML = "";
    const shown = Math.min(count, maxDots);
    for (let i = 0; i < shown; i++) {
        const dot = document.createElement("div");
        dot.className = "pass-dot";
        passCounter.appendChild(dot);
    }
    if (count > maxDots) {
        const overflow = document.createElement("span");
        overflow.className = "pass-overflow";
        overflow.textContent = `+${count - maxDots}`;
        passCounter.appendChild(overflow);
    }
}

function renderPatterns() {
    const patterns = state.patterns;

    if (patterns.length === 0) {
        patternsList.innerHTML = '<div class="empty-state">Press Space to begin</div>';
        return;
    }

    // Only rebuild if pattern count changed
    if (patternsList.children.length !== patterns.length || patternsList.querySelector(".empty-state")) {
        patternsList.innerHTML = "";
        patterns.forEach((p, i) => {
            const row = document.createElement("div");
            row.className = "pattern-row";
            row.innerHTML = `
                <div class="pattern-active-marker"></div>
                <div class="pattern-state-dot"></div>
                <span class="pattern-name">${p.name}</span>
                <span class="pattern-events">${p.event_count} events</span>
                <div class="pattern-volume-bar">
                    <div class="pattern-volume-fill"></div>
                </div>
            `;
            patternsList.appendChild(row);
        });
    }

    // Update classes and values
    const rows = patternsList.querySelectorAll(".pattern-row");
    patterns.forEach((p, i) => {
        if (!rows[i]) return;
        const row = rows[i];
        row.className = `pattern-row ${p.state}`;
        if (p.active) row.classList.add("active");

        row.querySelector(".pattern-name").textContent = p.name;
        row.querySelector(".pattern-events").textContent = `${p.event_count} events`;
        row.querySelector(".pattern-volume-fill").style.width = (p.volume * 100) + "%";
    });

    // Scroll to bottom for newest pattern
    patternsList.scrollTop = patternsList.scrollHeight;
}

// Actions — button clicks
document.addEventListener("click", (e) => {
    const btn = e.target.closest("[data-action]");
    if (btn) {
        socket.emit("action", { action: btn.dataset.action });
    }

    const barBtn = e.target.closest("[data-bars]");
    if (barBtn) {
        socket.emit("action", { action: "set_bars", value: parseInt(barBtn.dataset.bars) });
    }
});

// Keyboard shortcuts
document.addEventListener("keydown", (e) => {
    // Prevent default for our shortcuts
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

// Initial render
render();
