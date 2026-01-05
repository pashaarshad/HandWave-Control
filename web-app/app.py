import eventlet
eventlet.monkey_patch()

from flask import Flask, render_template, Response
from flask_socketio import SocketIO, emit
import cv2
import mediapipe as mp
import numpy as np
import time

# Initialize Flask app
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*", async_mode='eventlet')

# --- MEDIAPIPE SETUP ---
mp_hands = mp.solutions.hands
mp_drawing = mp.solutions.drawing_utils

hands = mp_hands.Hands(
    static_image_mode=False,
    max_num_hands=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.7
)

# Global variables
camera = None
prev_wrist_y = None
scroll_cooldown = 0

def generate_frames():
    global prev_wrist_y, scroll_cooldown, camera
    camera = cv2.VideoCapture(0)
    
    # Scroll State Machine
    # We track if the finger is currently 'ABOVE' (y < 0.5) or 'BELOW' (y > 0.5) the line
    last_position_state = None # "ABOVE" or "BELOW"
    
    # Volume State
    current_volume_percent = 50 
    
    while True:
        success, frame = camera.read()
        if not success:
            break

        frame = cv2.flip(frame, 1)
        h, w, c = frame.shape
        
        # 2. VOLUME ZONE (Left side, 20%)
        vol_zone_w = int(w * 0.20)
        
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(frame_rgb)
        
        scroll_action = None
        is_in_vol_zone = False
        
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                thumb_tip = hand_landmarks.landmark[4]
                index_tip = hand_landmarks.landmark[8]
                pinky_tip = hand_landmarks.landmark[20]
                wrist = hand_landmarks.landmark[0]

                # --- CHECK HAND OPEN STATE ---
                # Calculate pinch/hand open metrics
                pinch_dist = np.sqrt((thumb_tip.x - index_tip.x)**2 + (thumb_tip.y - index_tip.y)**2)
                pinky_dist = np.sqrt((pinky_tip.x - wrist.x)**2 + (pinky_tip.y - wrist.y)**2)
                
                is_hand_open = (pinch_dist > 0.1) and (pinky_dist > 0.15)
                
                # --- CURSOR COLOR & MODE LOGIC ---
                if is_hand_open:
                    # OPEN HAND -> RED -> MODE: PREV ONLY
                    cursor_color = (0, 0, 255) # Red (BGR)
                    mode = "PREV_ONLY"
                else:
                    # CLOSED/SINGLE -> GREEN -> MODE: NEXT ONLY
                    cursor_color = (0, 255, 0) # Green (BGR)
                    mode = "NEXT_ONLY"

                cx_index, cy_index = int(index_tip.x * w), int(index_tip.y * h)
                cv2.circle(frame, (cx_index, cy_index), 10, cursor_color, -1) 
                
                # --- CHECK VOLUME ZONE ---
                if cx_index < vol_zone_w:
                    is_in_vol_zone = True
                    # VOLUME LOGIC
                    vol_ratio = (pinch_dist - 0.02) / (0.22 - 0.02)
                    current_volume_percent = int(max(0.0, min(1.0, vol_ratio)) * 100)
                    cx_thumb, cy_thumb = int(thumb_tip.x * w), int(thumb_tip.y * h)
                    cv2.line(frame, (cx_thumb, cy_thumb), (cx_index, cy_index), (0, 255, 0), 3)
                else:
                    is_in_vol_zone = False

                # --- DYNAMIC SWIPE SCROLL LOGIC ---
                if not is_in_vol_zone:
                    curr_y = index_tip.y
                    current_time = time.time()
                    
                    # Track relative movement
                    if prev_wrist_y is not None:
                        dy = curr_y - prev_wrist_y # Change in Y
                        
                        # Threshold for swipe
                        swipe_threshold = 0.05 
                        
                        # Only trigger if cooldown is over
                        if (current_time - scroll_cooldown) > 0.5:
                            
                            # SWIPE UP (y decrease) -> NEXT REEL (Only if mode is NEXT_ONLY)
                            if dy < -swipe_threshold and mode == "NEXT_ONLY":
                                scroll_action = "SCROLL_DOWN" # Content moves down = Next Reel
                                print(f"ACTION: GREEN MODE -> NEXT")
                                scroll_cooldown = current_time
                                cv2.putText(frame, "NEXT", (cx_index, cy_index), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                                
                            # SWIPE DOWN (y increase) -> PREV REEL (Only if mode is PREV_ONLY)
                            elif dy > swipe_threshold and mode == "PREV_ONLY":
                                scroll_action = "SCROLL_UP" # Content moves up = Prev Reel
                                print(f"ACTION: RED MODE -> PREV")
                                scroll_cooldown = current_time
                                cv2.putText(frame, "PREV", (cx_index, cy_index), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

                    prev_wrist_y = curr_y 
                else:
                    prev_wrist_y = None

        # Emit gesture update (MOVED OUTSIDE hand detection to always emit current state)
        socketio.emit('gesture_update', {
            'volume': current_volume_percent,
            'scroll': scroll_action
        })
        # Yield control to eventlet so socket can send
        eventlet.sleep(0)
        
        # --- DRAW VISUALIZATIONS ---
        overlay = frame.copy()
        color = (0, 200, 0) if is_in_vol_zone else (30, 30, 30)
        cv2.rectangle(overlay, (0, 0), (vol_zone_w, h), color, -1)
        cv2.addWeighted(overlay, 0.3, frame, 0.7, 0, frame)
        
        cv2.putText(frame, "VOL ZONE", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (255, 255, 255), 1)
        cv2.putText(frame, f"{current_volume_percent}%", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (255, 255, 255), 2)

        ret, buffer = cv2.imencode('.jpg', frame)
        frame = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame + b'\r\n')

@app.route('/')
def index():
    return render_template('index.html')

@app.route('/reels')
def mock_reels():
    return render_template('mock_reels.html')

@app.route('/video_feed')
def video_feed():
    return Response(generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')

@socketio.on('connect')
def connect():
    print('Client connected')

if __name__ == '__main__':
    socketio.run(app, debug=True)
