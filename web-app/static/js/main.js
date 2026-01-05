const socket = io();

// UI Elements
const statusDot = document.getElementById('status-dot');
const statusText = document.getElementById('status-text');
const volumeBar = document.getElementById('volume-bar');
const volumeText = document.getElementById('volume-text');
const actionBox = document.getElementById('action-box');
const gestureFeedback = document.getElementById('gesture-feedback');

socket.on('connect', () => {
    console.log('Connected to server');
    statusDot.classList.add('connected');
    statusText.innerText = "Active & Monitor";
    statusText.style.color = "#22c55e";
});

socket.on('disconnect', () => {
    console.log('Disconnected');
    statusDot.classList.remove('connected');
    statusText.innerText = "Disconnected";
    statusText.style.color = "#ef4444";
});

socket.on('gesture_update', (data) => {
    // 1. Update Volume
    const volume = data.volume;
    volumeBar.style.width = `${volume}%`;
    volumeText.innerText = `${volume}%`;

    // 2. Update Action Text (Scroll)
    if (data.scroll) {
        actionBox.innerText = data.scroll;
        actionBox.style.background = "#3b82f6"; // flash blue
        setTimeout(() => {
            actionBox.style.background = "#334155"; // revert
        }, 200);

        gestureFeedback.innerText = `Gesture: ${data.scroll}`;
    }

    // 3. Update Feedback overlay
    // Simple logic: if volume is changing, show it
    if (!data.scroll) {
        gestureFeedback.innerText = `Index Finger Volume Control`;
    }
});
