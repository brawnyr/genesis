"""Entry point for GOD."""
import json
import os


def run():
    from god.audio import Sample
    from god.ui.app import GodApp

    app = GodApp()

    # Load pad config if it exists
    config_path = os.path.expanduser("~/.god/pads.json")
    if os.path.exists(config_path):
        with open(config_path) as f:
            pad_config = json.load(f)
        for pad_str, sample_path in pad_config.items():
            pad_idx = int(pad_str)
            if os.path.exists(sample_path):
                sample = Sample.from_file(sample_path)
                app.engine.pad_bank.assign(pad_idx, sample)

    app.run()


if __name__ == "__main__":
    run()
