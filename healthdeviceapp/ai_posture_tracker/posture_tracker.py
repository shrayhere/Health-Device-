"""
HealthDevice AI Webcam Posture Tracker
======================================
Real-time ergonomic posture detection powered by MediaPipe Pose & OpenCV.
Tracks:
- Vertical torso/spinal sinking & head drop (detects bending back & slouching)
- Forward head posture (craniovertebral angle / ear-to-shoulder compression)
- Shoulder horizontal tilt & alignment
- Absence detection (pauses alerts when user is not in front of camera)

Controls:
- Headless / Background mode support (no visible cmd/console window with pythonw)
- Closeable camera window: closing preview does NOT kill tracker (runs in background)
- Master ON/OFF control via HTTP (/stop)
- Natural studio-quality female voice alert ("Sir" / "Ma'am" / "Neutral" / Beep)
- Escalation alert cycle (4s alert -> Ctrl+B snooze -> 10s visual popup -> 10s repeat)
- Global Ctrl+B hotkey to snooze
"""

import sys
import os
import time
import math
import json
import threading
import argparse
import ctypes
from http.server import HTTPServer, BaseHTTPRequestHandler

# Safeguard imports for OpenCV and MediaPipe
try:
    import cv2
    import numpy as np
    import mediapipe as mp
    from mediapipe.tasks import python as mp_python
    from mediapipe.tasks.python import vision
except Exception as _import_err:
    _script_dir = os.path.dirname(os.path.abspath(__file__))
    _log_path = os.path.join(_script_dir, "tracker_error.log")
    try:
        with open(_log_path, "w", encoding="utf-8") as _f:
            _f.write(f"HealthDevice AI Posture Tracker Prerequisite Error:\n{_import_err}\n")
            import traceback
            traceback.print_exc(file=_f)
    except Exception:
        pass
    try:
        import ctypes
        ctypes.windll.user32.MessageBoxW(
            0,
            f"HealthDevice AI Posture Tracker could not start:\n\n{_import_err}\n\nPlease run 'Setup_Prerequisites.bat' in the Health Device folder to install MediaPipe and OpenCV.",
            "HealthDevice AI - Missing Prerequisites",
            0x10,
        )
    except Exception:
        pass
    sys.exit(1)

# Audio support
try:
    import pygame
    pygame.mixer.init()
    HAS_PYGAME = True
except Exception:
    HAS_PYGAME = False

try:
    import winsound
    HAS_WINSOUND = True
except ImportError:
    HAS_WINSOUND = False

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
BASELINE_FILE = os.path.join(SCRIPT_DIR, "posture_baseline.json")
WINDOW_TITLE = "HealthDevice AI - Webcam Posture Tracker"

def get_current_gender_voice_mode():
    try:
        local_app_data = os.environ.get('LOCALAPPDATA', '') or os.environ.get('APPDATA', '')
        store_path = os.path.join(local_app_data, 'HealthDeviceApp', 'settings_store.json')
        if os.path.exists(store_path):
            with open(store_path, 'r', encoding='utf-8') as sf:
                store_data = json.load(sf)
                bio_sex = store_data.get('hd_health_profile', {}).get('biologicalSex', '')
                if not bio_sex:
                    auth_user = store_data.get('hd_auth_user', {})
                    for u in store_data.get('hd_users_database', []):
                        if u.get('id') == auth_user.get('id') or u.get('email') == auth_user.get('email'):
                            bio_sex = u.get('profile', {}).get('biologicalSex', '')
                            break
                if bio_sex:
                    s = bio_sex.lower()
                    if 'female' in s or 'woman' in s or 'girl' in s:
                        return 'maam'
                    elif 'male' in s or 'man' in s or 'boy' in s:
                        return 'sir'
                    else:
                        return 'neutral'
    except Exception:
        pass
    return None

# -------------------------------------------------------------
# Global State for Telemetry Server & Posture Engine
# -------------------------------------------------------------
class PostureState:
    def __init__(self):
        self.running = True
        self.show_window = True  # Can be toggled on/off without stopping tracker
        self.person_detected = False
        self.posture_score = 100.0
        self.status = "Initializing..."
        self.shoulder_tilt_deg = 0.0
        self.head_forward_pct = 0.0
        self.slouch_seconds = 0.0
        self.good_posture_seconds = 0.0
        self.audio_enabled = True
        self.voice_mode = "sir"  # 'sir', 'maam', 'neutral', 'beep'
        self.alert_delay_seconds = 4.0
        
        # Escalation & Mute Lifecycle
        self.alert_active = False
        self.user_muted = False
        self.mute_timestamp = 0.0
        self.show_visual_popup = False
        self.last_escalated_alert_time = 0.0
        
        # Calibration & Biomechanical Baselines
        self.calibrated = False
        self.base_nose_y = 0.35         # Normalized Y position of nose in frame (0=top, 1=bottom)
        self.base_shoulder_y = 0.58     # Normalized Y position of mid-shoulder
        self.base_neck_ratio = 0.44     # Vertical distance between ear and shoulder / shoulder width
        self.base_shoulder_tilt = 0.0   # Horizontal tilt angle
        self.base_ear_nose_drop = 0.08  # Distance nose is below ear
        self.calibration_feedback = ""
        self.calibration_feedback_time = 0.0
        self.calibration_feedback_color = (0, 230, 115)
        
        # Video frame stream
        self.latest_frame_jpeg = None
        self.lock = threading.Lock()

    def load_baseline(self):
        # 1. First check if user's Health Profile has a saved biological sex in app storage
        profile_gender_mode = get_current_gender_voice_mode()
        if profile_gender_mode:
            self.voice_mode = profile_gender_mode
            print(f"[HealthDevice AI] Detected active profile gender voice mode: {profile_gender_mode}")

        if os.path.exists(BASELINE_FILE):
            try:
                with open(BASELINE_FILE, 'r') as f:
                    data = json.load(f)
                    self.base_nose_y = data.get("base_nose_y", 0.35)
                    self.base_shoulder_y = data.get("base_shoulder_y", 0.58)
                    self.base_neck_ratio = data.get("base_neck_ratio", 0.44)
                    self.base_shoulder_tilt = data.get("base_shoulder_tilt", 0.0)
                    self.base_ear_nose_drop = data.get("base_ear_nose_drop", 0.08)
                    if not profile_gender_mode:
                        self.voice_mode = data.get("voice_mode", self.voice_mode)
                    self.calibrated = True
                    print(f"[HealthDevice AI] Loaded saved baseline: nose_y={self.base_nose_y:.2f}, sh_y={self.base_shoulder_y:.2f}, voice={self.voice_mode}")
            except Exception as e:
                print(f"[HealthDevice AI] Error loading baseline: {e}")

    def save_baseline(self):
        try:
            data = {
                "base_nose_y": round(self.base_nose_y, 4),
                "base_shoulder_y": round(self.base_shoulder_y, 4),
                "base_neck_ratio": round(self.base_neck_ratio, 4),
                "base_shoulder_tilt": round(self.base_shoulder_tilt, 2),
                "base_ear_nose_drop": round(self.base_ear_nose_drop, 4),
                "voice_mode": self.voice_mode,
                "saved_at": time.strftime("%Y-%m-%d %H:%M:%S")
            }
            with open(BASELINE_FILE, 'w') as f:
                json.dump(data, f, indent=2)
            print("[HealthDevice AI] Saved baseline successfully to disk.")
        except Exception as e:
            print(f"[HealthDevice AI] Error saving baseline: {e}")

state = PostureState()
state.load_baseline()

# -------------------------------------------------------------
# Anti-Cheat Upright Posture Validation
# -------------------------------------------------------------
def validate_upright_posture(head_dist_ratio, shoulder_tilt, nose_x_offset, nose_y, shoulder_y):
    """
    Biomechanical validation to prevent cheating by registering a slouched
    or tilted posture as upright.
    """
    if shoulder_tilt > 8.0:
        return False, "Cheat Prevention: Shoulders are tilted (> 8°). Level your shoulders."

    if head_dist_ratio < 0.28:
        return False, "Cheat Prevention: Neck is compressed / slouching. Lift head and sit tall."

    if abs(nose_x_offset) > 0.09:
        return False, "Cheat Prevention: Head is leaning sideways. Center your head."

    if nose_y > shoulder_y - 0.08:
        return False, "Cheat Prevention: Head is hanging too low near shoulders. Sit upright."

    return True, "Valid Upright Posture"

# -------------------------------------------------------------
# Audio Voice & Beep Playback System
# -------------------------------------------------------------
_voice_sounds = {}
_last_audio_trigger_time = 0.0

def load_voice_sounds():
    if not HAS_PYGAME:
        return
    voice_files = {
        'sir': 'voice_sir.mp3',
        'maam': 'voice_maam.mp3',
        'neutral': 'voice_neutral.mp3',
        'reminder': 'voice_reminder.mp3'
    }
    for mode, filename in voice_files.items():
        path = os.path.join(SCRIPT_DIR, filename)
        if os.path.exists(path):
            try:
                _voice_sounds[mode] = pygame.mixer.Sound(path)
            except Exception as e:
                print(f"[Audio] Error loading {path}: {e}")

load_voice_sounds()

def play_alert_sound(reminder=False):
    global _last_audio_trigger_time
    now = time.time()
    if now - _last_audio_trigger_time < 3.0:
        return
    _last_audio_trigger_time = now

    def _play_thread():
        try:
            # Dynamically check latest profile gender immediately before speaking
            active_gender = get_current_gender_voice_mode()
            if active_gender and active_gender != state.voice_mode:
                state.voice_mode = active_gender

            mode = 'reminder' if reminder else state.voice_mode
            print(f"[Audio] Triggering posture alert: mode='{mode}' (gender voice='{state.voice_mode}')")
            if mode == 'beep' or not HAS_PYGAME or mode not in _voice_sounds:
                if HAS_WINSOUND:
                    winsound.Beep(980, 260)
                    time.sleep(0.08)
                    winsound.Beep(1200, 320)
            else:
                snd = _voice_sounds.get(mode)
                if snd:
                    snd.stop()
                    snd.play()
                elif HAS_WINSOUND:
                    winsound.Beep(980, 260)
        except Exception as e:
            print(f"[Audio] Play error: {e}")

    threading.Thread(target=_play_thread, daemon=True).start()

# -------------------------------------------------------------
# Telemetry HTTP Server (Communicates with Flutter App)
# -------------------------------------------------------------
class TelemetryHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        pass

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()

    def do_GET(self):
        if self.path == '/status':
            current_gender = get_current_gender_voice_mode()
            if current_gender and current_gender != state.voice_mode:
                state.voice_mode = current_gender
            with state.lock:
                data = {
                    "running": state.running,
                    "windowVisible": state.show_window,
                    "personDetected": state.person_detected,
                    "postureScore": int(state.posture_score) if state.person_detected else 0,
                    "status": state.status,
                    "shoulderTiltDeg": round(state.shoulder_tilt_deg, 1) if state.person_detected else 0.0,
                    "headForwardPct": round(state.head_forward_pct, 1) if state.person_detected else 0.0,
                    "slouchSeconds": round(state.slouch_seconds, 1),
                    "goodPostureSeconds": int(state.good_posture_seconds),
                    "beepEnabled": state.audio_enabled,
                    "voiceMode": state.voice_mode,
                    "showPopup": state.show_visual_popup,
                    "calibrated": state.calibrated,
                    "calibrationFeedback": state.calibration_feedback,
                }
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(data).encode('utf-8'))

        elif self.path == '/video_feed':
            self.send_response(200)
            self.send_header('Content-Type', 'multipart/x-mixed-replace; boundary=frame')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            try:
                while state.running:
                    with state.lock:
                        frame_bytes = state.latest_frame_jpeg
                    if frame_bytes is not None:
                        self.wfile.write(b'--frame\r\n')
                        self.send_header('Content-Type', 'image/jpeg')
                        self.send_header('Content-Length', str(len(frame_bytes)))
                        self.end_headers()
                        self.wfile.write(frame_bytes)
                        self.wfile.write(b'\r\n')
                    time.sleep(0.04)
            except Exception:
                pass
        else:
            self.send_response(404)
            self.end_headers()

    def do_POST(self):
        length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(length).decode('utf-8') if length > 0 else ""
        payload = {}
        if body:
            try:
                payload = json.loads(body)
            except Exception:
                pass

        if self.path == '/calibrate':
            with state.lock:
                state.calibrated = False # Trigger calibration check on next frame
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "checking"}).encode('utf-8'))

        elif self.path == '/dismiss_alert':
            dismiss_or_snooze_alert()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "dismissed"}).encode('utf-8'))

        elif self.path == '/toggle_window':
            with state.lock:
                state.show_window = not state.show_window
                current = state.show_window
            if not current:
                try:
                    cv2.destroyAllWindows()
                except Exception:
                    pass
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"windowVisible": current}).encode('utf-8'))

        elif self.path == '/toggle_beep':
            with state.lock:
                state.audio_enabled = not state.audio_enabled
                resp = {"beepEnabled": state.audio_enabled}
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps(resp).encode('utf-8'))

        elif self.path == '/set_voice_mode':
            mode = payload.get("mode", "sir")
            if mode in ["sir", "maam", "neutral", "beep"]:
                with state.lock:
                    state.voice_mode = mode
                state.save_baseline()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"voiceMode": state.voice_mode}).encode('utf-8'))

        elif self.path == '/stop':
            # Master Stop
            with state.lock:
                state.running = False
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Access-Control-Allow-Origin', '*')
            self.end_headers()
            self.wfile.write(json.dumps({"status": "stopping"}).encode('utf-8'))
        else:
            self.send_response(404)
            self.end_headers()

class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True

def start_server(port=8765):
    try:
        server = ReusableHTTPServer(('127.0.0.1', port), TelemetryHandler)
    except Exception as e:
        print(f"[HealthDevice AI] Warning: Port {port} bind error ({e}), retrying in 0.5s...")
        time.sleep(0.5)
        server = ReusableHTTPServer(('127.0.0.1', port), TelemetryHandler)
    server_thread = threading.Thread(target=server.serve_forever, daemon=True)
    server_thread.start()
    return server


# -------------------------------------------------------------
# Dismissal / Snooze Logic (Ctrl+B Action)
# -------------------------------------------------------------
def dismiss_or_snooze_alert():
    now = time.time()
    with state.lock:
        state.alert_active = False
        state.user_muted = True
        state.mute_timestamp = now
        state.show_visual_popup = False
    print("[HealthDevice AI] Alert dismissed / snoozed via Ctrl+B shortcut.")

# -------------------------------------------------------------
# Windows Global Hotkey Listener (Ctrl + B)
# -------------------------------------------------------------
def start_global_hotkey_listener():
    if os.name != 'nt':
        return

    def _listener():
        try:
            user32 = ctypes.windll.user32
            MOD_CONTROL = 0x0002
            VK_B = 0x42
            HOTKEY_ID = 101

            if not user32.RegisterHotKey(None, HOTKEY_ID, MOD_CONTROL, VK_B):
                print("[Hotkey] Could not register global Ctrl+B hotkey.")
                return

            msg = ctypes.wintypes.MSG()
            while user32.GetMessageW(ctypes.byref(msg), None, 0, 0) != 0:
                if msg.message == 0x0312:
                    dismiss_or_snooze_alert()
                user32.TranslateMessage(ctypes.byref(msg))
                user32.DispatchMessageW(ctypes.byref(msg))
        except Exception as e:
            print(f"[Hotkey] Error in hotkey thread: {e}")

    threading.Thread(target=_listener, daemon=True).start()

# -------------------------------------------------------------
# Visual Posture Correction Animation Overlay Renderer
# -------------------------------------------------------------
def draw_visual_correction_popup(frame, w, h, anim_step):
    overlay = frame.copy()
    box_w = min(560, w - 40)
    box_h = min(340, h - 40)
    x1 = (w - box_w) // 2
    y1 = (h - box_h) // 2
    x2 = x1 + box_w
    y2 = y1 + box_h

    cv2.rectangle(overlay, (0, 0), (w, h), (10, 15, 25), -1)
    cv2.addWeighted(overlay, 0.70, frame, 0.30, 0, frame)

    card_bg = frame.copy()
    cv2.rectangle(card_bg, (x1, y1), (x2, y2), (20, 28, 48), -1)
    cv2.addWeighted(card_bg, 0.95, frame, 0.05, 0, frame)

    pulse_val = int(127 + 127 * math.sin(anim_step * 0.15))
    border_color = (0, pulse_val, 255)
    cv2.rectangle(frame, (x1, y1), (x2, y2), border_color, 2)

    cv2.rectangle(frame, (x1, y1), (x2, y1 + 54), (180, 40, 40), -1)
    cv2.putText(frame, "! PLEASE FIX YOUR POSTURE !", (x1 + 30, y1 + 36),
                cv2.FONT_HERSHEY_SIMPLEX, 0.75, (255, 255, 255), 2)

    cv2.putText(frame, "Back bending or slouching detected for > 10 seconds.",
                (x1 + 25, y1 + 80), cv2.FONT_HERSHEY_SIMPLEX, 0.50, (200, 200, 200), 1)

    col1_cx = x1 + box_w // 4
    base_y = y1 + 230

    cv2.putText(frame, "SLOUCHED (NO)", (col1_cx - 55, y1 + 115),
                cv2.FONT_HERSHEY_SIMPLEX, 0.50, (60, 60, 255), 2)
    pts_slouch = np.array([
        [col1_cx + 15, base_y],
        [col1_cx - 20, base_y - 45],
        [col1_cx - 35, base_y - 75],
        [col1_cx - 20, base_y - 100]
    ], np.int32)
    cv2.polylines(frame, [pts_slouch], False, (60, 60, 255), 3)
    cv2.circle(frame, (col1_cx - 25, base_y - 110), 14, (60, 60, 255), -1)
    cv2.putText(frame, "X", (col1_cx - 45, base_y - 45),
                cv2.FONT_HERSHEY_SIMPLEX, 0.9, (60, 60, 255), 2)

    mid_x = x1 + box_w // 2
    cv2.line(frame, (mid_x, y1 + 105), (mid_x, y1 + 260), (60, 75, 100), 1)

    col2_cx = x1 + (box_w * 3) // 4
    cv2.putText(frame, "UPRIGHT (YES)", (col2_cx - 55, y1 + 115),
                cv2.FONT_HERSHEY_SIMPLEX, 0.50, (0, 230, 115), 2)
    cv2.line(frame, (col2_cx, base_y), (col2_cx, base_y - 95), (0, 230, 115), 3)
    cv2.line(frame, (col2_cx - 25, base_y - 80), (col2_cx + 25, base_y - 80), (0, 230, 115), 3)
    cv2.circle(frame, (col2_cx, base_y - 115), 14, (0, 230, 115), -1)
    cv2.putText(frame, "OK", (col2_cx + 20, base_y - 45),
                cv2.FONT_HERSHEY_SIMPLEX, 0.8, (0, 230, 115), 2)

    action_banner_y = y2 - 40
    cv2.rectangle(frame, (x1 + 10, action_banner_y), (x2 - 10, y2 - 8), (30, 42, 68), -1)
    cv2.putText(frame, "Sit straight with level shoulders, or press Ctrl+B to snooze",
                (x1 + 20, action_banner_y + 22), cv2.FONT_HERSHEY_SIMPLEX, 0.44, (0, 230, 255), 1)

# -------------------------------------------------------------
# Main Computer Vision & Posture Engine
# -------------------------------------------------------------
def run_posture_tracker(camera_index=0, start_window=True, port=8765, voice_mode=None):
    state.show_window = start_window
    if voice_mode and voice_mode in ["sir", "maam", "neutral", "beep"]:
        state.voice_mode = voice_mode
    model_path = os.path.join(SCRIPT_DIR, "pose_landmarker_lite.task")
    if not os.path.exists(model_path):
        parent_model = os.path.join(os.path.dirname(SCRIPT_DIR), "pose_landmarker_lite.task")
        if os.path.exists(parent_model):
            model_path = parent_model
        else:
            print(f"[Error] Model file not found at {model_path}")
            sys.exit(1)

    print(f"[HealthDevice AI] Loading Pose Landmarker model: {model_path}...")
    base_options = mp_python.BaseOptions(model_asset_path=model_path)
    options = vision.PoseLandmarkerOptions(
        base_options=base_options,
        running_mode=vision.RunningMode.IMAGE,
        num_poses=1,
        min_pose_detection_confidence=0.5,
        min_pose_presence_confidence=0.5,
        min_tracking_confidence=0.5,
    )
    landmarker = vision.PoseLandmarker.create_from_options(options)

    # Start Telemetry HTTP server
    start_server(port)
    print(f"[HealthDevice AI] Telemetry server active at http://127.0.0.1:{port}/status")

    # Start global Ctrl+B hotkey listener
    start_global_hotkey_listener()

    # Initialize Webcam with retry across available backends & indices
    cap = None
    for cam_idx in [camera_index, 0, 1]:
        backends = [cv2.CAP_DSHOW, cv2.CAP_ANY] if os.name == 'nt' else [cv2.CAP_ANY]
        for backend in backends:
            try:
                temp_cap = cv2.VideoCapture(cam_idx, backend)
                if temp_cap and temp_cap.isOpened():
                    cap = temp_cap
                    camera_index = cam_idx
                    break
                elif temp_cap:
                    temp_cap.release()
            except Exception:
                pass
        if cap is not None and cap.isOpened():
            break

    if cap is None or not cap.isOpened():
        print(f"[HealthDevice AI] Notice: Webcam index {camera_index} could not be opened. Telemetry server running in standby.")
        state.status = "Camera Unavailable"
        state.person_detected = False
        while state.running:
            time.sleep(0.5)
        return

    cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
    cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
    cap.set(cv2.CAP_PROP_FPS, 30)

    print("[HealthDevice AI] Webcam posture engine running in background.")

    last_loop_time = time.time()
    last_adaptive_save_time = time.time()
    anim_step = 0
    window_created = False

    try:
        while state.running:
            ret, frame = cap.read()
            if not ret:
                time.sleep(0.03)
                continue

            frame = cv2.flip(frame, 1)
            h, w, _ = frame.shape
            current_time = time.time()
            dt = current_time - last_loop_time
            last_loop_time = current_time
            anim_step += 1

            rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
            mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=rgb_frame)
            detection_result = landmarker.detect(mp_image)

            if detection_result.pose_landmarks and len(detection_result.pose_landmarks) > 0:
                landmarks = detection_result.pose_landmarks[0]
                state.person_detected = True

                nose = landmarks[0]
                left_ear = landmarks[7]
                right_ear = landmarks[8]
                left_sh = landmarks[11]
                right_sh = landmarks[12]

                px_nose = (int(nose.x * w), int(nose.y * h))
                px_left_ear = (int(left_ear.x * w), int(left_ear.y * h))
                px_right_ear = (int(right_ear.x * w), int(right_ear.y * h))
                px_left_sh = (int(left_sh.x * w), int(left_sh.y * h))
                px_right_sh = (int(right_sh.x * w), int(right_sh.y * h))

                curr_nose_y = nose.y
                mid_sh_x = (px_left_sh[0] + px_right_sh[0]) / 2.0
                mid_sh_y = (px_left_sh[1] + px_right_sh[1]) / 2.0
                curr_shoulder_y = mid_sh_y / h
                mid_ear_y = (px_left_ear[1] + px_right_ear[1]) / 2.0
                curr_mid_ear_y = mid_ear_y / h

                shoulder_width = math.hypot(px_right_sh[0] - px_left_sh[0], px_right_sh[1] - px_left_sh[1])
                if shoulder_width < 10:
                    shoulder_width = 10

                sh_dy = px_right_sh[1] - px_left_sh[1]
                sh_dx = px_right_sh[0] - px_left_sh[0]
                shoulder_tilt = abs(math.degrees(math.atan2(sh_dy, sh_dx)))
                if shoulder_tilt > 90:
                    shoulder_tilt = abs(180 - shoulder_tilt)

                head_dist_ratio = (mid_sh_y - mid_ear_y) / shoulder_width
                nose_x_offset = (nose.x - (left_sh.x + right_sh.x) / 2.0)

                # -------------------------------------------------------------
                # Calibration & Anti-Cheat Logic
                # -------------------------------------------------------------
                if not state.calibrated:
                    is_valid, reason = validate_upright_posture(
                        head_dist_ratio, shoulder_tilt, nose_x_offset, curr_nose_y, curr_shoulder_y
                    )
                    if is_valid:
                        state.base_nose_y = curr_nose_y
                        state.base_shoulder_y = curr_shoulder_y
                        state.base_neck_ratio = head_dist_ratio
                        state.base_shoulder_tilt = shoulder_tilt
                        state.base_ear_nose_drop = curr_nose_y - curr_mid_ear_y
                        state.calibrated = True
                        state.calibration_feedback = "Upright Baseline Calibrated!"
                        state.calibration_feedback_color = (0, 230, 115)
                        state.calibration_feedback_time = current_time
                        state.save_baseline()
                        print(f"[HealthDevice AI] Valid baseline saved: nose_y={curr_nose_y:.2f}, sh_y={curr_shoulder_y:.2f}, tilt={shoulder_tilt:.1f}°")
                    else:
                        state.calibration_feedback = reason
                        state.calibration_feedback_color = (60, 60, 255)
                        state.calibration_feedback_time = current_time
                        state.calibrated = True # Stop continuous check; keep prior baseline
                        print(f"[HealthDevice AI] {reason}")

                # -------------------------------------------------------------
                # Multi-Factor Ergonomic Biomechanical Slouch Engine
                # (Detects Back Bending, Head Drop, Neck Compression, and Tilt)
                # -------------------------------------------------------------
                # 1. Torso / Shoulder Vertical Drop (Back bending causes shoulders to sink down)
                shoulder_drop = max(0.0, curr_shoulder_y - state.base_shoulder_y)
                shoulder_drop_penalty = min(50.0, shoulder_drop * 450.0)

                # 2. Head / Nose Vertical Drop (Bending forward causes head to sink down in frame)
                head_drop = max(0.0, curr_nose_y - state.base_nose_y)
                head_drop_penalty = min(50.0, head_drop * 400.0)

                # 3. Craniovertebral Neck Compression (Ear scrunches toward shoulders)
                neck_diff = max(0.0, state.base_neck_ratio - head_dist_ratio)
                neck_penalty = min(40.0, neck_diff * 200.0)

                # 4. Chin / Head Droop (Nose drops significantly relative to ears)
                ear_nose_diff = max(0.0, (curr_nose_y - curr_mid_ear_y) - state.base_ear_nose_drop)
                chin_penalty = min(30.0, ear_nose_diff * 250.0)

                # 5. Shoulder Tilt Penalty
                tilt_diff = max(0.0, shoulder_tilt - state.base_shoulder_tilt)
                tilt_penalty = min(30.0, tilt_diff * 3.0)

                # Combined Slouch Penalty
                total_slouch_penalty = shoulder_drop_penalty + head_drop_penalty + neck_penalty + chin_penalty + tilt_penalty
                raw_score = max(10.0, min(100.0, 100.0 - total_slouch_penalty))

                # Highly responsive smoothing (alpha = 0.35 so back bending registers immediately)
                state.posture_score = (state.posture_score * 0.65) + (raw_score * 0.35)
                state.shoulder_tilt_deg = shoulder_tilt
                state.head_forward_pct = min(100.0, max(0.0, total_slouch_penalty))

                # Adaptive continuous upright refinement (only when confirmed strictly upright)
                if state.posture_score >= 88.0 and shoulder_tilt <= 4.0 and shoulder_drop < 0.01:
                    state.base_nose_y = (state.base_nose_y * 0.998) + (curr_nose_y * 0.002)
                    state.base_shoulder_y = (state.base_shoulder_y * 0.998) + (curr_shoulder_y * 0.002)
                    state.base_neck_ratio = (state.base_neck_ratio * 0.998) + (head_dist_ratio * 0.002)
                    if current_time - last_adaptive_save_time > 120.0:
                        state.save_baseline()
                        last_adaptive_save_time = current_time

                # Posture Status
                is_slouching = state.posture_score < 75.0
                if state.posture_score >= 82:
                    current_status = "Good Posture"
                    status_color = (0, 230, 115) # Green
                    state.good_posture_seconds += dt
                    state.slouch_seconds = 0.0
                    state.alert_active = False
                    state.user_muted = False
                    state.show_visual_popup = False
                elif state.posture_score >= 68:
                    current_status = "Mild Slouch"
                    status_color = (0, 190, 255) # Orange
                    state.slouch_seconds += dt
                else:
                    current_status = "Slouch Detected!"
                    status_color = (60, 60, 255) # Red
                    state.slouch_seconds += dt

                # Escalation Lifecycle: 4s Alert -> Snooze -> 10s Popup -> 10s Loop
                if is_slouching and state.audio_enabled:
                    if state.slouch_seconds >= state.alert_delay_seconds and not state.alert_active and not state.user_muted:
                        state.alert_active = True
                        play_alert_sound(reminder=False)
                        current_status = "ALERT: Please Sit Straight!"

                    if state.user_muted and (current_time - state.mute_timestamp >= 10.0):
                        if not state.show_visual_popup:
                            state.show_visual_popup = True
                            state.last_escalated_alert_time = current_time
                            play_alert_sound(reminder=True)

                    if state.show_visual_popup and (current_time - state.last_escalated_alert_time >= 10.0):
                        state.last_escalated_alert_time = current_time
                        play_alert_sound(reminder=True)

                state.status = current_status

                # ── Corner Mini Skeleton Diagram (bottom-right, off the face) ──
                # Panel dimensions
                panel_w, panel_h = 110, 120
                px0 = w - panel_w - 10   # top-left x of panel
                py0 = h - panel_h - 10   # top-left y of panel

                # Semi-transparent dark background for the panel
                panel_overlay = frame.copy()
                cv2.rectangle(panel_overlay, (px0, py0), (px0 + panel_w, py0 + panel_h), (12, 18, 32), -1)
                cv2.addWeighted(panel_overlay, 0.78, frame, 0.22, 0, frame)
                cv2.rectangle(frame, (px0, py0), (px0 + panel_w, py0 + panel_h), status_color, 1)

                # Diagram center x, and key y positions inside the panel
                cx = px0 + panel_w // 2
                head_cy   = py0 + 22     # head circle center y
                ear_l_x   = cx - 16      # left ear x
                ear_r_x   = cx + 16      # right ear x
                ear_y     = py0 + 30     # ear y
                neck_top  = py0 + 38     # top of neck line
                sh_y      = py0 + 60     # shoulder line y
                sh_l_x    = cx - 24      # left shoulder x
                sh_r_x    = cx + 24      # right shoulder x
                spine_bot = py0 + 100    # bottom of spine

                # Head circle
                cv2.circle(frame, (cx, head_cy), 13, status_color, 2)

                # Ears (small filled dots)
                cv2.circle(frame, (ear_l_x, ear_y), 3, (255, 200, 50), -1)
                cv2.circle(frame, (ear_r_x, ear_y), 3, (255, 200, 50), -1)

                # Neck line (head bottom → shoulder midpoint)
                cv2.line(frame, (cx, head_cy + 13), (cx, sh_y), status_color, 2)

                # Shoulder line
                cv2.line(frame, (sh_l_x, sh_y), (sh_r_x, sh_y), status_color, 3)

                # Ear-to-shoulder lines (shows tilt / compression)
                cv2.line(frame, (ear_l_x, ear_y), (sh_l_x, sh_y), (255, 200, 50), 1)
                cv2.line(frame, (ear_r_x, ear_y), (sh_r_x, sh_y), (255, 200, 50), 1)

                # Spine stub
                cv2.line(frame, (cx, sh_y), (cx, spine_bot), status_color, 2)

                # Label at bottom of panel
                cv2.putText(frame, "POSTURE", (px0 + 14, py0 + panel_h - 6),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.32, status_color, 1)

            else:
                # User stepped away from camera
                state.person_detected = False
                state.status = "No Person in Camera"
                status_color = (150, 150, 150)
                # Pause slouch timer and alerts when nobody is in camera!
                state.slouch_seconds = 0.0
                state.alert_active = False
                state.show_visual_popup = False

            # Top HUD Header & Score Banner
            hud_overlay = frame.copy()
            cv2.rectangle(hud_overlay, (0, 0), (w, 74), (15, 23, 42), -1)
            cv2.addWeighted(hud_overlay, 0.75, frame, 0.25, 0, frame)

            score_int = int(state.posture_score) if state.person_detected else 0
            score_text = f"Posture: {score_int}%" if state.person_detected else "Posture: --"
            cv2.putText(frame, score_text, (16, 32), cv2.FONT_HERSHEY_SIMPLEX, 0.85, (255, 255, 255), 2)
            cv2.putText(frame, state.status, (16, 62), cv2.FONT_HERSHEY_SIMPLEX, 0.65, status_color, 2)

            audio_label = f"Voice: {state.voice_mode.upper()}" if state.audio_enabled else "Mute: OFF"
            cv2.putText(frame, audio_label, (w - 180, 32), cv2.FONT_HERSHEY_SIMPLEX, 0.52, (0, 230, 255), 1)
            cv2.putText(frame, "[C] Calibrate | [X] Hide Window", (w - 270, 62), cv2.FONT_HERSHEY_SIMPLEX, 0.44, (180, 180, 180), 1)

            if current_time - state.calibration_feedback_time < 3.0 and state.calibration_feedback:
                fb_overlay = frame.copy()
                toast_y = h - 60
                cv2.rectangle(fb_overlay, (20, toast_y), (w - 20, toast_y + 40), (15, 23, 42), -1)
                cv2.addWeighted(fb_overlay, 0.85, frame, 0.15, 0, frame)
                cv2.rectangle(frame, (20, toast_y), (w - 20, toast_y + 40), state.calibration_feedback_color, 2)
                cv2.putText(frame, state.calibration_feedback, (32, toast_y + 26),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.46, (255, 255, 255), 1)

            if state.show_visual_popup and state.person_detected:
                draw_visual_correction_popup(frame, w, h, anim_step)

            # Encode latest frame for web streaming
            _, jpeg_buffer = cv2.imencode('.jpg', frame, [cv2.IMWRITE_JPEG_QUALITY, 70])
            with state.lock:
                state.latest_frame_jpeg = jpeg_buffer.tobytes()

            # ---------------------------------------------------------
            # Closeable Window Logic (Closing preview keeps tracking in BG)
            # ---------------------------------------------------------
            if state.show_window:
                cv2.imshow(WINDOW_TITLE, frame)
                window_created = True
                key = cv2.waitKey(1) & 0xFF

                # Check if user clicked the X button on the OpenCV window:
                # getWindowProperty returns -1 or < 1 when closed by the user
                try:
                    visible = cv2.getWindowProperty(WINDOW_TITLE, cv2.WND_PROP_VISIBLE)
                    if visible < 1:
                        # User clicked the X button!
                        print("[HealthDevice AI] Camera window closed by user. Tracker continues in background.")
                        cv2.destroyAllWindows()
                        window_created = False
                        state.show_window = False
                except Exception:
                    pass

                if key == ord('q') or key == 27:
                    # User pressed 'q' or Esc -> Hide window, keep tracker running
                    cv2.destroyAllWindows()
                    window_created = False
                    state.show_window = False
                elif key == ord('c') or key == ord('C'):
                    with state.lock:
                        state.calibrated = False
                elif key == 2 or key == ord('b') or key == ord('B'):
                    dismiss_or_snooze_alert()
            else:
                if window_created:
                    cv2.destroyAllWindows()
                    window_created = False
                time.sleep(0.02)

    finally:
        state.running = False
        cap.release()
        try:
            cv2.destroyAllWindows()
        except Exception:
            pass
        print("[HealthDevice AI] Posture Tracker fully stopped. Camera released.")

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description="HealthDevice AI Webcam Posture Tracker")
    parser.add_argument("--camera", type=int, default=0, help="Camera device index (default: 0)")
    parser.add_argument("--window", action="store_true", default=False, help="Show OpenCV window on startup")
    parser.add_argument("--port", type=int, default=8765, help="Telemetry HTTP server port (default: 8765)")
    parser.add_argument("--voice-mode", type=str, default=None, help="Voice alert mode (sir/maam/neutral/beep)")
    args, _ = parser.parse_known_args()

    run_posture_tracker(
        camera_index=args.camera,
        start_window=args.window,
        port=args.port,
        voice_mode=args.voice_mode
    )
