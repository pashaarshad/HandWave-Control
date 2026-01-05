from flask import Flask, render_template, Response
from flask_socketio import SocketIO, emit
import cv2
import mediapipe as mp
from mediapipe.tasks import python
from mediapipe.tasks.python import vision
import numpy as np
import time
import os

# Initialize Flask app
app = Flask(__name__)
socketio = SocketIO(app, cors_allowed_origins="*")

# --- MEDIAPIPE TASKS SETUP ---
# Path to the model file. 
MODEL_PATH = 'hand_landmarker.task'

# Check if model exists
if not os.path.exists(MODEL_PATH):
    print(f"Error: {MODEL_PATH} not found. Please ensure the model file is in the web-app directory.")
    # Fallback or exit? We'll try to continue but it will crash if used.

# Create HandLandmarker options
base_options = python.BaseOptions(model_asset_path=MODEL_PATH)
options = vision.HandLandmarkerOptions(
    base_options=base_options,
    num_hands=1,
    min_hand_detection_confidence=0.5,
    min_hand_presence_confidence=0.5,
    min_tracking_confidence=0.5
)

# Create detector
detector = vision.HandLandmarker.create_from_options(options)

# Drawing utilities (we might need to implement custom drawing if mp_drawing doesn't work with new result format directly)
mp_drawing = mp.solutions.drawing_utils
mp_hands = mp.solutions.hands # For connection constants

# Global variables
camera = None
prev_wrist_y = None
scroll_cooldown = 0

def draw_landmarks_on_image(rgb_image, detection_result):
    """
    Helper to draw landmarks on the frame.
    """
    hand_landmarks_list = detection_result.hand_landmarks
    annotated_image = np.copy(rgb_image)
    
    # Loop through the detected hands to visualize.
    for idx in range(len(hand_landmarks_list)):
        hand_landmarks = hand_landmarks_list[idx]
        
        # Convert the simplified landmark object to what mp_drawing expects (Proto)
        # However, the new API returns objects, distinct from Protos.
        # We'll draw manually or convert. Manual is safer for dependency reasons.
        
        # Draw points
        for landmark in hand_landmarks:
            h, w, _ = annotated_image.shape
            x, y = int(landmark.x * w), int(landmark.y * h)
            cv2.circle(annotated_image, (x, y), 5, (0, 255, 0), -1)
            
        # Draw connections
        # HAND_CONNECTIONS is a set of tuples (start_idx, end_idx)
        for connection in mp_hands.HAND_CONNECTIONS:
            start_idx = connection[0]
            end_idx = connection[1]
            
            start_point = hand_landmarks[start_idx]
            end_point = hand_landmarks[end_idx]
            
            h, w, _ = annotated_image.shape
            x1, y1 = int(start_point.x * w), int(start_point.y * h)
            x2, y2 = int(end_point.x * w), int(end_point.y * h)
            
            cv2.line(annotated_image, (x1, y1), (x2, y2), (255, 255, 255), 2)
            
    return annotated_image

def generate_frames():
    global prev_wrist_y, scroll_cooldown, camera
    camera = cv2.VideoCapture(0)
    
    while True:
        success, frame = camera.read()
        if not success:
            break

        frame = cv2.flip(frame, 1)
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Create MediaPipe Image
        mp_image = mp.Image(image_format=mp.ImageFormat.SRGB, data=frame_rgb)
        
        # Detect
        result = detector.detect(mp_image)
        
        # Draw
        annotated_frame = draw_landmarks_on_image(frame, result)
        
        current_volume_percent = 0
        scroll_action = None
        
        if result.hand_landmarks:
            # We assume 1 hand because max_num_hands=1
            hand_landmarks = result.hand_landmarks[0]
            
            # --- VOLUME (Index Tip: 8) ---
            index_finger_y = hand_landmarks[8].y
            vol_value = 1.0 - index_finger_y
            vol_value = max(0.0, min(1.0, vol_value))
            current_volume_percent = int(vol_value * 100)
            
            # --- SCROLL (Wrist: 0) ---
            wrist_y = hand_landmarks[0].y
            current_time = time.time()
            
            if prev_wrist_y is not None and (current_time - scroll_cooldown) > 1.0:
                delta_y = wrist_y - prev_wrist_y
                SWIPE_THRESHOLD = 0.15
                
                if delta_y < -SWIPE_THRESHOLD:
                    scroll_action = "SCROLL_DOWN" # Swipe UP
                    scroll_cooldown = current_time
                    prev_wrist_y = wrist_y # Reset baseline after action
                elif delta_y > SWIPE_THRESHOLD:
                    scroll_action = "SCROLL_UP" # Swipe DOWN
                    scroll_cooldown = current_time
                    prev_wrist_y = wrist_y
            
            # Update previous position continuously if no action
            if scroll_action is None:
                prev_wrist_y = wrist_y

            socketio.emit('gesture_update', {
                'volume': current_volume_percent,
                'scroll': scroll_action
            })

        # Encode
        ret, buffer = cv2.imencode('.jpg', annotated_frame)
        frame_out = buffer.tobytes()
        yield (b'--frame\r\n'
               b'Content-Type: image/jpeg\r\n\r\n' + frame_out + b'\r\n')

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

