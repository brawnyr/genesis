"""Main GOD Textual application."""
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import Footer, Header
from god.engine import GodEngine
from god.ui.widgets.transport_bar import TransportBar
from god.ui.widgets.pattern_list import PatternList
from god.ui.widgets.status_panel import StatusPanel


class GodApp(App):
    TITLE = "GOD"
    SUB_TITLE = "Genesis On Disk"

    CSS = """
    Screen { background: #1a1a2e; }
    Header { background: #16213e; color: #a78bfa; }
    Footer { background: #16213e; color: #7a7a9e; }
    """

    BINDINGS = [
        Binding("space", "toggle_play", "Play/Stop"),
        Binding("escape", "stop_all", "Stop All"),
        Binding("g", "god_toggle", "GOD"),
        Binding("u", "undo", "Undo"),
        Binding("r", "redo", "Redo"),
        Binding("m", "toggle_metronome", "Metronome"),
        Binding("up", "bpm_up", "BPM +1", show=False),
        Binding("down", "bpm_down", "BPM -1", show=False),
        Binding("1", "set_bars_1", "1 Bar", show=False),
        Binding("2", "set_bars_2", "2 Bars", show=False),
        Binding("4", "set_bars_4", "4 Bars", show=False),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self):
        super().__init__()
        self.engine = GodEngine()

    def compose(self) -> ComposeResult:
        yield Header()
        yield TransportBar()
        yield PatternList()
        yield StatusPanel()
        yield Footer()

    def on_mount(self) -> None:
        self.engine.midi.connect()
        self.engine.start_audio_stream()
        self._refresh_ui()
        self.set_interval(1 / 30, self._refresh_ui)

    def on_unmount(self) -> None:
        self.engine.stop_audio_stream()
        self.engine.midi.disconnect()

    def _refresh_ui(self) -> None:
        transport = self.query_one(TransportBar)
        transport.bpm = self.engine.transport.bpm
        transport.bar_count = self.engine.transport.bar_count
        transport.playing = self.engine.transport.playing
        transport.current_bar = self.engine.transport.current_bar
        transport.god_state = self.engine.capture.state.value

        patterns = self.query_one(PatternList)
        pattern_data = []
        for i, p in enumerate(self.engine.pattern_stack.patterns):
            pattern_data.append({
                "name": p.name,
                "state": p.state.value,
                "volume": p.volume,
                "active": i == self.engine.pattern_stack.active_index,
            })
        patterns.refresh_patterns(pattern_data)

        status = self.query_one(StatusPanel)
        status.update_loop(
            self.engine.transport.loop_progress,
            self.engine.transport.current_bar,
            self.engine.transport.bar_count,
        )
        status.update_passes(self.engine.transport.pass_number)
        status.update_metronome(
            self.engine.metronome.enabled,
            self.engine.metronome.sound.value,
        )

    def action_toggle_play(self) -> None:
        if self.engine.transport.playing:
            self.engine.stop()
        else:
            self.engine.play()

    def action_stop_all(self) -> None:
        self.engine.stop_all()

    def action_god_toggle(self) -> None:
        self.engine.god_toggle()

    def action_undo(self) -> None:
        self.engine.undo_last_pass()

    def action_redo(self) -> None:
        self.engine.redo()

    def action_toggle_metronome(self) -> None:
        self.engine.metronome.toggle()

    def action_bpm_up(self) -> None:
        self.engine.set_bpm(self.engine.transport.bpm + 1)

    def action_bpm_down(self) -> None:
        self.engine.set_bpm(self.engine.transport.bpm - 1)

    def action_set_bars_1(self) -> None:
        self.engine.set_bar_count(1)

    def action_set_bars_2(self) -> None:
        self.engine.set_bar_count(2)

    def action_set_bars_4(self) -> None:
        self.engine.set_bar_count(4)
