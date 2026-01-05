from flask import Flask, render_template, Response
from flask_socketio import SocketIO, emit
import cv2
import mediapipe as mp
import numpy as np
import time

# Initialize Flask app
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

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
    
    # Scroll State
    prev_finger_y = None
    
    # Volume State
    current_volume_percent = 50 # Default start
    
    while True:
        success, frame = camera.read()
        if not success:
            break

        frame = cv2.flip(frame, 1)
        # Get frame dimensions
        h, w, c = frame.shape
        
        # --- UI LAYOUT ---
        # 1. SCROLL LINE (Right side/Main area)
        line_y = int(h * 0.5) 
        cv2.line(frame, (int(w*0.3), line_y), (w, line_y), (0, 255, 255), 2) # Yellow Line
        
        # 2. VOLUME ZONE (Left side, 25%)
        vol_zone_w = int(w * 0.25)
        
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(frame_rgb)
        
        scroll_action = None
        is_in_vol_zone = False
        
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                # Thumb Tip: 4, Index Tip: 8
                thumb_tip = hand_landmarks.landmark[4]
                index_tip = hand_landmarks.landmark[8]
                
                # --- CURSOR (Index Tip) ---
                cx_index, cy_index = int(index_tip.x * w), int(index_tip.y * h)
                cv2.circle(frame, (cx_index, cy_index), 10, (0, 255, 255), -1) # Yellow Cursor
                
                # --- CHECK ZONE ---
                # Check if cursor is in Volume Zone (Left side)
                if cx_index < vol_zone_w:
                    is_in_vol_zone = True
                    
                    # --- VOLUME LOGIC (Active) ---
                    # Calculate pinch distance
                    distance = np.sqrt((thumb_tip.x - index_tip.x)**2 + (thumb_tip.y - index_tip.y)**2)
                    
                    # Map Distance
                    min_dist = 0.02
                    max_dist = 0.22
                    vol_ratio = (distance - min_dist) / (max_dist - min_dist)
                    vol_ratio = max(0.0, min(1.0, vol_ratio))
                    
                    current_volume_percent = int(vol_ratio * 100)
                    
                    # Visual: Pinch Line
                    cx_thumb, cy_thumb = int(thumb_tip.x * w), int(thumb_tip.y * h)
                    cv2.line(frame, (cx_thumb, cy_thumb), (cx_index, cy_index), (0, 255, 0), 3)
                    
                else:
                    is_in_vol_zone = False
                    # Volume remains LOCKED at last `current_volume_percent`
                
                
                # --- SCROLL LOGIC ---
                # Only scroll if NOT in volume zone (to avoid conflicts)
                if not is_in_vol_zone:
                    curr_y = index_tip.y
                    current_time = time.time()
                    
                    # Check crossing if we have a previous point and cooldown is over
                    if prev_finger_y is not None and (current_time - scroll_cooldown) > 0.8:
                        line_normalized = 0.5
                        buffer = 0.04 # Reduced buffer for sensitivity
                        
                        # Swipe UP (Bottom -> Top)
                        if prev_finger_y > (line_normalized + buffer) and curr_y < (line_normalized - buffer):
                            scroll_action = "SCROLL_DOWN" 
                            scroll_cooldown = current_time
                            cv2.putText(frame, "NEXT", (cx_index, cy_index), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                            
                        # Swipe DOWN (Top -> Bottom)
                        elif prev_finger_y < (line_normalized - buffer) and curr_y > (line_normalized + buffer):
                            scroll_action = "SCROLL_UP"
                            scroll_cooldown = current_time
                            cv2.putText(frame, "PREV", (cx_index, cy_index), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)
    
                    prev_finger_y = curr_y

                socketio.emit('gesture_update', {
                    'volume': current_volume_percent,
                    'scroll': scroll_action
                })
        
        # --- DRAW VISUALIZATIONS ---
        # Draw Volume Zone Overlay
        overlay = frame.copy()
        color = (0, 255, 0) if is_in_vol_zone else (50, 50, 50) # Green if active, Gray if idle
        cv2.rectangle(overlay, (0, 0), (vol_zone_w, h), color, -1)
        cv2.addWeighted(overlay, 0.3, frame, 0.7, 0, frame)
        
        cv2.putText(frame, "VOL ZONE", (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(frame, f"{current_volume_percent}%", (10, 70), cv2.FONT_HERSHEY_SIMPLEX, 1.2, (255, 255, 255), 3)

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
