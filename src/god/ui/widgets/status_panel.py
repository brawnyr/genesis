"""Status panel — loop position, pass counter, visual indicators."""
from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import Static
from god.ui.theme import SYMBOLS


class StatusPanel(Widget):
    DEFAULT_CSS = """
    StatusPanel {
        height: 5;
        dock: bottom;
        background: #16213e;
        border-top: solid #7c6fe0;
        padding: 0 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Static("", id="loop-bar")
        yield Static("", id="pass-counter")
        yield Static("", id="metronome-status")

    def update_loop(self, progress: float, current_bar: int, total_bars: int) -> None:
        width = 40
        filled = int(progress * width)
        bar = SYMBOLS["bar_fill"] * filled + SYMBOLS["bar_empty"] * (width - filled)
        self.query_one("#loop-bar", Static).update(f" BAR {current_bar}/{total_bars}  {bar} ")

    def update_passes(self, count: int) -> None:
        max_display = 16
        shown = min(count, max_display)
        dots = SYMBOLS["pass_dot"] * shown
        if count > max_display:
            dots += f" +{count - max_display}"
        self.query_one("#pass-counter", Static).update(f" PASSES  {dots} ")

    def update_metronome(self, enabled: bool, sound_name: str) -> None:
        state = "ON" if enabled else "OFF"
        self.query_one("#metronome-status", Static).update(f" METRONOME {state}  {sound_name} ")
