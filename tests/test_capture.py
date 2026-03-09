import numpy as np
from god.capture import GodCapture, CaptureState


def test_capture_initial_state():
    cap = GodCapture(sample_rate=44100)
    assert cap.state == CaptureState.IDLE


def test_capture_arm():
    cap = GodCapture(sample_rate=44100)
    cap.arm()
    assert cap.state == CaptureState.ARMED


def test_capture_start_on_pass():
    cap = GodCapture(sample_rate=44100)
    cap.arm()
    cap.on_loop_boundary()
    assert cap.state == CaptureState.RECORDING


def test_capture_write_buffer():
    cap = GodCapture(sample_rate=44100)
    cap.arm()
    cap.on_loop_boundary()
    buf = np.zeros(1024, dtype=np.float32)
    cap.write(buf)
    assert cap.frames_recorded == 1024


def test_capture_stop_saves_file(tmp_path):
    cap = GodCapture(sample_rate=44100, output_dir=str(tmp_path))
    cap.arm()
    cap.on_loop_boundary()
    buf = np.random.randn(44100).astype(np.float32)
    cap.write(buf)
    path = cap.stop()
    assert path is not None
    assert path.endswith(".wav")
    import soundfile as sf
    data, sr = sf.read(path)
    assert sr == 44100
    assert len(data) == 44100


def test_capture_idle_ignores_write():
    cap = GodCapture(sample_rate=44100)
    buf = np.zeros(1024, dtype=np.float32)
    cap.write(buf)
    assert cap.frames_recorded == 0
