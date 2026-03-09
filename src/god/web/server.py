"""GOD web server — Flask + SocketIO backend."""

import logging
import os
import threading
import time
import webbrowser

from flask import Flask, render_template
from flask_socketio import SocketIO

from god.engine import GodEngine

log = logging.getLogger("god.web")

engine: GodEngine | None = None
socketio: SocketIO | None = None


def create_app() -> tuple[Flask, SocketIO]:
    global engine, socketio

    template_dir = os.path.join(os.path.dirname(__file__), "templates")
    static_dir = os.path.join(os.path.dirname(__file__), "static")

    app = Flask(__name__, template_folder=template_dir, static_folder=static_dir)
    app.config["SECRET_KEY"] = "god-genesis-on-disk"
    socketio = SocketIO(app, cors_allowed_origins="*", async_mode="threading")

    engine = GodEngine()

    @app.route("/")
    def index():
        return render_template("index.html")

    @socketio.on("connect")
    def on_connect():
        log.info("Client connected")
        _emit_state()

    @socketio.on("action")
    def on_action(data):
        action = data.get("action")
        log.info("Action: %s", action)

        if action == "toggle_play":
            if engine.transport.playing:
                engine.stop()
            else:
                engine.play()
        elif action == "stop_all":
            engine.stop_all()
        elif action == "god_toggle":
            engine.god_toggle()
        elif action == "undo":
            engine.undo_last_pass()
        elif action == "redo":
            engine.redo()
        elif action == "toggle_metronome":
            engine.metronome.toggle()
        elif action == "cycle_metronome_sound":
            engine.metronome.cycle_sound()
        elif action == "bpm_up":
            engine.set_bpm(engine.transport.bpm + 1)
        elif action == "bpm_down":
            engine.set_bpm(engine.transport.bpm - 1)
        elif action == "set_bpm":
            engine.set_bpm(data.get("value", 120))
        elif action == "set_bars":
            engine.set_bar_count(data.get("value", 1))

        _emit_state()

    return app, socketio


def _emit_state():
    """Push current engine state to all connected clients."""
    if not engine or not socketio:
        return

    patterns = []
    for i, p in enumerate(engine.pattern_stack.patterns):
        patterns.append({
            "name": p.name,
            "state": p.state.value,
            "volume": p.volume,
            "active": i == engine.pattern_stack.active_index,
            "event_count": len(p.events),
        })

    state = {
        "bpm": engine.transport.bpm,
        "bar_count": engine.transport.bar_count,
        "playing": engine.transport.playing,
        "current_bar": engine.transport.current_bar,
        "loop_progress": engine.transport.loop_progress,
        "pass_number": engine.transport.pass_number,
        "god_state": engine.capture.state.value,
        "metronome_enabled": engine.metronome.enabled,
        "metronome_sound": engine.metronome.sound.value,
        "master_volume": engine.audio.master_volume,
        "patterns": patterns,
    }
    socketio.emit("state", state)


def _state_loop():
    """Background thread pushing state at ~30fps."""
    while True:
        if engine and engine.transport.playing:
            socketio.emit("state", _build_state())
        time.sleep(1 / 30)


def _build_state() -> dict:
    patterns = []
    for i, p in enumerate(engine.pattern_stack.patterns):
        patterns.append({
            "name": p.name,
            "state": p.state.value,
            "volume": p.volume,
            "active": i == engine.pattern_stack.active_index,
            "event_count": len(p.events),
        })

    return {
        "bpm": engine.transport.bpm,
        "bar_count": engine.transport.bar_count,
        "playing": engine.transport.playing,
        "current_bar": engine.transport.current_bar,
        "loop_progress": engine.transport.loop_progress,
        "pass_number": engine.transport.pass_number,
        "god_state": engine.capture.state.value,
        "metronome_enabled": engine.metronome.enabled,
        "metronome_sound": engine.metronome.sound.value,
        "master_volume": engine.audio.master_volume,
        "patterns": patterns,
    }


def run_server(host: str = "127.0.0.1", port: int = 6660):
    app, sio = create_app()

    # Connect MIDI
    engine.midi.connect()
    log.info("MIDI connected: %s", engine.midi.port_name or "none")

    # Start audio stream
    engine.start_audio_stream()
    log.info("Audio stream started")

    # Background state push thread
    state_thread = threading.Thread(target=_state_loop, daemon=True)
    state_thread.start()

    # Open browser
    webbrowser.open(f"http://{host}:{port}")

    log.info("GOD web server starting on %s:%d", host, port)
    sio.run(app, host=host, port=port, debug=False, use_reloader=False, log_output=False)
