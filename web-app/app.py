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
    scroll_state = "IDLE" # IDLE, CROSSING_UP, CROSSING_DOWN
    
    while True:
        success, frame = camera.read()
        if not success:
            break

        frame = cv2.flip(frame, 1)
        # Get frame dimensions
        h, w, c = frame.shape
        
        # DRAW REFERENCE LINE (Middle of Screen)
        # Y-coordinate of the line (e.g., 50% height)
        line_y = int(h * 0.5) 
        cv2.line(frame, (0, line_y), (w, line_y), (0, 255, 255), 2) # Yellow Line
        cv2.putText(frame, "SCROLL LINE", (10, line_y - 10), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (0, 255, 255), 1)

        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(frame_rgb)
        
        current_volume_percent = 0
        scroll_action = None
        
        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp_drawing.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                
                # --- NEW FEATURE 1: VOLUME via PINCH (Distance) ---
                # Thumb Tip: 4, Index Tip: 8
                thumb_tip = hand_landmarks.landmark[4]
                index_tip = hand_landmarks.landmark[8]
                
                # Calculate distance between thumb and index finger
                distance = np.sqrt((thumb_tip.x - index_tip.x)**2 + (thumb_tip.y - index_tip.y)**2)
                
                # Map Distance to Volume
                # Closed (Touch) ~ 0.02
                # Wide Open ~ 0.20+
                min_dist = 0.02
                max_dist = 0.22
                
                # Direct Map: More Distance = More Volume
                vol_ratio = (distance - min_dist) / (max_dist - min_dist)
                vol_ratio = max(0.0, min(1.0, vol_ratio)) # Clamp
                
                # Smooth log curve for better feel (optional, sticking to linear for now)
                current_volume_percent = int(vol_ratio * 100)
                
                # Visualize Pinch Line color based on volume (Red=Low, Green=High)
                line_color = (0, 0, 255) if vol_ratio < 0.3 else (0, 255, 0)
                cx_thumb, cy_thumb = int(thumb_tip.x * w), int(thumb_tip.y * h)
                cx_index, cy_index = int(index_tip.x * w), int(index_tip.y * h)
                cv2.line(frame, (cx_thumb, cy_thumb), (cx_index, cy_index), line_color, 3)
                cv2.putText(frame, f"Vol: {current_volume_percent}%", (cx_thumb, cy_thumb - 20), cv2.FONT_HERSHEY_SIMPLEX, 0.6, line_color, 2)
                
                
                # --- NEW FEATURE 2: SCROLL via LINE CROSSING ---
                # Use Index Finger Tip (8) for scrolling
                curr_y = index_tip.y # Normalized 0.0 (Top) to 1.0 (Bottom)
                
                # Setup hysteresis / threshold zone around the line (e.g., 0.45 to 0.55)
                # Line is at 0.5
                
                current_time = time.time()
                
                # Logic: Detect Crossing
                # We need to track if finger WAS above and IS NOW below (Swipe Down)
                # or WAS below and IS NOW above (Swipe Up)
                
                if prev_finger_y is not None and (current_time - scroll_cooldown) > 0.8:
                    # Defining Zones: TOP (< 0.45), BOTTOM (> 0.55), MIDDLE (0.45-0.55)
                    line_normalized = 0.5
                    buffer = 0.05
                    
                    # Swipe UP (Bottom -> Top) -> Scroll DOWN
                    if prev_finger_y > (line_normalized + buffer) and curr_y < (line_normalized - buffer):
                        scroll_action = "SCROLL_DOWN" # Next Reel
                        print("ACTION: CROSS UP -> NEXT REEL")
                        scroll_cooldown = current_time
                        cv2.putText(frame, "NEXT REEL!", (int(w/2), int(h/2)), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
                        
                    # Swipe DOWN (Top -> Bottom) -> Scroll UP
                    elif prev_finger_y < (line_normalized - buffer) and curr_y > (line_normalized + buffer):
                        scroll_action = "SCROLL_UP" # Prev Reel
                        print("ACTION: CROSS DOWN -> PREV REEL")
                        scroll_cooldown = current_time
                        cv2.putText(frame, "PREV REEL!", (int(w/2), int(h/2)), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 2)

                prev_finger_y = curr_y

                # Emit updates
                socketio.emit('gesture_update', {
                    'volume': current_volume_percent,
                    'scroll': scroll_action
                })

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

