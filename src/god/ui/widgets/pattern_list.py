"""Pattern list — shows stacked patterns with state indicators."""
from textual.app import ComposeResult
from textual.widget import Widget
from textual.widgets import Static
from god.ui.theme import SYMBOLS


class PatternRow(Static):
    DEFAULT_CSS = """
    PatternRow { height: 1; padding: 0 1; }
    PatternRow.playing { color: #4ade80; }
    PatternRow.muted { color: #6b7280; }
    PatternRow.recording { color: #ef4444; text-style: bold; }
    """

    def __init__(self, name: str, state: str, volume: float, index: int, active: bool = False):
        self._pattern_name = name
        self._state = state
        self._volume = volume
        self._index = index
        self._active = active
        super().__init__(self._render())
        self.add_class(state)

    def _render(self) -> str:
        symbol = SYMBOLS.get(self._state, SYMBOLS["empty"])
        active_marker = "\u2192" if self._active else " "
        vol_bar = "\u2588" * int(self._volume * 8) + "\u2591" * (8 - int(self._volume * 8))
        return f" {active_marker} {symbol} {self._pattern_name:<16} {vol_bar} "


class PatternList(Widget):
    DEFAULT_CSS = """
    PatternList {
        height: 1fr;
        border: solid #7c6fe0;
        background: #16213e;
        padding: 1;
    }
    """

    def compose(self) -> ComposeResult:
        yield Static(" PATTERNS ", id="pattern-header")

    def refresh_patterns(self, patterns: list[dict]) -> None:
        for row in self.query(PatternRow):
            row.remove()
        for i, p in enumerate(patterns):
            self.mount(PatternRow(
                name=p["name"], state=p["state"], volume=p["volume"],
                index=i, active=p.get("active", False),
            ))
