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
        
        # --- UI LAYOUT ---
        # 1. SCROLL LINE (y=0.5)
        line_y = int(h * 0.5) 
        cv2.line(frame, (int(w*0.25), line_y), (w, line_y), (0, 255, 255), 2) # Yellow Line
        
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
                
                # --- CURSOR ---
                cx_index, cy_index = int(index_tip.x * w), int(index_tip.y * h)
                cv2.circle(frame, (cx_index, cy_index), 10, (0, 255, 255), -1) 
                
                # --- CHECK ZONE ---
                if cx_index < vol_zone_w:
                    is_in_vol_zone = True
                    # VOLUME LOGIC
                    distance = np.sqrt((thumb_tip.x - index_tip.x)**2 + (thumb_tip.y - index_tip.y)**2)
                    min_dist, max_dist = 0.02, 0.22
                    vol_ratio = (distance - min_dist) / (max_dist - min_dist)
                    current_volume_percent = int(max(0.0, min(1.0, vol_ratio)) * 100)
                    
                    # Visual
                    cx_thumb, cy_thumb = int(thumb_tip.x * w), int(thumb_tip.y * h)
                    cv2.line(frame, (cx_thumb, cy_thumb), (cx_index, cy_index), (0, 255, 0), 3)
                else:
                    is_in_vol_zone = False

                # --- SCROLL LOGIC (State Machine) ---
                if not is_in_vol_zone:
                    curr_y = index_tip.y
                    current_time = time.time()
                    
                    # Determine current state relative to line (with small buffer)
                    # Line is 0.5. 
                    # ABOVE (< 0.45), BELOW (> 0.55), BUFFER (0.45-0.55)
                    
                    current_position_state = None
                    if curr_y < 0.45:
                        current_position_state = "ABOVE"
                    elif curr_y > 0.55:
                        current_position_state = "BELOW"
                    
                    # Check for State TRANSITION
                    if last_position_state and current_position_state and (current_time - scroll_cooldown) > 0.5:
                        
                        # Transition: BELOW -> ABOVE (Swipe UP)
                        if last_position_state == "BELOW" and current_position_state == "ABOVE":
                            scroll_action = "SCROLL_DOWN" # Content moves down, meaning Next Item
                            print(f"ACTION: SWIPE UP -> NEXT REEL")
                            scroll_cooldown = current_time
                            cv2.putText(frame, "NEXT", (cx_index, cy_index), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                        
                        # Transition: ABOVE -> BELOW (Swipe DOWN)
                        elif last_position_state == "ABOVE" and current_position_state == "BELOW":
                            scroll_action = "SCROLL_UP" # Content moves up, meaning Prev Item
                            print(f"ACTION: SWIPE DOWN -> PREV REEL")
                            scroll_cooldown = current_time
                            cv2.putText(frame, "PREV", (cx_index, cy_index), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

                    # Only update state if we are decisively in a new zone
                    if current_position_state:
                         last_position_state = current_position_state

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
