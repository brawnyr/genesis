"""Transport bar — tempo, bars, play/stop, GOD button."""
from textual.app import ComposeResult
from textual.reactive import reactive
from textual.widget import Widget
from textual.widgets import Static
from god.ui.theme import COLORS, SYMBOLS


class TransportBar(Widget):
    DEFAULT_CSS = """
    TransportBar {
        dock: top;
        height: 3;
        background: #16213e;
        border-bottom: solid #7c6fe0;
        layout: horizontal;
        padding: 0 1;
    }
    .transport-section {
        width: auto;
        padding: 0 2;
        content-align: center middle;
        height: 100%;
    }
    .tempo-display { color: #e0e0e0; text-style: bold; }
    .bar-display { color: #7a7a9e; }
    .god-status { color: #e0e0e0; }
    """

    bpm: reactive[int] = reactive(120)
    bar_count: reactive[int] = reactive(1)
    playing: reactive[bool] = reactive(False)
    current_bar: reactive[int] = reactive(1)
    god_state: reactive[str] = reactive("idle")

    def compose(self) -> ComposeResult:
        yield Static("", id="tempo", classes="transport-section tempo-display")
        yield Static("", id="bars", classes="transport-section bar-display")
        yield Static("", id="loop-pos", classes="transport-section")
        yield Static("", id="god", classes="transport-section god-status")

    def watch_bpm(self, value: int) -> None:
        self.query_one("#tempo", Static).update(f" {value} BPM ")

    def watch_bar_count(self, value: int) -> None:
        self.query_one("#bars", Static).update(f" {value} BAR{'S' if value > 1 else ''} ")

    def watch_playing(self, value: bool) -> None:
        symbol = SYMBOLS["playing"] if value else SYMBOLS["muted"]
        self.query_one("#loop-pos", Static).update(f" {symbol} ")

    def watch_god_state(self, value: str) -> None:
        symbol = SYMBOLS.get(f"god_{value}", SYMBOLS["god_idle"])
        label = {"idle": "GOD", "armed": "GOD ARMED", "recording": "GOD REC"}
        self.query_one("#god", Static).update(f" {symbol} {label.get(value, 'GOD')} ")
