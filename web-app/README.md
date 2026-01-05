# HandWave Control - Web Prototype

This is the Python-based prototype for the HandWave Control application. It uses **MediaPipe** for hand tracking and **Flask** for the web interface.

## ⚠️ Important Requirement
**This project requires Python 3.9 - 3.11.**
Python 3.13 (current latest) has compatibility issues with Google MediaPipe.
Please ensure you are using a compatible version.

## Setup & Run

1.  **Install Dependencies**:
    ```bash
    pip install -r requirements.txt
    ```

2.  **Run the App**:
    ```bash
    python app.py
    ```

3.  **Open in Browser**:
    Go to `http://localhost:5000`

## Features Implemented
- **Hand Detection**: Uses MediaPipe `HandLandmarker`.
- **Volume Control**: Map index finger height to volume (0-100%).
- **Scroll Gesture**: Swipe hand UP to scroll DOWN (and vice versa).
- **Mock Reels**: A simulated Reels feed to test gestures.

## Gestures
| Gesture | Action |
|---------|--------|
| **Index Finger UP** 👆 | Increase Volume |
| **Index Finger DOWN** 👇 | Decrease Volume |
| **Hand Swipe UP** ✋⬆️ | Scroll Down (Next Reel) |
| **Hand Swipe DOWN** ✋⬇️ | Scroll Up (Prev Reel) |

## 📜 License & Copyright

**Copyright © 2026 CodePlay. All Rights Reserved.**

This project is licensed under the **MIT License**.

> **Note**: This software is the intellectual property of **CodePlay**. Unauthorized commercial exploitation is strictly monitored.
