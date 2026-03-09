"""Entry point for GOD."""
import json
import logging
import os
import sys
import traceback
from datetime import datetime

LOG_DIR = os.path.expanduser("~/.god/logs")
LOG_FILE = os.path.join(LOG_DIR, "god.log")


def setup_logging():
    os.makedirs(LOG_DIR, exist_ok=True)
    logging.basicConfig(
        filename=LOG_FILE,
        level=logging.DEBUG,
        format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )

    def exception_handler(exc_type, exc_value, exc_tb):
        logging.critical(
            "Uncaught exception:\n%s",
            "".join(traceback.format_exception(exc_type, exc_value, exc_tb)),
        )
        sys.__excepthook__(exc_type, exc_value, exc_tb)

    sys.excepthook = exception_handler


def run():
    setup_logging()
    log = logging.getLogger("god")
    log.info("=" * 60)
    log.info("GOD starting — %s", datetime.now().isoformat())
    log.info("Python %s", sys.version)

    try:
        from god.web.server import engine, run_server

        # Need to import after create_app to get engine reference
        from god.web.server import create_app
        app, sio = create_app()

        # Re-import engine after creation
        from god.web import server
        eng = server.engine

        # Load pad config if it exists
        config_path = os.path.expanduser("~/.god/pads.json")
        if os.path.exists(config_path):
            from god.audio import Sample
            log.info("Loading pad config from %s", config_path)
            with open(config_path) as f:
                pad_config = json.load(f)
            for pad_str, sample_path in pad_config.items():
                pad_idx = int(pad_str)
                if os.path.exists(sample_path):
                    sample = Sample.from_file(sample_path)
                    eng.pad_bank.assign(pad_idx, sample)
                    log.info("Pad %d: %s", pad_idx, sample_path)
                else:
                    log.warning("Pad %d: file not found: %s", pad_idx, sample_path)
        else:
            log.info("No pad config found at %s", config_path)

        # Connect MIDI
        eng.midi.connect()
        log.info("MIDI connected: %s", eng.midi.port_name or "none")

        # Start audio stream
        eng.start_audio_stream()
        log.info("Audio stream started")

        # Start state push thread
        import threading
        state_thread = threading.Thread(target=server._state_loop, daemon=True)
        state_thread.start()

        # Open browser
        import webbrowser
        port = 6660
        webbrowser.open(f"http://127.0.0.1:{port}")

        log.info("GOD web server starting on port %d", port)
        print(f"\n  GOD — Genesis On Disk")
        print(f"  http://127.0.0.1:{port}")
        print(f"  Press Ctrl+C to stop\n")
        sio.run(app, host="127.0.0.1", port=port, debug=False, use_reloader=False, log_output=False)
        log.info("GOD exited normally")

    except KeyboardInterrupt:
        log.info("GOD stopped by user")
        print("\nGOD stopped.")
    except Exception:
        log.critical("GOD crashed:\n%s", traceback.format_exc())
        crash_file = os.path.join(LOG_DIR, "last_crash.txt")
        with open(crash_file, "w") as f:
            f.write(f"GOD crash — {datetime.now().isoformat()}\n\n")
            f.write(traceback.format_exc())
        print(f"\nGOD crashed. See logs:\n  {LOG_FILE}\n  {crash_file}")
        raise


if __name__ == "__main__":
    run()
